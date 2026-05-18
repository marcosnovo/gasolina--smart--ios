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
            guard generation == loadGeneration else { return }
            stations = response.stations.map { $0.toChargingStation() }
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

    func nearbyStations(location: CLLocation, radiusKm: Double, limit: Int = 100) -> [ChargingStation] {
        let radiusM = radiusKm * 1000
        let origin = location.coordinate
        let sorted = stations
            .compactMap { s -> (ChargingStation, Double)? in
                guard s.isOperational else { return nil }
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

    /// EV equivalent of StationStore.nearbySummary. The "cheapest" is the
    /// station with the lowest parsed €/kWh among nearby stations; if no
    /// nearby station advertises a price, falls back to the fastest charger.
    func nearbySummary(location: CLLocation, radiusKm: Double, limit: Int = 100) -> ChargingSummary {
        let radiusM = radiusKm * 1000
        let origin = location.coordinate

        let nearby = stations
            .compactMap { s -> (station: ChargingStation, distance: Double)? in
                guard s.isOperational else { return nil }
                let d = s.distanceKm(from: origin) * 1000
                guard d <= radiusM else { return nil }
                return (s, d)
            }
            .sorted { $0.distance < $1.distance }
            .prefix(limit)

        let visible = nearby.map(\.station)
        let priced = visible.compactMap { s -> (ChargingStation, Decimal)? in
            guard let price = s.pricePerKWh else { return nil }
            return (s, price)
        }

        let cheapest = priced.min(by: { $0.1 < $1.1 })?.0
            ?? visible.max(by: { ($0.maxPowerKW ?? 0) < ($1.maxPowerKW ?? 0) })

        let avg: Decimal? = priced.isEmpty
            ? nil
            : priced.map(\.1).reduce(Decimal.zero, +) / Decimal(priced.count)

        return ChargingSummary(
            visibleStations: visible,
            cheapestStation: cheapest,
            averagePricePerKWh: avg
        )
    }
}
