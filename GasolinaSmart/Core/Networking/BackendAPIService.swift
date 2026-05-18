import Foundation

actor BackendAPIService {
    static let shared = BackendAPIService()
    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    private var baseURL = "https://gasolina-smart-api.marcosnovo.workers.dev"
    // gov.uk's edge filters Cloudflare Workers' outbound IPs (HTTP 525). Until
    // that's resolved, UK requests route to the legacy Railway backend.
    private let ukBaseURL = "https://gasolina-smart-ios-production.up.railway.app"

    private let session: URLSession
    // Reused across every API call. JSONDecoder is thread-safe for decoding
    // (Foundation guarantee) and is private actor state, so this is safe.
    private let decoder = JSONDecoder()
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

    private func base(for country: Country?) -> String {
        country == .uk ? ukBaseURL : baseURL
    }

    private func base(forStationId id: String) -> String {
        if let prefix = id.split(separator: "_").first,
           let country = Country(rawValue: String(prefix)) {
            return base(for: country)
        }
        return baseURL
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
        var components = URLComponents(string: "\(base(for: country))/api/stations")!
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
        return try decoder.decode(StationsResponse.self, from: data)
    }

    // MARK: - All EV charging stations of a country

    struct ChargingResponse: Decodable, Sendable {
        let stations: [ChargingDTO]
        let count: Int
        let last_updated: String?
    }

    struct ChargingConnectionDTO: Decodable, Sendable {
        let typeName: String
        let powerKW: Double?
        let quantity: Int?
    }

    struct ChargingDTO: Decodable, Sendable {
        let id: String
        let name: String
        let operator_name: String?
        let address: String
        let municipality: String
        let province: String
        let latitude: Double
        let longitude: Double
        let country: String
        let number_of_points: Int
        let is_operational: Bool
        let usage_cost: String?
        let max_power_kw: Double?
        let connections: [ChargingConnectionDTO]
        let updated_at: String

        func toChargingStation() -> ChargingStation {
            let conns = connections.map {
                ChargingConnection(typeName: $0.typeName, powerKW: $0.powerKW, quantity: $0.quantity)
            }
            return ChargingStation(
                id: id,
                name: name,
                operatorName: operator_name ?? "",
                address: address,
                town: municipality,
                province: province,
                latitude: latitude,
                longitude: longitude,
                connections: conns,
                numberOfPoints: number_of_points,
                isOperational: is_operational,
                usageCost: usage_cost,
                lastUpdated: BackendAPIService.isoFormatter.date(from: updated_at)
            )
        }
    }

    func fetchAllChargingStations(country: Country = .spain) async throws -> ChargingResponse {
        var components = URLComponents(string: "\(base(for: country))/api/charging/all")!
        components.queryItems = [
            URLQueryItem(name: "country", value: country.rawValue),
        ]
        guard let url = components.url else { throw BackendError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(ChargingResponse.self, from: data)
    }

    // MARK: - All stations of a country (full snapshot)

    func fetchAllStations(country: Country = .spain) async throws -> StationsResponse {
        var components = URLComponents(string: "\(base(for: country))/api/stations/all")!
        components.queryItems = [
            URLQueryItem(name: "country", value: country.rawValue),
        ]
        guard let url = components.url else { throw BackendError.invalidURL }

        // Whole-country payloads can be a few MB. Allow more time than the
        // default request timeout (10 s) for this one call.
        var request = URLRequest(url: url)
        request.timeoutInterval = 60

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(StationsResponse.self, from: data)
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
        var components = URLComponents(string: "\(base(for: country))/api/stations/cheapest")!
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
        return try decoder.decode(CheapestResponse.self, from: data)
    }

    // MARK: - Station Detail

    struct DetailResponse: Decodable, Sendable {
        let station: StationDTO
    }

    func fetchStationDetail(id: String) async throws -> StationDTO {
        guard let url = URL(string: "\(base(forStationId: id))/api/stations/\(id)") else {
            throw BackendError.invalidURL
        }
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        let detail = try decoder.decode(DetailResponse.self, from: data)
        return detail.station
    }

    // MARK: - Meta

    struct MetaResponse: Decodable, Sendable {
        let last_fetch: String?
        let station_count: Int
        // Workers backend doesn't return this; Railway does. Optional so both work.
        let fetch_interval_minutes: Int?
    }

    func fetchMeta(country: Country = .spain) async throws -> MetaResponse {
        var components = URLComponents(string: "\(base(for: country))/api/meta")!
        components.queryItems = [
            URLQueryItem(name: "country", value: country.rawValue),
        ]
        guard let url = components.url else { throw BackendError.invalidURL }
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try decoder.decode(MetaResponse.self, from: data)
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
        return try decoder.decode([CountryInfo].self, from: data)
    }

    // MARK: - Price History

    struct PriceHistoryEntry: Decodable, Sendable {
        let recorded_at: String
        let fuel_type: String
        let price: Double
    }

    func fetchPriceHistory(stationId: String, days: Int = 30) async throws -> [PriceHistoryEntry] {
        var components = URLComponents(string: "\(base(forStationId: stationId))/api/history/\(stationId)")!
        components.queryItems = [
            URLQueryItem(name: "days", value: String(days)),
        ]
        guard let url = components.url else { throw BackendError.invalidURL }
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try decoder.decode([PriceHistoryEntry].self, from: data)
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
