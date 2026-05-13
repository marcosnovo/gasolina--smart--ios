import Foundation
import CoreLocation

protocol FuelDataSource: AnyObject, Sendable {
    var country: Country { get }
    var lastFetchedAt: Date? { get }

    func fetchStations(
        latitude: Double,
        longitude: Double,
        radiusKm: Double
    ) async throws -> [FuelStation]
}

enum FuelDataSourceError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case parseError(String)
    case apiKeyRequired
    case countryNotSupported

    var errorDescription: String? {
        switch self {
        case .invalidURL: "URL no válida"
        case .httpError(let code): "Error del servidor: \(code)"
        case .parseError(let msg): "Error al procesar datos: \(msg)"
        case .apiKeyRequired: "Se requiere API key"
        case .countryNotSupported: "País no soportado"
        }
    }
}

@MainActor
final class FuelDataSourceRegistry: Observable {
    static let shared = FuelDataSourceRegistry()

    private var sources: [Country: any FuelDataSource] = [:]

    private init() {
        register(SpainDataSource())
        register(UKDataSource())
        register(FranceDataSource())
        register(GermanyDataSource())
        register(PortugalDataSource())
    }

    func register(_ source: any FuelDataSource) {
        sources[source.country] = source
    }

    func source(for country: Country) -> (any FuelDataSource)? {
        sources[country]
    }
}
