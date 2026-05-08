import Foundation

actor FuelAPIService {
    static let shared = FuelAPIService()

    private let baseURL = "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/"
    private let delegate = TLSSessionDelegate()
    private var session: URLSession?

    private init() {}

    private func getSession() -> URLSession {
        if let session { return session }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        config.urlCache = URLCache(memoryCapacity: 20_000_000, diskCapacity: 50_000_000)
        let newSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        session = newSession
        return newSession
    }

    func fetchStations() async throws -> [FuelStation] {
        guard let url = URL(string: baseURL) else {
            throw FuelAPIError.invalidURL
        }

        let urlSession = getSession()
        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FuelAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw FuelAPIError.httpError(httpResponse.statusCode)
        }

        return try await parseInBackground(data)
    }

    private func parseInBackground(_ data: Data) async throws -> [FuelStation] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let stations = try self.parseResponse(data)
                    continuation.resume(returning: stations)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private nonisolated func parseResponse(_ data: Data) throws -> [FuelStation] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let listaEstaciones = json?["ListaEESSPrecio"] as? [[String: Any]] else {
            throw FuelAPIError.parsingFailed
        }

        let dateString = json?["Fecha"] as? String
        let sourceDate = parseSourceDate(dateString) ?? Date()

        return listaEstaciones.compactMap { raw in
            parseStation(raw, sourceDate: sourceDate)
        }
    }

    private nonisolated func parseStation(_ raw: [String: Any], sourceDate: Date) -> FuelStation? {
        guard let idEstacion = raw["IDEESS"] as? String,
              let latString = raw["Latitud"] as? String,
              let lonString = raw["Longitud (WGS84)"] as? String,
              let lat = parseSpanishDecimal(latString),
              let lon = parseSpanishDecimal(lonString),
              lat >= 27 && lat <= 44,
              lon >= -19 && lon <= 5 else {
            return nil
        }

        let name = (raw["Rótulo"] as? String ?? "Estación").trimmingCharacters(in: .whitespaces)
        let address = (raw["Dirección"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let municipality = (raw["Municipio"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let province = (raw["Provincia"] as? String ?? "").trimmingCharacters(in: .whitespaces)

        var prices: [FuelType: Decimal] = [:]
        for fuelType in FuelType.allCases {
            if let priceString = raw[fuelType.apiFieldName] as? String,
               !priceString.isEmpty,
               let price = parseSpanishDecimal(priceString),
               price > 0 {
                prices[fuelType] = Decimal(price)
            }
        }

        guard !prices.isEmpty else { return nil }

        return FuelStation(
            id: idEstacion,
            name: name,
            brand: name,
            address: address,
            municipality: municipality,
            province: province,
            latitude: lat,
            longitude: lon,
            prices: prices,
            lastUpdated: sourceDate
        )
    }

    private nonisolated func parseSpanishDecimal(_ string: String) -> Double? {
        let cleaned = string
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    private nonisolated func parseSourceDate(_ dateString: String?) -> Date? {
        guard let dateString else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter.date(from: dateString)
    }
}

private final class TLSSessionDelegate: NSObject, URLSessionDelegate, Sendable {
    nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == "sedeaplicaciones.minetur.gob.es",
              let trust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }
        return (.useCredential, URLCredential(trust: trust))
    }
}

enum FuelAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case parsingFailed
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL: "URL no válida"
        case .invalidResponse: "Respuesta no válida del servidor"
        case .httpError(let code): "Error del servidor: \(code)"
        case .parsingFailed: "Error al procesar los datos"
        case .noData: "No hay datos disponibles"
        }
    }
}
