import Foundation

struct Vehicle: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var fuelType: FuelType
    var tankSizeLiters: Double

    init(id: UUID = UUID(), name: String, fuelType: FuelType, tankSizeLiters: Double = 50) {
        self.id = id
        self.name = name
        self.fuelType = fuelType
        self.tankSizeLiters = tankSizeLiters
    }

    static let defaultVehicle = Vehicle(name: "Mi coche", fuelType: .gasolina95, tankSizeLiters: 50)
}
