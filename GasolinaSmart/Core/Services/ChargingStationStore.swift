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

    func loadStations(near location: CLLocation, radiusKm: Double) async {
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
            stations = result
            lastFetchLocation = location
            lastFetchRadius = radiusKm + 5
            lastFetchTime = Date()
        } catch {
            if stations.isEmpty {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    func nearbyStations(location: CLLocation, radiusKm: Double, limit: Int = 100) -> [ChargingStation] {
        let radiusM = radiusKm * 1000
        let sorted = stations
            .compactMap { s -> (ChargingStation, Double)? in
                guard s.isOperational else { return nil }
                let d = location.distance(from: CLLocation(latitude: s.latitude, longitude: s.longitude))
                guard d <= radiusM else { return nil }
                return (s, d)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map(\.0)
        return Array(sorted)
    }
}
