import Foundation

actor SpainDataSource: FuelDataSource {
    nonisolated let country: Country = .spain

    private(set) var lastFetchedAt: Date?

    private let backend = BackendAPIService.shared
    private let fallback = FuelAPIService.shared

    func fetchStations(
        latitude: Double,
        longitude: Double,
        radiusKm: Double
    ) async throws -> [FuelStation] {
        do {
            let response = try await backend.fetchStationsNearby(
                latitude: latitude,
                longitude: longitude,
                radiusKm: radiusKm,
                limit: 500
            )
            let stations = response.stations.map { $0.toFuelStation() }
            lastFetchedAt = Date()
            return stations
        } catch {
            let result = try await fallback.fetchStationsProgressively(
                latitude: latitude,
                longitude: longitude,
                nearbyRadiusKm: radiusKm
            )
            lastFetchedAt = Date()
            return result.all
        }
    }
}
