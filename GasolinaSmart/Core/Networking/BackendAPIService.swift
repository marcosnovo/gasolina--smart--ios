import Foundation

actor BackendAPIService {
    static let shared = BackendAPIService()

    #if DEBUG
    private var baseURL = "http://localhost:3000"
    #else
    private var baseURL = "https://api.gasolinasmart.com"
    #endif

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    func setBaseURL(_ url: String) {
        baseURL = url
    }

    // MARK: - Stations Nearby

    struct StationsResponse: Decodable, Sendable {
        let stations: [StationDTO]
        let count: Int
        let average_price: Double?
        let zone_count: Int?
        let last_updated: String?
    }

    struct StationDTO: Decodable, Sendable {
        let id: String
        let name: String
        let brand: String
        let address: String
        let municipality: String
        let province: String
        let latitude: Double
        let longitude: Double
        let updated_at: String
        let distance_km: Double
        let prices: [String: Double]

        func toFuelStation() -> FuelStation {
            var fuelPrices: [FuelType: Decimal] = [:]
            for (key, value) in prices {
                if let fuelType = FuelType(rawValue: key) {
                    fuelPrices[fuelType] = Decimal(value)
                }
            }

            let date = ISO8601DateFormatter().date(from: updated_at) ?? Date()

            return FuelStation(
                id: id,
                name: name,
                brand: brand,
                address: address,
                municipality: municipality,
                province: province,
                latitude: latitude,
                longitude: longitude,
                prices: fuelPrices,
                lastUpdated: date
            )
        }
    }

    func fetchStationsNearby(
        latitude: Double,
        longitude: Double,
        radiusKm: Double,
        fuelType: FuelType? = nil,
        limit: Int = 50
    ) async throws -> StationsResponse {
        var components = URLComponents(string: "\(baseURL)/api/stations")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "radius", value: String(radiusKm)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let fuelType {
            components.queryItems?.append(
                URLQueryItem(name: "fuel", value: fuelType.rawValue)
            )
        }

        guard let url = components.url else { throw BackendError.invalidURL }
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode(StationsResponse.self, from: data)
    }

    // MARK: - Cheapest

    struct CheapestResponse: Decodable, Sendable {
        let station: StationDTO?
        let average_price: Double?
        let zone_count: Int?
    }

    func fetchCheapest(
        latitude: Double,
        longitude: Double,
        radiusKm: Double,
        fuelType: FuelType
    ) async throws -> CheapestResponse {
        var components = URLComponents(string: "\(baseURL)/api/stations/cheapest")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "radius", value: String(radiusKm)),
            URLQueryItem(name: "fuel", value: fuelType.rawValue),
        ]

        guard let url = components.url else { throw BackendError.invalidURL }
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode(CheapestResponse.self, from: data)
    }

    // MARK: - Station Detail

    struct DetailResponse: Decodable, Sendable {
        let station: StationDTO
    }

    func fetchStationDetail(id: String) async throws -> StationDTO {
        guard let url = URL(string: "\(baseURL)/api/stations/\(id)") else {
            throw BackendError.invalidURL
        }
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        let detail = try JSONDecoder().decode(DetailResponse.self, from: data)
        return detail.station
    }

    // MARK: - Meta

    struct MetaResponse: Decodable, Sendable {
        let last_fetch: String?
        let station_count: Int
        let fetch_interval_minutes: Int
    }

    func fetchMeta() async throws -> MetaResponse {
        guard let url = URL(string: "\(baseURL)/api/meta") else {
            throw BackendError.invalidURL
        }
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode(MetaResponse.self, from: data)
    }

    // MARK: - Health

    func isHealthy() async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Helpers

    private nonisolated func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw BackendError.httpError(http.statusCode)
        }
    }
}

enum BackendError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "URL no válida"
        case .invalidResponse: "Respuesta no válida"
        case .httpError(let code): "Error del servidor: \(code)"
        }
    }
}
