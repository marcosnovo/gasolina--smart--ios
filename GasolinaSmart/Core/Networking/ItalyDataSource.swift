import Foundation

actor ItalyDataSource: FuelDataSource {
    nonisolated let country: Country = .italy

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
            country: .italy,
            limit: 500
        )
        let stations = response.stations.map { $0.toFuelStation() }
        lastFetchedAt = Date()
        return stations
    }
}
