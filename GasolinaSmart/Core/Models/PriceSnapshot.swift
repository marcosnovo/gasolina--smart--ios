import Foundation

struct PriceSnapshot: Codable, Identifiable, Sendable {
    nonisolated var id: String { "\(stationId)-\(fuelType.rawValue)-\(timestamp.timeIntervalSince1970)" }
    let stationId: String
    let fuelType: FuelType
    let price: Decimal
    let timestamp: Date
    let sourceDate: Date
}
