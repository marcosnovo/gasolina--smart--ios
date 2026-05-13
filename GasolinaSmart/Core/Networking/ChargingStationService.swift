import Foundation

actor ChargingStationService {
    static let shared = ChargingStationService()

    private let overpassURL = "https://overpass-api.de/api/interpreter"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    func fetchStations(
        latitude: Double,
        longitude: Double,
        radiusKm: Double,
        maxResults: Int = 200
    ) async throws -> [ChargingStation] {
        let radiusMeters = Int(radiusKm * 1000)
        let query = """
        [out:json][timeout:20];
        node["amenity"="charging_station"](around:\(radiusMeters),\(latitude),\(longitude));
        out body \(maxResults);
        """

        guard var components = URLComponents(string: overpassURL) else {
            throw ChargingAPIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "data", value: query)]

        guard let url = components.url else { throw ChargingAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("GasolinaSmart/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ChargingAPIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let result = try JSONDecoder().decode(OverpassResponse.self, from: data)
        return result.elements.compactMap { $0.toChargingStation() }
    }
}

// MARK: - Overpass DTO

private struct OverpassResponse: Decodable, Sendable {
    let elements: [OverpassNode]
}

private struct OverpassNode: Decodable, Sendable {
    let type: String
    let id: Int
    let lat: Double
    let lon: Double
    let tags: [String: String]?

    func toChargingStation() -> ChargingStation? {
        guard type == "node" else { return nil }
        let t = tags ?? [:]

        let connections = parseConnections(from: t)
        let capacity = Int(t["capacity"] ?? "") ?? connections.reduce(0) { $0 + ($1.quantity ?? 0) }

        let name = t["name"]
            ?? t["brand"]
            ?? t["network"]
            ?? t["operator"]
            ?? "Punto de carga"

        let operatorName = t["operator"]
            ?? t["brand"]
            ?? t["network"]
            ?? t["name"]
            ?? "Desconocido"

        return ChargingStation(
            id: String(id),
            name: name,
            operatorName: operatorName,
            address: buildAddress(from: t),
            town: t["addr:city"] ?? t["is_in:municipality"] ?? "",
            province: t["addr:state"] ?? t["addr:province"] ?? t["is_in:province"] ?? "",
            latitude: lat,
            longitude: lon,
            connections: connections,
            numberOfPoints: max(capacity, 1),
            isOperational: t["disused"] != "yes",
            usageCost: parseCost(from: t),
            lastUpdated: nil
        )
    }

    private func buildAddress(from t: [String: String]) -> String {
        var parts: [String] = []
        if let street = t["addr:street"] {
            if let number = t["addr:housenumber"] {
                parts.append("\(street), \(number)")
            } else {
                parts.append(street)
            }
        }
        if let postcode = t["addr:postcode"] {
            parts.append(postcode)
        }
        if parts.isEmpty, let place = t["addr:place"] ?? t["addr:suburb"] {
            parts.append(place)
        }
        return parts.joined(separator: " · ")
    }

    private func parseCost(from t: [String: String]) -> String? {
        if t["fee"] == "no" || t["charge"] == "0" { return "Gratuito" }
        if let charge = t["charge"], !charge.isEmpty { return charge }
        if t["fee"] == "yes" { return "De pago" }
        return nil
    }

    private func parseConnections(from t: [String: String]) -> [ChargingConnection] {
        let socketTypes: [(key: String, name: String)] = [
            ("socket:type2_combo", "CCS (Tipo 2)"),
            ("socket:chademo", "CHAdeMO"),
            ("socket:type2", "Tipo 2 (Mennekes)"),
            ("socket:type2_cable", "Tipo 2 (cable)"),
            ("socket:type1", "Tipo 1"),
            ("socket:type1_combo", "CCS (Tipo 1)"),
            ("socket:schuko", "Schuko"),
            ("socket:cee_blue", "CEE azul"),
            ("socket:cee_red_16a", "CEE rojo 16A"),
            ("socket:cee_red_32a", "CEE rojo 32A"),
            ("socket:tesla_supercharger", "Tesla Supercharger"),
            ("socket:tesla_destination", "Tesla Destination"),
            ("socket:nacs", "NACS"),
        ]

        let stationPower = t["charging_station:output"].flatMap { parsePowerKW($0) }

        var connections: [ChargingConnection] = []
        for (key, name) in socketTypes {
            guard let value = t[key] else { continue }
            let count: Int
            if let parsed = Int(value), parsed > 0 {
                count = parsed
            } else if value.lowercased() == "yes" {
                count = 1
            } else {
                continue
            }

            let powerKW = t["\(key):output"].flatMap { parsePowerKW($0) }
                ?? inferPower(from: t, socketKey: key)
                ?? stationPower

            connections.append(ChargingConnection(
                typeName: name,
                powerKW: powerKW,
                quantity: count
            ))
        }

        if connections.isEmpty {
            let cap = Int(t["capacity"] ?? "") ?? 1
            connections.append(ChargingConnection(
                typeName: "Desconocido",
                powerKW: stationPower,
                quantity: max(cap, 1)
            ))
        }

        return connections
    }

    private func inferPower(from t: [String: String], socketKey: String) -> Double? {
        if let voltage = t["\(socketKey):voltage"].flatMap({ Double($0.replacingOccurrences(of: " V", with: "").replacingOccurrences(of: "V", with: "")) }),
           let current = t["\(socketKey):current"].flatMap({ Double($0.replacingOccurrences(of: " A", with: "").replacingOccurrences(of: "A", with: "")) }) {
            return (voltage * current) / 1000.0
        }
        return nil
    }

    private func parsePowerKW(_ value: String) -> Double? {
        let cleaned = value
            .replacingOccurrences(of: "kW", with: "")
            .replacingOccurrences(of: "kw", with: "")
            .replacingOccurrences(of: "KW", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }
}

enum ChargingAPIError: LocalizedError {
    case invalidURL
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "URL no válida"
        case .httpError(let code): "Error del servidor: \(code)"
        }
    }
}
