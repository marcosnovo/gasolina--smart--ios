import Foundation
import CoreLocation
import SwiftUI

@MainActor
@Observable
final class StationStore {
    private(set) var allStations: [FuelStation] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var lastUpdated: Date?
    private(set) var isUsingCache = false
    private(set) var cachedAveragePrice: Decimal?
    private(set) var activeCountry: Country = .spain
    private var loadedRadiusKm: Double = 0
    private var loadGeneration = 0

    struct NearbyFuelSummary {
        let visibleStations: [FuelStation]
        /// The cheapest station for the user's *primary* fuel (the one shown in
        /// the vehicle pill and used by the radar / cheapest pin).
        let cheapestStation: FuelStation?
        /// Average price for the primary fuel only.
        let averagePrice: Decimal?
        /// Cheapest price *per fuel* — used by per-fuel "near-cheapest" tinting.
        let cheapestPriceByFuel: [FuelType: Decimal]
        /// For each visible station, the fuel its marker should display.
        /// Prefers the primary fuel when the station has it; otherwise picks
        /// whichever other fuel from the requested set the station carries.
        let displayedFuelByStation: [String: FuelType]
    }

    func loadCacheImmediately() async {
        guard allStations.isEmpty else { return }
        if let cached = await StationCache.shared.getStale(country: activeCountry) {
            allStations = cached
            lastUpdated = await StationCache.shared.get(country: activeCountry)?.timestamp
            isUsingCache = true
        }
    }

    func switchCountry(_ country: Country) {
        guard country != activeCountry else { return }
        activeCountry = country
        allStations = []
        cachedAveragePrice = nil
        lastUpdated = nil
        loadedRadiusKm = 0
        loadGeneration += 1
        error = nil
        isUsingCache = false
    }

    func loadStations(near location: CLLocation? = nil, radiusKm: Double = 50) async {
        await loadFromNetwork(location: location, radiusKm: radiusKm)
    }

    func reloadIfNeeded(location: CLLocation?, radiusKm: Double) async {
        guard radiusKm > loadedRadiusKm else { return }
        await loadFromNetwork(location: location, radiusKm: radiusKm, force: true)
    }

    // Loads every station of the active country in one network call and
    // caches the result. After this returns, all subsequent queries
    // (nearbySummary, areaSummary, …) work against an in-memory dataset
    // that covers the whole country, so panning the map anywhere is
    // instant and doesn't need extra fetches.
    func loadAllCountryStations(force: Bool = false) async {
        loadGeneration += 1
        let myGeneration = loadGeneration
        let country = activeCountry

        if !force,
           let age = await StationCache.shared.cacheAge(country: country),
           age < 30 * 60, !allStations.isEmpty {
            isLoading = false
            return
        }

        isLoading = allStations.isEmpty
        error = nil

        do {
            let response = try await BackendAPIService.shared.fetchAllStations(country: country)
            // Map the 11k+ DTOs to domain models off the main actor — for Spain
            // this saved ~120 ms of stutter on cold launch.
            let stations = await Task.detached(priority: .userInitiated) {
                response.stations.map { $0.toFuelStation() }
            }.value
            guard myGeneration == loadGeneration else { return }
            allStations = stations
            lastUpdated = Date()
            loadedRadiusKm = .infinity
            isUsingCache = false
            await StationCache.shared.set(stations, country: country)
        } catch {
            guard myGeneration == loadGeneration else { return }
            if allStations.isEmpty {
                self.error = error.localizedDescription
            }
        }

        if myGeneration == loadGeneration {
            isLoading = false
        }
    }

    // MARK: - Network loading

    private func loadFromNetwork(location: CLLocation?, radiusKm: Double, force: Bool = false) async {
        loadGeneration += 1
        let myGeneration = loadGeneration
        let country = activeCountry

        if !force,
           let age = await StationCache.shared.cacheAge(country: country), age < 5 * 60, !allStations.isEmpty {
            isLoading = false
            return
        }

        isLoading = allStations.isEmpty
        error = nil

        guard let location else {
            isLoading = false
            return
        }

        let fetchRadius = max(radiusKm + 10, 30)

        do {
            guard myGeneration == loadGeneration else { return }
            guard let source = FuelDataSourceRegistry.shared.source(for: country) else {
                throw FuelDataSourceError.countryNotSupported
            }
            let stations = try await source.fetchStations(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radiusKm: fetchRadius
            )
            guard myGeneration == loadGeneration else { return }
            allStations = stations
            lastUpdated = Date()
            loadedRadiusKm = fetchRadius
            isUsingCache = false
            await StationCache.shared.set(stations, country: country)
        } catch {
            guard myGeneration == loadGeneration else { return }
            if allStations.isEmpty {
                self.error = error.localizedDescription
            }
        }
        if myGeneration == loadGeneration {
            isLoading = false
        }
    }

    // MARK: - Queries (local filtering)

    func nearbyStations(
        location: CLLocation,
        radiusKm: Double,
        fuelType: FuelType,
        limit: Int? = nil
    ) -> [FuelStation] {
        nearbySummary(location: location, radiusKm: radiusKm, fuelType: fuelType, limit: limit).visibleStations
    }

    func cheapestStation(
        location: CLLocation,
        radiusKm: Double,
        fuelType: FuelType
    ) -> FuelStation? {
        nearbySummary(location: location, radiusKm: radiusKm, fuelType: fuelType).cheapestStation
    }

    func averagePrice(
        location: CLLocation,
        radiusKm: Double,
        fuelType: FuelType
    ) -> Decimal? {
        nearbySummary(location: location, radiusKm: radiusKm, fuelType: fuelType).averagePrice ?? cachedAveragePrice
    }

    func nearbySummary(
        location: CLLocation,
        radiusKm: Double,
        fuelType: FuelType,
        limit: Int? = nil
    ) -> NearbyFuelSummary {
        nearbySummary(
            location: location,
            radiusKm: radiusKm,
            fuelTypes: [fuelType],
            primaryFuel: fuelType,
            limit: limit
        )
    }

    /// Multi-fuel filter used by dual-fuel vehicles (e.g. GLP cars that also
    /// run on gasoline). A station is visible if it carries *any* of the
    /// `fuelTypes` requested. An empty `fuelTypes` returns an empty summary
    /// (used for EV vehicles — they don't want fuel markers at all).
    func nearbySummary(
        location: CLLocation,
        radiusKm: Double,
        fuelTypes: Set<FuelType>,
        primaryFuel: FuelType,
        limit: Int? = nil
    ) -> NearbyFuelSummary {
        guard !fuelTypes.isEmpty else {
            return NearbyFuelSummary(
                visibleStations: [],
                cheapestStation: nil,
                averagePrice: nil,
                cheapestPriceByFuel: [:],
                displayedFuelByStation: [:]
            )
        }
        let radiusM = radiusKm * 1000
        let origin = location.coordinate
        let fuels = fuelTypes

        struct Match {
            let station: FuelStation
            let distance: Double
            let displayedFuel: FuelType
            let displayedPrice: Decimal
        }

        var matches: [Match] = []
        matches.reserveCapacity(allStations.count)

        for station in allStations {
            let distance = station.distanceMeters(from: origin)
            guard distance <= radiusM else { continue }

            // Prefer the user's primary fuel at this station; fall back to any
            // other fuel from the requested set if the station only has those.
            if let price = station.price(for: primaryFuel) {
                matches.append(Match(
                    station: station,
                    distance: distance,
                    displayedFuel: primaryFuel,
                    displayedPrice: price
                ))
                continue
            }
            for fuel in fuels where fuel != primaryFuel {
                if let price = station.price(for: fuel) {
                    matches.append(Match(
                        station: station,
                        distance: distance,
                        displayedFuel: fuel,
                        displayedPrice: price
                    ))
                    break
                }
            }
        }

        matches.sort { $0.distance < $1.distance }
        if let limit, matches.count > limit {
            matches = Array(matches.prefix(limit))
        }

        var visibleStations: [FuelStation] = []
        visibleStations.reserveCapacity(matches.count)
        var cheapestStation: FuelStation?
        var cheapestPrimaryPrice: Decimal?
        var primarySum: Decimal = 0
        var primaryCount: Int = 0
        var cheapestPriceByFuel: [FuelType: Decimal] = [:]
        var displayedFuelByStation: [String: FuelType] = [:]
        displayedFuelByStation.reserveCapacity(matches.count)

        for match in matches {
            visibleStations.append(match.station)
            displayedFuelByStation[match.station.id] = match.displayedFuel
            if let current = cheapestPriceByFuel[match.displayedFuel] {
                if match.displayedPrice < current {
                    cheapestPriceByFuel[match.displayedFuel] = match.displayedPrice
                }
            } else {
                cheapestPriceByFuel[match.displayedFuel] = match.displayedPrice
            }
            if match.displayedFuel == primaryFuel {
                primarySum += match.displayedPrice
                primaryCount += 1
                if cheapestPrimaryPrice == nil || match.displayedPrice < cheapestPrimaryPrice! {
                    cheapestPrimaryPrice = match.displayedPrice
                    cheapestStation = match.station
                }
            }
        }

        let averagePrice: Decimal? = primaryCount == 0
            ? cachedAveragePrice
            : primarySum / Decimal(primaryCount)

        return NearbyFuelSummary(
            visibleStations: visibleStations,
            cheapestStation: cheapestStation,
            averagePrice: averagePrice,
            cheapestPriceByFuel: cheapestPriceByFuel,
            displayedFuelByStation: displayedFuelByStation
        )
    }

    func areaSummary(
        minLatitude: Double,
        maxLatitude: Double,
        minLongitude: Double,
        maxLongitude: Double,
        fuelType: FuelType,
        limit: Int = 30
    ) -> NearbyFuelSummary {
        areaSummary(
            minLatitude: minLatitude,
            maxLatitude: maxLatitude,
            minLongitude: minLongitude,
            maxLongitude: maxLongitude,
            fuelTypes: [fuelType],
            primaryFuel: fuelType,
            limit: limit
        )
    }

    // Bounds-based filter for the "Search in this area" feature. Multi-fuel
    // version: a station qualifies if it has any of `fuelTypes`. If more
    // than `limit` stations qualify, we keep the cheapest ones (by the
    // displayed fuel of each station) so the map stays readable. Empty
    // `fuelTypes` returns an empty summary (EV vehicles).
    func areaSummary(
        minLatitude: Double,
        maxLatitude: Double,
        minLongitude: Double,
        maxLongitude: Double,
        fuelTypes: Set<FuelType>,
        primaryFuel: FuelType,
        limit: Int = 30
    ) -> NearbyFuelSummary {
        guard !fuelTypes.isEmpty else {
            return NearbyFuelSummary(
                visibleStations: [],
                cheapestStation: nil,
                averagePrice: nil,
                cheapestPriceByFuel: [:],
                displayedFuelByStation: [:]
            )
        }
        let fuels = fuelTypes

        struct Match {
            let station: FuelStation
            let displayedFuel: FuelType
            let displayedPrice: Decimal
        }

        var matches: [Match] = []
        matches.reserveCapacity(allStations.count)

        for station in allStations {
            guard station.latitude >= minLatitude,
                  station.latitude <= maxLatitude,
                  station.longitude >= minLongitude,
                  station.longitude <= maxLongitude else { continue }

            if let price = station.price(for: primaryFuel) {
                matches.append(Match(station: station, displayedFuel: primaryFuel, displayedPrice: price))
                continue
            }
            for fuel in fuels where fuel != primaryFuel {
                if let price = station.price(for: fuel) {
                    matches.append(Match(station: station, displayedFuel: fuel, displayedPrice: price))
                    break
                }
            }
        }

        if matches.count > limit {
            matches.sort { $0.displayedPrice < $1.displayedPrice }
            matches = Array(matches.prefix(limit))
        }

        var visibleStations: [FuelStation] = []
        visibleStations.reserveCapacity(matches.count)
        var cheapestStation: FuelStation?
        var cheapestPrimaryPrice: Decimal?
        var primarySum: Decimal = 0
        var primaryCount: Int = 0
        var cheapestPriceByFuel: [FuelType: Decimal] = [:]
        var displayedFuelByStation: [String: FuelType] = [:]
        displayedFuelByStation.reserveCapacity(matches.count)

        for match in matches {
            visibleStations.append(match.station)
            displayedFuelByStation[match.station.id] = match.displayedFuel
            if let current = cheapestPriceByFuel[match.displayedFuel] {
                if match.displayedPrice < current {
                    cheapestPriceByFuel[match.displayedFuel] = match.displayedPrice
                }
            } else {
                cheapestPriceByFuel[match.displayedFuel] = match.displayedPrice
            }
            if match.displayedFuel == primaryFuel {
                primarySum += match.displayedPrice
                primaryCount += 1
                if cheapestPrimaryPrice == nil || match.displayedPrice < cheapestPrimaryPrice! {
                    cheapestPrimaryPrice = match.displayedPrice
                    cheapestStation = match.station
                }
            }
        }

        let averagePrice: Decimal? = primaryCount == 0
            ? nil
            : primarySum / Decimal(primaryCount)

        return NearbyFuelSummary(
            visibleStations: visibleStations,
            cheapestStation: cheapestStation,
            averagePrice: averagePrice,
            cheapestPriceByFuel: cheapestPriceByFuel,
            displayedFuelByStation: displayedFuelByStation
        )
    }

    func estimatedSaving(
        stationPrice: Decimal,
        averagePrice: Decimal,
        tankLiters: Double
    ) -> Decimal {
        (averagePrice - stationPrice) * Decimal(tankLiters)
    }

    func worthItLevel(saving: Decimal) -> WorthItLevel {
        if saving < 1 { return .neutral }
        if saving <= 3 { return .moderate }
        return .good
    }

    func fuelDecisionMessage(
        stationPrice: Decimal?,
        averagePrice: Decimal?,
        tankLiters: Double,
        distanceKm: Double?
    ) -> FuelDecision {
        guard let stationPrice, let averagePrice else {
            return FuelDecision(verdict: .noData, saving: nil)
        }
        let saving = (averagePrice - stationPrice) * Decimal(tankLiters)
        let level = worthItLevel(saving: saving)

        if let distanceKm, distanceKm > 15, level != .good {
            return FuelDecision(verdict: .tooFar, saving: saving)
        }

        switch level {
        case .good:
            return FuelDecision(verdict: .refuelNow, saving: saving)
        case .moderate:
            return FuelDecision(verdict: .goodOption, saving: saving)
        case .neutral:
            return FuelDecision(verdict: .average, saving: saving)
        }
    }

    func dataFreshnessText(loc: Loc) -> String {
        guard let lastUpdated else { return loc.dataNoData }
        let minutes = Int(Date().timeIntervalSince(lastUpdated) / 60)
        let prefix = isLoading ? loc.dataUpdating : ""
        if minutes < 1 { return "\(prefix)\(loc.dataUpdatedNow)" }
        if minutes < 60 { return "\(prefix)\(loc.dataMinutesAgo(minutes))" }
        let hours = minutes / 60
        return "\(prefix)\(loc.dataHoursAgo(hours))"
    }

    func priceOpportunity(
        stationPrice: Decimal?,
        averagePrice: Decimal?,
        tankLiters: Double
    ) -> PriceOpportunity {
        guard let stationPrice, let averagePrice else { return .unknown }
        let saving = (averagePrice - stationPrice) * Decimal(tankLiters)
        if saving > 3 { return .great }
        if saving > 0 { return .fair }
        return .poor
    }
}

enum WorthItLevel {
    case neutral
    case moderate
    case good

    var message: String {
        switch self {
        case .neutral: "Precio similar a la media"
        case .moderate: "Puede compensar"
        case .good: "Buena oportunidad"
        }
    }

    var icon: String {
        switch self {
        case .neutral: "equal.circle"
        case .moderate: "arrow.down.circle"
        case .good: "arrow.down.circle.fill"
        }
    }

    var shortMessage: String {
        switch self {
        case .neutral: "Similar"
        case .moderate: "Compensa"
        case .good: "Buen precio"
        }
    }
}

struct FuelDecision {
    enum Verdict {
        case refuelNow
        case goodOption
        case average
        case tooFar
        case noData

        var title: String {
            switch self {
            case .refuelNow: "Reposta ahora"
            case .goodOption: "Buena oportunidad"
            case .average: "Precio normal"
            case .tooFar: "No compensa desviarse"
            case .noData: "Sin datos suficientes"
            }
        }

        var icon: String {
            switch self {
            case .refuelNow: "bolt.fill"
            case .goodOption: "hand.thumbsup.fill"
            case .average: "equal.circle"
            case .tooFar: "location.slash"
            case .noData: "questionmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .refuelNow: Theme.Colors.goodPrice
            case .goodOption: Theme.Colors.moderatePrice
            case .average: Theme.Colors.neutralPrice
            case .tooFar: Theme.Colors.expensivePrice
            case .noData: Theme.Colors.secondaryLabel
            }
        }
    }

    let verdict: Verdict
    let saving: Decimal?
}
