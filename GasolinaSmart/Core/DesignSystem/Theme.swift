import SwiftUI

enum Theme {
    enum Colors {
        static let primary = Color.accentColor

        // Semantic system colors — adapts to light/dark automatically
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let tertiaryBackground = Color(.tertiarySystemBackground)
        static let groupedBackground = Color(.systemGroupedBackground)

        static let label = Color(.label)
        static let secondaryLabel = Color(.secondaryLabel)
        static let tertiaryLabel = Color(.tertiaryLabel)

        // Legacy aliases — prefer semantic names above
        static let cardBackground = Color(.secondarySystemBackground)

        // Accent — blue-teal, adaptive light/dark
        static let accent = Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.121, green: 0.639, blue: 0.620, alpha: 1)
                : UIColor(red: 0.054, green: 0.486, blue: 0.482, alpha: 1)
        })

        // Semantic pricing
        static let goodPrice = Color.green
        static let neutralPrice = Color(.secondaryLabel)
        static let moderatePrice = Color.orange
        static let expensivePrice = Color.red
        static let cheapPrice = Color.green
        static let saving = Color.green

        // Markers
        static let markerDefault = Color(.tertiaryLabel)
        static let markerBest = accent

    }

    enum Fonts {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.semibold)
        static let headline = Font.headline.weight(.semibold)
        static let body = Font.body
        static let subheadline = Font.subheadline
        static let caption = Font.caption
        static let mono = Font.system(.caption2, design: .monospaced)

        static let priceHero = Font.system(size: 48, weight: .bold, design: .rounded).monospacedDigit()
        static let priceLarge = Font.system(size: 36, weight: .bold, design: .rounded).monospacedDigit()
        static let price = Font.system(.title, design: .rounded, weight: .bold).monospacedDigit()
        static let priceSmall = Font.system(.headline, design: .rounded, weight: .semibold).monospacedDigit()

        static let sectionLabel = Font.system(size: 11, weight: .semibold)
        static let radarLabel = Font.system(size: 12, weight: .medium)
        static let pillLabel = Font.subheadline.weight(.medium)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 16
    }

}

// MARK: - Price Opportunity

enum PriceOpportunity {
    case great
    case fair
    case poor
    case unknown

    var color: Color {
        switch self {
        case .great: .green
        case .fair: .orange
        case .poor: .red
        case .unknown: Color(.secondaryLabel)
        }
    }

    var icon: String {
        switch self {
        case .great: "checkmark.seal.fill"
        case .fair: "equal.circle.fill"
        case .poor: "exclamationmark.circle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    var label: String {
        switch self {
        case .great: "Buena oportunidad"
        case .fair: "Precio normal"
        case .poor: "Por encima de la media"
        case .unknown: "Sin datos suficientes"
        }
    }
}

// MARK: - Formatters

private let priceFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumFractionDigits = 3
    f.maximumFractionDigits = 3
    f.decimalSeparator = ","
    return f
}()

private let currencyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "EUR"
    f.currencySymbol = "€"
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    return f
}()

extension Decimal {
    var priceFormatted: String {
        priceFormatter.string(from: NSDecimalNumber(decimal: self)) ?? "\(self)"
    }

    var savingFormatted: String {
        currencyFormatter.string(from: NSDecimalNumber(decimal: self)) ?? "\(self) €"
    }
}

extension Double {
    var distanceFormatted: String {
        if self < 1 {
            return String(format: "%.0f m", self * 1000)
        }
        return String(format: "%.1f km", self)
    }
}

