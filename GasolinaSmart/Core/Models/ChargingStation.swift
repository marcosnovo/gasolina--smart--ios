import Foundation
import CoreLocation

struct ChargingConnection: Equatable, Sendable {
    let typeName: String
    let powerKW: Double?
    let quantity: Int?
}

struct ChargingStation: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let operatorName: String
    let address: String
    let town: String
    let province: String
    let latitude: Double
    let longitude: Double
    let connections: [ChargingConnection]
    let numberOfPoints: Int
    let isOperational: Bool
    let usageCost: String?
    let lastUpdated: Date?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distanceKm(from location: CLLocation) -> Double {
        GeoDistance.distance(
            fromLatitude: location.coordinate.latitude,
            fromLongitude: location.coordinate.longitude,
            toLatitude: latitude,
            toLongitude: longitude
        ) / 1000.0
    }

    func distanceKm(from coordinate: CLLocationCoordinate2D) -> Double {
        GeoDistance.distance(
            fromLatitude: coordinate.latitude,
            fromLongitude: coordinate.longitude,
            toLatitude: latitude,
            toLongitude: longitude
        ) / 1000.0
    }

    var maxPowerKW: Double? {
        connections.compactMap(\.powerKW).max()
    }

    var speedCategory: SpeedCategory {
        guard let maxPower = maxPowerKW else { return .unknown }
        if maxPower >= 50 { return .fast }
        if maxPower >= 22 { return .semiFast }
        return .slow
    }

    var connectionSummary: String {
        let types = Set(connections.map(\.typeName)).sorted()
        return types.joined(separator: ", ")
    }

    enum SpeedCategory {
        case fast, semiFast, slow, unknown

        var label: String {
            switch self {
            case .fast: "Carga rápida"
            case .semiFast: "Semi-rápida"
            case .slow: "Carga lenta"
            case .unknown: "Desconocida"
            }
        }

        var icon: String {
            switch self {
            case .fast: "bolt.fill"
            case .semiFast: "bolt"
            case .slow: "bolt.slash"
            case .unknown: "questionmark"
            }
        }
    }

    static func == (lhs: ChargingStation, rhs: ChargingStation) -> Bool {
        lhs.id == rhs.id
    }
}
