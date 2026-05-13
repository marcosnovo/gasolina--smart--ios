import Foundation

enum FuelType: String, CaseIterable, Codable, Identifiable, Sendable {
    case gasolina95 = "gasolina95"
    case gasolina98 = "gasolina98"
    case dieselA = "dieselA"
    case dieselPremium = "dieselPremium"
    case glp = "glp"
    case e5 = "e5"
    case e10 = "e10"
    case e85 = "e85"

    nonisolated var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gasolina95: "Gasolina 95"
        case .gasolina98: "Gasolina 98"
        case .dieselA: "Diésel A"
        case .dieselPremium: "Diésel Premium"
        case .glp: "GLP"
        case .e5: "E5"
        case .e10: "E10"
        case .e85: "E85"
        }
    }

    func displayName(for country: Country) -> String {
        switch (self, country) {
        case (.gasolina95, .spain): return "Gasolina 95"
        case (.gasolina95, .portugal): return "Gasolina 95"
        case (.gasolina98, .spain): return "Gasolina 98"
        case (.gasolina98, .uk): return "Super Unleaded"
        case (.gasolina98, .france): return "SP98"
        case (.dieselA, .spain), (.dieselA, .portugal): return "Diésel A"
        case (.dieselA, .uk): return "Diesel"
        case (.dieselA, .france): return "Gazole"
        case (.dieselA, .germany): return "Diesel"
        case (.dieselPremium, .spain): return "Diésel Premium"
        case (.dieselPremium, .uk): return "Premium Diesel"
        case (.glp, .spain): return "GLP"
        case (.glp, .france): return "GPLc"
        case (.glp, .portugal): return "GPL Auto"
        case (.e5, .uk): return "Unleaded (E5)"
        case (.e5, .france): return "SP95"
        case (.e5, .germany): return "Super E5"
        case (.e10, .uk): return "Unleaded (E10)"
        case (.e10, .france): return "E10"
        case (.e10, .germany): return "Super E10"
        case (.e85, .france): return "Superéthanol E85"
        default: return displayName
        }
    }

    var shortLabel: String {
        switch self {
        case .gasolina95: "G95"
        case .gasolina98: "G98"
        case .dieselA: "DA"
        case .dieselPremium: "D+"
        case .glp: "GLP"
        case .e5: "E5"
        case .e10: "E10"
        case .e85: "E85"
        }
    }

    func shortLabel(for country: Country) -> String {
        switch (self, country) {
        case (.gasolina98, .uk): return "SUL"
        case (.dieselA, .france): return "GOL"
        case (.glp, .france): return "GPL"
        case (.e85, _): return "E85"
        default: return shortLabel
        }
    }

    var officialName: String {
        switch self {
        case .gasolina95: "E5"
        case .gasolina98: "E5 Premium"
        case .dieselA: "Gasóleo A"
        case .dieselPremium: "Gasóleo Premium"
        case .glp: "GLP Auto"
        case .e5: "E5"
        case .e10: "E10"
        case .e85: "E85"
        }
    }

    var unit: String { "€/L" }

    func unit(for country: Country) -> String {
        switch country {
        case .uk: return "p/L"
        default: return "€/L"
        }
    }

    var apiFieldName: String {
        switch self {
        case .gasolina95: "Precio Gasolina 95 E5"
        case .gasolina98: "Precio Gasolina 98 E5"
        case .dieselA: "Precio Gasoleo A"
        case .dieselPremium: "Precio Gasoleo Premium"
        case .glp: "Precio Gases licuados del petróleo"
        case .e5: "Precio Gasolina 95 E5"
        case .e10: "Precio Gasolina 95 E10"
        case .e85: ""
        }
    }

    var icon: String {
        switch self {
        case .gasolina95, .gasolina98, .e5, .e10: "fuelpump"
        case .dieselA, .dieselPremium: "fuelpump.fill"
        case .glp: "leaf"
        case .e85: "leaf.fill"
        }
    }
}
