import Foundation

actor FranceDataSource: FuelDataSource {
    nonisolated let country: Country = .france

    private(set) var lastFetchedAt: Date?

    private let baseURL = "https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/records"
    private let session: URLSession

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let fallbackFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - FuelDataSource

    func fetchStations(
        latitude: Double,
        longitude: Double,
        radiusKm: Double
    ) async throws -> [FuelStation] {
        guard var components = URLComponents(string: baseURL) else {
            throw FuelDataSourceError.invalidURL
        }

        let whereClause = "within_distance(geom, geom'POINT(\(longitude) \(latitude))', \(radiusKm)km)"

        components.queryItems = [
            URLQueryItem(name: "where", value: whereClause),
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "select", value: "id,adresse,ville,cp,geom,prix_nom,prix_valeur,prix_maj,marque")
        ]

        guard let url = components.url else {
            throw FuelDataSourceError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FuelDataSourceError.httpError(0)
        }

        guard httpResponse.statusCode == 200 else {
            throw FuelDataSourceError.httpError(httpResponse.statusCode)
        }

        let decoded: FranceResponse
        do {
            let decoder = JSONDecoder()
            decoded = try decoder.decode(FranceResponse.self, from: data)
        } catch {
            throw FuelDataSourceError.parseError(error.localizedDescription)
        }

        lastFetchedAt = Date()

        return groupAndMapStations(decoded.results)
    }

    // MARK: - Grouping & Mapping

    /// Each API record represents a single fuel price at a station.
    /// We group by station `id` to build complete FuelStation objects.
    private nonisolated func groupAndMapStations(_ records: [FranceRecordDTO]) -> [FuelStation] {
        let grouped = Dictionary(grouping: records, by: { $0.id })

        return grouped.compactMap { (stationId, records) -> FuelStation? in
            guard let first = records.first else { return nil }

            var prices: [FuelType: Decimal] = [:]
            var latestUpdate: Date?

            for record in records {
                guard let fuelType = mapFuelType(record.prix_nom) else { continue }

                if let value = record.prix_valeur {
                    prices[fuelType] = Decimal(value)
                }

                if let dateString = record.prix_maj {
                    let parsed = Self.isoFormatter.date(from: dateString)
                        ?? Self.fallbackFormatter.date(from: dateString)
                    if let date = parsed {
                        if latestUpdate == nil || date > latestUpdate! {
                            latestUpdate = date
                        }
                    }
                }
            }

            guard !prices.isEmpty else { return nil }

            let lat = first.geom?.lat ?? 0
            let lon = first.geom?.lon ?? 0

            return FuelStation(
                id: "FR_\(stationId)",
                name: first.marque ?? "Station",
                brand: first.marque ?? "",
                address: first.adresse ?? "",
                municipality: first.ville ?? "",
                province: first.cp ?? "",
                latitude: lat,
                longitude: lon,
                prices: prices,
                lastUpdated: latestUpdate ?? Date(),
                country: .france
            )
        }
    }

    private nonisolated func mapFuelType(_ name: String?) -> FuelType? {
        guard let name else { return nil }
        switch name {
        case "Gazole":  return .dieselA
        case "SP95":    return .e5
        case "SP98":    return .gasolina98
        case "E10":     return .e10
        case "E85":     return .e85
        case "GPLc":    return .glp
        default:        return nil
        }
    }
}

// MARK: - Decodable DTOs

private struct FranceResponse: Decodable {
    let total_count: Int?
    let results: [FranceRecordDTO]
}

private struct FranceRecordDTO: Decodable {
    let id: String
    let adresse: String?
    let ville: String?
    let cp: String?
    let geom: FranceGeomDTO?
    let prix_nom: String?
    let prix_valeur: Double?
    let prix_maj: String?
    let marque: String?
}

private struct FranceGeomDTO: Decodable {
    let lat: Double
    let lon: Double
}
