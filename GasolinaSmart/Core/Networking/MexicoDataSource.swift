import Foundation

actor MexicoDataSource: FuelDataSource {
    nonisolated let country: Country = .mexico

    private(set) var lastFetchedAt: Date?

    private let backend = BackendAPIService.shared

    func fetchStations(
        latitude: Double,
        longitude: Double,
        radiusKm: Double
    ) async throws -> [FuelStation] {
        let response = try await backend.fetchStationsNearby(
            latitude: latitude,
            longitude: longitude,
            radiusKm: radiusKm,
            country: .mexico,
            limit: 500
        )
        let stations = response.stations.map { $0.toFuelStation() }
        lastFetchedAt = Date()
        return stations
    }
}
