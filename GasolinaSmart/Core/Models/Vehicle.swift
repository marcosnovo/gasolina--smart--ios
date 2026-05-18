import SwiftUI

enum VehicleType: String, Codable, CaseIterable, Hashable {
    case sedan
    case suv
    case hatchback
    case van
    case motorcycle

    var icon: String {
        switch self {
        case .sedan: "car.side.fill"
        case .suv: "car.rear.fill"
        case .hatchback: "car.fill"
        case .van: "box.truck.fill"
        case .motorcycle: "motorcycle.fill"
        }
    }

    var displayName: String {
        switch self {
        case .sedan: "Sedán"
        case .suv: "SUV"
        case .hatchback: "Compacto"
        case .van: "Furgoneta"
        case .motorcycle: "Moto"
        }
    }

    var modelFileName: String? {
        switch self {
        case .sedan: "sedan"
        case .suv: "suv"
        case .hatchback: "hatchback-sports"
        case .van: "van"
        case .motorcycle: nil
        }
    }
}

enum VehicleColor: String, Codable, CaseIterable, Hashable {
    case black
    case white
    case silver
    case red
    case blue
    case darkBlue
    case green
    case orange
    case yellow
    case brown

    var color: Color {
        switch self {
        case .black: Color(red: 0.15, green: 0.15, blue: 0.15)
        case .white: Color(red: 0.92, green: 0.92, blue: 0.92)
        case .silver: Color(red: 0.65, green: 0.67, blue: 0.70)
        case .red: Color(red: 0.85, green: 0.18, blue: 0.15)
        case .blue: Color(red: 0.20, green: 0.50, blue: 0.90)
        case .darkBlue: Color(red: 0.13, green: 0.22, blue: 0.45)
        case .green: Color(red: 0.20, green: 0.60, blue: 0.35)
        case .orange: Color(red: 0.92, green: 0.50, blue: 0.10)
        case .yellow: Color(red: 0.95, green: 0.80, blue: 0.10)
        case .brown: Color(red: 0.45, green: 0.30, blue: 0.18)
        }
    }

    var displayName: String {
        switch self {
        case .black: "Negro"
        case .white: "Blanco"
        case .silver: "Plata"
        case .red: "Rojo"
        case .blue: "Azul"
        case .darkBlue: "Azul oscuro"
        case .green: "Verde"
        case .orange: "Naranja"
        case .yellow: "Amarillo"
        case .brown: "Marrón"
        }
    }
}

struct Vehicle: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var brand: String
    /// Primary fuel: gasoline or diesel. Never `.glp` going forward — GLP is a
    /// dual-fuel flag (`hasGLP`) layered on top of the primary.
    var fuelType: FuelType
    /// True when the vehicle is also able to run on LPG/GLP. Realistic LPG
    /// installations always retain a gasoline primary for cold starts and for
    /// areas without LPG stations, so the two are always kept together.
    var hasGLP: Bool
    var tankSizeLiters: Double
    var consumptionL100Km: Double
    var vehicleType: VehicleType
    var vehicleColor: VehicleColor

    init(id: UUID = UUID(), name: String, brand: String = "",
         fuelType: FuelType, hasGLP: Bool = false,
         tankSizeLiters: Double = 50,
         consumptionL100Km: Double = 7.0,
         vehicleType: VehicleType = .sedan, vehicleColor: VehicleColor = .silver) {
        self.id = id
        self.name = name
        self.brand = brand
        // If the caller still passes .glp as primary (legacy callers), migrate
        // to the new shape immediately.
        if fuelType == .glp {
            self.fuelType = .gasolina95
            self.hasGLP = true
        } else {
            self.fuelType = fuelType
            self.hasGLP = hasGLP
        }
        self.tankSizeLiters = tankSizeLiters
        self.consumptionL100Km = consumptionL100Km
        self.vehicleType = vehicleType
        self.vehicleColor = vehicleColor
    }

    static let defaultVehicle = Vehicle(name: "Mi coche", fuelType: .gasolina95, tankSizeLiters: 50)

    static func defaultConsumption(for type: VehicleType) -> Double {
        switch type {
        case .sedan: 7.0
        case .suv: 9.0
        case .hatchback: 6.0
        case .van: 10.0
        case .motorcycle: 4.5
        }
    }

    static let commonBrands = [
        "Seat", "Renault", "Peugeot", "Citroën", "Volkswagen",
        "Toyota", "Ford", "Opel", "BMW", "Mercedes-Benz",
        "Audi", "Hyundai", "Kia", "Dacia", "Nissan",
        "Fiat", "Mazda", "Honda", "Škoda", "Volvo",
        "Cupra", "MG", "Tesla", "BYD", "Jeep"
    ]

    enum CodingKeys: String, CodingKey {
        case id, name, brand, fuelType, hasGLP, tankSizeLiters, consumptionL100Km, vehicleType, vehicleColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        brand = try container.decodeIfPresent(String.self, forKey: .brand) ?? ""

        // Migration: vehicles previously stored as GLP-primary are reshaped
        // into "gasolina95 primary + hasGLP = true". hasGLP didn't exist
        // before, so default to false for everything else.
        let storedFuel = try container.decode(FuelType.self, forKey: .fuelType)
        let storedHasGLP = try container.decodeIfPresent(Bool.self, forKey: .hasGLP) ?? false
        if storedFuel == .glp {
            fuelType = .gasolina95
            hasGLP = true
        } else {
            fuelType = storedFuel
            hasGLP = storedHasGLP
        }

        tankSizeLiters = try container.decode(Double.self, forKey: .tankSizeLiters)
        let vType = try container.decodeIfPresent(VehicleType.self, forKey: .vehicleType) ?? .sedan
        vehicleType = vType
        vehicleColor = try container.decodeIfPresent(VehicleColor.self, forKey: .vehicleColor) ?? .silver
        consumptionL100Km = try container.decodeIfPresent(Double.self, forKey: .consumptionL100Km)
            ?? Vehicle.defaultConsumption(for: vType)
    }
}
