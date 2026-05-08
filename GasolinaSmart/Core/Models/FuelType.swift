import Foundation

enum FuelType: String, CaseIterable, Codable, Identifiable, Sendable {
    case gasolina95 = "gasolina95"
    case gasolina98 = "gasolina98"
    case dieselA = "dieselA"
    case dieselPremium = "dieselPremium"
    case glp = "glp"

    nonisolated var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gasolina95: "Gasolina 95"
        case .gasolina98: "Gasolina 98"
        case .dieselA: "Diésel A"
        case .dieselPremium: "Diésel Premium"
        case .glp: "GLP"
        }
    }

    var shortLabel: String {
        switch self {
        case .gasolina95: "G95"
        case .gasolina98: "G98"
        case .dieselA: "DA"
        case .dieselPremium: "D+"
        case .glp: "GLP"
        }
    }

    var unit: String { "€/L" }

    var apiFieldName: String {
        switch self {
        case .gasolina95: "Precio Gasolina 95 E5"
        case .gasolina98: "Precio Gasolina 98 E5"
        case .dieselA: "Precio Gasoleo A"
        case .dieselPremium: "Precio Gasoleo Premium"
        case .glp: "Precio Gases licuados del petróleo"
        }
    }

    var icon: String {
        switch self {
        case .gasolina95, .gasolina98: "fuelpump"
        case .dieselA, .dieselPremium: "fuelpump.fill"
        case .glp: "leaf"
        }
    }
}
