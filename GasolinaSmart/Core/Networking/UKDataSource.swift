import Foundation

actor UKDataSource: FuelDataSource {
    nonisolated let country: Country = .uk

    private(set) var lastFetchedAt: Date?

    private let baseURL = "https://developer.fuel-finder.service.gov.uk/public-api"
    private let session: URLSession

    private static let kmToMiles = 1.60934
    private static let isoFormatter = ISO8601DateFormatter()

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
        let radiusMiles = radiusKm / Self.kmToMiles

        guard var components = URLComponents(string: "\(baseURL)/stations/nearby") else {
            throw FuelDataSourceError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "radius", value: String(format: "%.2f", radiusMiles))
        ]

        guard let url = components.url else {
            throw FuelDataSourceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("GasolinaSmart/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FuelDataSourceError.httpError(0)
        }

        guard httpResponse.statusCode == 200 else {
            throw FuelDataSourceError.httpError(httpResponse.statusCode)
        }

        let decoded: UKResponse
        do {
            let decoder = JSONDecoder()
            decoded = try decoder.decode(UKResponse.self, from: data)
        } catch {
            throw FuelDataSourceError.parseError(error.localizedDescription)
        }

        lastFetchedAt = Date()

        return decoded.stations.compactMap { mapToFuelStation($0) }
    }

    // MARK: - Mapping

    private nonisolated func mapToFuelStation(_ dto: UKStationDTO) -> FuelStation? {
        var prices: [FuelType: Decimal] = [:]

        for priceDTO in dto.prices {
            if let fuelType = mapFuelType(priceDTO.fuel_type) {
                // UK prices are in pence per litre; convert to pounds
                let priceInPounds = Decimal(priceDTO.price) / 100
                prices[fuelType] = priceInPounds
            }
        }

        guard !prices.isEmpty else { return nil }

        let latestUpdate = dto.prices
            .compactMap { Self.isoFormatter.date(from: $0.updated_at) }
            .max() ?? Date()

        let address = [dto.address.line1, dto.address.town, dto.address.postcode]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        return FuelStation(
            id: "GB_\(dto.station_id)",
            name: dto.name,
            brand: dto.brand,
            address: address,
            municipality: dto.address.town ?? "",
            province: dto.address.county ?? "",
            latitude: dto.location.latitude,
            longitude: dto.location.longitude,
            prices: prices,
            lastUpdated: latestUpdate,
            country: .uk
        )
    }

    private nonisolated func mapFuelType(_ apiType: String) -> FuelType? {
        switch apiType {
        case "E10":  return .e10
        case "E5":   return .e5
        case "B7":   return .dieselA
        case "SDV":  return .dieselPremium
        case "SUL":  return .gasolina98
        default:     return nil
        }
    }
}

// MARK: - Decodable DTOs

private struct UKResponse: Decodable {
    let stations: [UKStationDTO]
}

private struct UKStationDTO: Decodable {
    let station_id: String
    let brand: String
    let name: String
    let address: UKAddressDTO
    let location: UKLocationDTO
    let prices: [UKPriceDTO]
}

private struct UKAddressDTO: Decodable {
    let line1: String?
    let town: String?
    let county: String?
    let postcode: String?
}

private struct UKLocationDTO: Decodable {
    let latitude: Double
    let longitude: Double
}

private struct UKPriceDTO: Decodable {
    let fuel_type: String
    let price: Double
    let updated_at: String
}
