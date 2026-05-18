import Foundation

actor BackendAPIService {
    static let shared = BackendAPIService()
    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    private var baseURL = "https://gasolina-smart-api.marcosnovo.workers.dev"

    private let session: URLSession
    private var lastHealthCheck: Date?
    private var lastHealthResult: Bool = true

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
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
        let country: String?
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

            let date = BackendAPIService.isoFormatter.date(from: updated_at) ?? Date()

            let stationCountry: Country
            if let code = country, let c = Country(rawValue: code) {
                stationCountry = c
            } else if id.count > 3, let prefix = id.split(separator: "_").first,
                      let c = Country(rawValue: String(prefix)) {
                stationCountry = c
            } else {
                stationCountry = .spain
            }

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
                lastUpdated: date,
                country: stationCountry
            )
        }
    }

    func fetchStationsNearby(
        latitude: Double,
        longitude: Double,
        radiusKm: Double,
        country: Country = .spain,
        fuelType: FuelType? = nil,
        limit: Int = 50
    ) async throws -> StationsResponse {
        var components = URLComponents(string: "\(baseURL)/api/stations")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "radius", value: String(radiusKm)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "country", value: country.rawValue),
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
        fuelType: FuelType,
        country: Country = .spain
    ) async throws -> CheapestResponse {
        var components = URLComponents(string: "\(baseURL)/api/stations/cheapest")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "radius", value: String(radiusKm)),
            URLQueryItem(name: "fuel", value: fuelType.rawValue),
            URLQueryItem(name: "country", value: country.rawValue),
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

    func fetchMeta(country: Country = .spain) async throws -> MetaResponse {
        var components = URLComponents(string: "\(baseURL)/api/meta")!
        components.queryItems = [
            URLQueryItem(name: "country", value: country.rawValue),
        ]
        guard let url = components.url else { throw BackendError.invalidURL }
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode(MetaResponse.self, from: data)
    }

    // MARK: - Countries

    struct CountryInfo: Decodable, Sendable {
        let code: String
        let displayName: String
        let currency: String
        let currencySymbol: String
        let supportedFuels: [String]
        let dataFreshness: String
        let attribution: Attribution
        let stationsCount: Int
        let lastFetchedAt: String?

        struct Attribution: Decodable, Sendable {
            let text: String
            let url: String
            let license: String
        }
    }

    func fetchCountries() async throws -> [CountryInfo] {
        guard let url = URL(string: "\(baseURL)/api/countries") else {
            throw BackendError.invalidURL
        }
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode([CountryInfo].self, from: data)
    }

    // MARK: - Price History

    struct PriceHistoryEntry: Decodable, Sendable {
        let recorded_at: String
        let fuel_type: String
        let price: Double
    }

    func fetchPriceHistory(stationId: String, days: Int = 30) async throws -> [PriceHistoryEntry] {
        var components = URLComponents(string: "\(baseURL)/api/history/\(stationId)")!
        components.queryItems = [
            URLQueryItem(name: "days", value: String(days)),
        ]
        guard let url = components.url else { throw BackendError.invalidURL }
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode([PriceHistoryEntry].self, from: data)
    }

    // MARK: - Health

    func isHealthy() async -> Bool {
        if let lastCheck = lastHealthCheck,
           Date().timeIntervalSince(lastCheck) < 120 {
            return lastHealthResult
        }

        guard let url = URL(string: "\(baseURL)/health") else { return false }
        do {
            let (_, response) = try await session.data(from: url)
            let healthy = (response as? HTTPURLResponse)?.statusCode == 200
            lastHealthCheck = Date()
            lastHealthResult = healthy
            return healthy
        } catch {
            lastHealthCheck = Date()
            lastHealthResult = false
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
