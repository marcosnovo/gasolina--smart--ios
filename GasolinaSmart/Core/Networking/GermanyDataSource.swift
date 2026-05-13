import Foundation
import CoreLocation

/// Data source for German fuel stations using the Tankerkoenig API (CC BY 4.0).
/// Requires a free API key stored in UserDefaults under "tankerkoenig_api_key".
actor GermanyDataSource: FuelDataSource {

    // MARK: - FuelDataSource

    nonisolated let country: Country = .germany
    private(set) var lastFetchedAt: Date?

    // MARK: - Constants

    private let baseURL = "https://creativecommons.tankerkoenig.de/json/list.php"
    private static let maxRadiusKm: Double = 25

    // MARK: - DTOs

    private struct TankerkoenigResponse: Decodable {
        let ok: Bool
        let stations: [StationDTO]?
        let message: String?
    }

    private struct StationDTO: Decodable {
        let id: String
        let name: String
        let brand: String
        let street: String
        let houseNumber: String?
        let postCode: String?
        let place: String
        let lat: Double
        let lng: Double
        let dist: Double?
        let diesel: Double?
        let e5: Double?
        let e10: Double?
        let isOpen: Bool
    }

    // MARK: - Fetch

    func fetchStations(
        latitude: Double,
        longitude: Double,
        radiusKm: Double
    ) async throws -> [FuelStation] {
        let apiKey = UserDefaults.standard.string(forKey: "tankerkoenig_api_key") ?? ""
        guard !apiKey.isEmpty else {
            throw FuelDataSourceError.apiKeyRequired
        }

        let clampedRadius = min(radiusKm, Self.maxRadiusKm)

        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lng", value: String(longitude)),
            URLQueryItem(name: "rad", value: String(clampedRadius)),
            URLQueryItem(name: "sort", value: "dist"),
            URLQueryItem(name: "type", value: "all"),
            URLQueryItem(name: "apikey", value: apiKey),
        ]

        guard let url = components?.url else {
            throw FuelDataSourceError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FuelDataSourceError.httpError(0)
        }
        guard httpResponse.statusCode == 200 else {
            throw FuelDataSourceError.httpError(httpResponse.statusCode)
        }

        let decoded: TankerkoenigResponse
        do {
            decoded = try JSONDecoder().decode(TankerkoenigResponse.self, from: data)
        } catch {
            throw FuelDataSourceError.parseError(error.localizedDescription)
        }

        guard decoded.ok else {
            throw FuelDataSourceError.parseError(decoded.message ?? "API returned ok=false")
        }

        guard let dtoStations = decoded.stations else {
            throw FuelDataSourceError.parseError("Missing stations array")
        }

        let now = Date()
        lastFetchedAt = now

        return dtoStations
            .filter { $0.isOpen }
            .compactMap { dto in
                mapStation(dto, fetchDate: now)
            }
    }

    // MARK: - Mapping

    private nonisolated func mapStation(_ dto: StationDTO, fetchDate: Date) -> FuelStation? {
        var prices: [FuelType: Decimal] = [:]

        if let e5 = dto.e5, e5 > 0 {
            prices[.e5] = Decimal(e5)
        }
        if let e10 = dto.e10, e10 > 0 {
            prices[.e10] = Decimal(e10)
        }
        if let diesel = dto.diesel, diesel > 0 {
            prices[.dieselA] = Decimal(diesel)
        }

        guard !prices.isEmpty else { return nil }

        let address: String
        if let houseNumber = dto.houseNumber, !houseNumber.isEmpty {
            address = "\(dto.street) \(houseNumber)"
        } else {
            address = dto.street
        }

        return FuelStation(
            id: "DE_\(dto.id)",
            name: dto.name,
            brand: dto.brand,
            address: address,
            municipality: dto.place,
            province: dto.postCode ?? "",
            latitude: dto.lat,
            longitude: dto.lng,
            prices: prices,
            lastUpdated: fetchDate,
            country: .germany
        )
    }
}
