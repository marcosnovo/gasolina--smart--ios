import Foundation
import CoreLocation

@MainActor
@Observable
final class ChargingStationStore {
    private(set) var stations: [ChargingStation] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var lastUpdated: Date?
    private var lastFetchLocation: CLLocation?
    private var lastFetchRadius: Double = 0
    private var lastFetchTime: Date?
    private var activeCountry: Country = .spain
    private var loadGeneration = 0

    /// Whole-country EV charging snapshot from the Workers backend.
    /// Mirrors StationStore.loadAllCountryStations — call once per session /
    /// per country switch, then run all subsequent filters in-memory.
    func loadAllCountryStations(country: Country, force: Bool = false) async {
        loadGeneration += 1
        let generation = loadGeneration

        if !force, country == activeCountry,
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < 30 * 60,
           !stations.isEmpty {
            return
        }

        activeCountry = country
        isLoading = stations.isEmpty
        error = nil

        do {
            let response = try await BackendAPIService.shared.fetchAllChargingStations(country: country)
            // Convert DTOs off the main actor — connector JSON parsing isn't
            // free and a country can have tens of thousands of points.
            let mapped = await Task.detached(priority: .userInitiated) {
                response.stations.map { $0.toChargingStation() }
            }.value
            guard generation == loadGeneration else { return }
            stations = mapped
            lastFetchTime = Date()
            lastUpdated = Date()
        } catch {
            guard generation == loadGeneration else { return }
            if stations.isEmpty {
                self.error = error.localizedDescription
            }
        }

        if generation == loadGeneration {
            isLoading = false
        }
    }

    /// Legacy radius-based loader (OpenStreetMap fallback). Still useful when
    /// the backend snapshot hasn't landed yet for a country.
    func loadStations(near location: CLLocation, radiusKm: Double) async {
        loadGeneration += 1
        let generation = loadGeneration

        if let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < 5 * 60,
           let lastLoc = lastFetchLocation,
           lastLoc.distance(from: location) < 2000,
           radiusKm <= lastFetchRadius {
            return
        }

        isLoading = stations.isEmpty
        error = nil

        do {
            let result = try await ChargingStationService.shared.fetchStations(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radiusKm: radiusKm + 5
            )
            guard generation == loadGeneration else { return }
            stations = result
            lastFetchLocation = location
            lastFetchRadius = radiusKm + 5
            lastFetchTime = Date()
        } catch {
            guard generation == loadGeneration else { return }
            if stations.isEmpty {
                self.error = error.localizedDescription
            }
        }

        if generation == loadGeneration {
            isLoading = false
        }
    }

    func nearbyStations(
        location: CLLocation,
        radiusKm: Double,
        limit: Int = 100,
        connectorFilter: Set<String> = []
    ) -> [ChargingStation] {
        let radiusM = radiusKm * 1000
        let origin = location.coordinate
        let sorted = stations
            .compactMap { s -> (ChargingStation, Double)? in
                guard s.isOperational else { return nil }
                guard s.matchesConnectorFilter(connectorFilter) else { return nil }
                let d = s.distanceKm(from: origin) * 1000
                guard d <= radiusM else { return nil }
                return (s, d)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map(\.0)
        return Array(sorted)
    }

    struct ChargingSummary {
        let visibleStations: [ChargingStation]
        let cheapestStation: ChargingStation?
        let averagePricePerKWh: Decimal?
    }

    /// Bounds-based filter for the EV "Search in this area" feature. Mirrors
    /// StationStore.areaSummary but for charging points: returns the
    /// stations inside the visible map rectangle, capped at `limit` and
    /// sorted by parsed €/kWh ascending (or max kW descending as a fallback
    /// when no prices are available).
    func areaSummary(
        minLatitude: Double,
        maxLatitude: Double,
        minLongitude: Double,
        maxLongitude: Double,
        limit: Int = 30,
        connectorFilter: Set<String> = []
    ) -> ChargingSummary {
        var matches = stations.filter { s in
            s.isOperational
                && s.matchesConnectorFilter(connectorFilter)
                && s.latitude >= minLatitude && s.latitude <= maxLatitude
                && s.longitude >= minLongitude && s.longitude <= maxLongitude
        }

        if matches.count > limit {
            // Sort by price first, falling back to max kW.
            matches.sort { a, b in
                switch (a.pricePerKWh, b.pricePerKWh) {
                case (let pa?, let pb?): return pa < pb
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return (a.maxPowerKW ?? 0) > (b.maxPowerKW ?? 0)
                }
            }
            matches = Array(matches.prefix(limit))
        }

        var cheapest: ChargingStation?
        var cheapestPrice: Decimal?
        var fastest: ChargingStation?
        var fastestKW: Double = -1
        var priceSum: Decimal = 0
        var pricedCount: Int = 0

        for station in matches {
            if let price = station.pricePerKWh {
                priceSum += price
                pricedCount += 1
                if cheapestPrice == nil || price < cheapestPrice! {
                    cheapestPrice = price
                    cheapest = station
                }
            }
            let power = station.maxPowerKW ?? 0
            if power > fastestKW {
                fastestKW = power
                fastest = station
            }
        }

        let avg: Decimal? = pricedCount == 0 ? nil : priceSum / Decimal(pricedCount)
        return ChargingSummary(
            visibleStations: matches,
            cheapestStation: cheapest ?? fastest,
            averagePricePerKWh: avg
        )
    }

    /// EV equivalent of StationStore.nearbySummary. The "cheapest" is the
    /// station with the lowest parsed €/kWh among nearby stations; if no
    /// nearby station advertises a price, falls back to the fastest charger.
    func nearbySummary(
        location: CLLocation,
        radiusKm: Double,
        limit: Int = 100,
        connectorFilter: Set<String> = []
    ) -> ChargingSummary {
        let radiusM = radiusKm * 1000
        let origin = location.coordinate

        // Single pass that filters + computes distance, avoiding the
        // closure-wrapped compactMap allocation. Builds the array, then
        // sorts and prefixes — same complexity as before, fewer
        // intermediate allocations.
        var candidates: [(station: ChargingStation, distance: Double)] = []
        candidates.reserveCapacity(stations.count)
        for s in stations {
            guard s.isOperational else { continue }
            guard s.matchesConnectorFilter(connectorFilter) else { continue }
            let d = s.distanceKm(from: origin) * 1000
            guard d <= radiusM else { continue }
            candidates.append((s, d))
        }
        candidates.sort { $0.distance < $1.distance }
        let nearby = candidates.prefix(limit)

        var visible: [ChargingStation] = []
        visible.reserveCapacity(nearby.count)
        var cheapest: ChargingStation?
        var cheapestPrice: Decimal?
        var fastest: ChargingStation?
        var fastestKW: Double = -1
        var priceSum: Decimal = 0
        var pricedCount: Int = 0

        for entry in nearby {
            let s = entry.station
            visible.append(s)
            if let price = s.pricePerKWh {
                priceSum += price
                pricedCount += 1
                if cheapestPrice == nil || price < cheapestPrice! {
                    cheapestPrice = price
                    cheapest = s
                }
            }
            let power = s.maxPowerKW ?? 0
            if power > fastestKW {
                fastestKW = power
                fastest = s
            }
        }

        let avg: Decimal? = pricedCount == 0 ? nil : priceSum / Decimal(pricedCount)
        return ChargingSummary(
            visibleStations: visible,
            cheapestStation: cheapest ?? fastest,
            averagePricePerKWh: avg
        )
    }
}
