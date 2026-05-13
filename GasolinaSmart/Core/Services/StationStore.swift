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
        let radiusM = radiusKm * 1000
        var result = allStations
            .compactMap { s -> (FuelStation, Double)? in
                guard s.price(for: fuelType) != nil else { return nil }
                let d = location.distance(from: CLLocation(latitude: s.latitude, longitude: s.longitude))
                guard d <= radiusM else { return nil }
                return (s, d)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
        if let limit { result = Array(result.prefix(limit)) }
        return result
    }

    func cheapestStation(
        location: CLLocation,
        radiusKm: Double,
        fuelType: FuelType
    ) -> FuelStation? {
        let radiusM = radiusKm * 1000
        return allStations
            .filter {
                $0.price(for: fuelType) != nil &&
                location.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude)) <= radiusM
            }
            .min { ($0.price(for: fuelType) ?? .greatestFiniteMagnitude) < ($1.price(for: fuelType) ?? .greatestFiniteMagnitude) }
    }

    func averagePrice(
        location: CLLocation,
        radiusKm: Double,
        fuelType: FuelType
    ) -> Decimal? {
        let radiusM = radiusKm * 1000
        let prices = allStations
            .filter {
                $0.price(for: fuelType) != nil &&
                location.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude)) <= radiusM
            }
            .compactMap { $0.price(for: fuelType) }
        guard !prices.isEmpty else { return cachedAveragePrice }
        return prices.reduce(Decimal.zero, +) / Decimal(prices.count)
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
