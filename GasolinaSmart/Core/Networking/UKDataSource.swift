import Foundation

actor UKDataSource: FuelDataSource {
    nonisolated let country: Country = .uk

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
            country: .uk,
            limit: 500
        )
        let stations = response.stations.map { $0.toFuelStation() }
        lastFetchedAt = Date()
        return stations
    }
}
