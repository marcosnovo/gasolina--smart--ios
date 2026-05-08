import Foundation

enum AlertType: String, Codable, CaseIterable, Sendable {
    case priceDropped
    case belowNearbyAverage
    case cheapestNearby
    case stationBecameExpensive
    case belowUserTargetPrice

    var displayName: String {
        switch self {
        case .priceDropped: "Bajada de precio"
        case .belowNearbyAverage: "Por debajo de la media"
        case .cheapestNearby: "Más barata cercana"
        case .stationBecameExpensive: "Subida de precio"
        case .belowUserTargetPrice: "Precio objetivo alcanzado"
        }
    }
}

struct PriceAlertRule: Codable, Identifiable, Sendable {
    let id: UUID
    var stationId: String?
    var locationRadiusKm: Double?
    var fuelType: FuelType
    var alertType: AlertType
    var threshold: Decimal?
    var isEnabled: Bool

    init(fuelType: FuelType, alertType: AlertType, stationId: String? = nil,
         locationRadiusKm: Double? = nil, threshold: Decimal? = nil, isEnabled: Bool = true) {
        self.id = UUID()
        self.stationId = stationId
        self.locationRadiusKm = locationRadiusKm
        self.fuelType = fuelType
        self.alertType = alertType
        self.threshold = threshold
        self.isEnabled = isEnabled
    }
}
