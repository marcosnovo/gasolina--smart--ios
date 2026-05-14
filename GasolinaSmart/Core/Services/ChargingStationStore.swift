import Foundation
import CoreLocation

@MainActor
@Observable
final class ChargingStationStore {
    private(set) var stations: [ChargingStation] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private var lastFetchLocation: CLLocation?
    private var lastFetchRadius: Double = 0
    private var lastFetchTime: Date?
    private var loadGeneration = 0

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
}
