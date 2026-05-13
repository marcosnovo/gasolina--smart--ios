import Foundation
import CoreLocation

/// Data source for Portuguese fuel stations using the DGEG API.
/// No authentication required. Note: commercial use is restricted; app must be free-only for Portugal.
actor PortugalDataSource: FuelDataSource {

    // MARK: - FuelDataSource

    nonisolated let country: Country = .portugal
    private(set) var lastFetchedAt: Date?

    // MARK: - Constants

    private let endpoint = "https://precoscombustiveis.dgeg.gov.pt/api/PrecoComb/PesquisarPostos"

    /// DGEG fuel type identifiers
    private enum DGEGFuelId {
        static let gasolina95 = 3201
        static let gasoleoSimples = 2101
        static let gplAuto = 3001
    }

    // MARK: - DTOs

    private struct DGEGResponse: Decodable {
        let resultado: [StationDTO]
    }

    private struct StationDTO: Decodable {
        let Id: Int
        let Nome: String
        let Morada: String?
        let Localidade: String?
        let CodPostal: String?
        let Latitude: String?
        let Longitude: String?
        let Municipio: String?
        let Distrito: String?
        let Marca: String?
        let Combustiveis: [FuelDTO]?
    }

    private struct FuelDTO: Decodable {
        let Id: Int
        let Descritivo: String?
        let Preco: String?
    }

    private struct RequestBody: Encodable {
        let IdsTiposComb: String
        let IdDistrito: Int
        let IdMunicipio: Int
        let IdFreguesia: Int
        let Marca: String
        let Combustivel: String
    }

    // MARK: - Fetch

    func fetchStations(
        latitude: Double,
        longitude: Double,
        radiusKm: Double
    ) async throws -> [FuelStation] {
        guard let url = URL(string: endpoint) else {
            throw FuelDataSourceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RequestBody(
            IdsTiposComb: "\(DGEGFuelId.gasolina95),\(DGEGFuelId.gasoleoSimples),\(DGEGFuelId.gplAuto)",
            IdDistrito: 0,
            IdMunicipio: 0,
            IdFreguesia: 0,
            Marca: "",
            Combustivel: ""
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FuelDataSourceError.httpError(0)
        }
        guard httpResponse.statusCode == 200 else {
            throw FuelDataSourceError.httpError(httpResponse.statusCode)
        }

        let decoded: DGEGResponse
        do {
            decoded = try JSONDecoder().decode(DGEGResponse.self, from: data)
        } catch {
            throw FuelDataSourceError.parseError(error.localizedDescription)
        }

        let now = Date()
        lastFetchedAt = now

        let origin = CLLocation(latitude: latitude, longitude: longitude)
        let radiusMeters = radiusKm * 1000

        return decoded.resultado.compactMap { dto in
            guard let station = mapStation(dto, fetchDate: now) else { return nil }
            let dist = origin.distance(from: CLLocation(latitude: station.latitude, longitude: station.longitude))
            return dist <= radiusMeters ? station : nil
        }
    }

    // MARK: - Mapping

    private nonisolated func mapStation(_ dto: StationDTO, fetchDate: Date) -> FuelStation? {
        guard let latString = dto.Latitude,
              let lonString = dto.Longitude,
              let lat = Double(latString),
              let lon = Double(lonString) else {
            return nil
        }

        var prices: [FuelType: Decimal] = [:]

        if let fuels = dto.Combustiveis {
            for fuel in fuels {
                guard let priceString = fuel.Preco,
                      let price = Decimal(string: priceString),
                      price > 0 else {
                    continue
                }

                let fuelType: FuelType? = switch fuel.Id {
                case DGEGFuelId.gasolina95:
                    .gasolina95
                case DGEGFuelId.gasoleoSimples:
                    .dieselA
                case DGEGFuelId.gplAuto:
                    .glp
                default:
                    nil
                }

                if let fuelType {
                    prices[fuelType] = price
                }
            }
        }

        guard !prices.isEmpty else { return nil }

        let address = [dto.Morada, dto.CodPostal]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        return FuelStation(
            id: "PT_\(dto.Id)",
            name: dto.Nome,
            brand: dto.Marca ?? dto.Nome,
            address: address,
            municipality: dto.Municipio ?? dto.Localidade ?? "",
            province: dto.Distrito ?? "",
            latitude: lat,
            longitude: lon,
            prices: prices,
            lastUpdated: fetchDate,
            country: .portugal
        )
    }
}
