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

        // Legacy aliases used across codebase
        static let deepBackground = Color(.systemBackground)
        static let surface = Color(.secondarySystemBackground)
        static let surfaceElevated = Color(.tertiarySystemBackground)
        static let cardBackground = Color(.secondarySystemBackground)
        static let ivory = Color(.label)

        // Accent — mint green, used for primary CTA and highlights
        static let accent = Color(red: 0.13, green: 0.61, blue: 0.35)
        static let amber = Color(red: 0.13, green: 0.61, blue: 0.35)

        // Semantic pricing
        static let goodPrice = Color.green
        static let neutralPrice = Color(.secondaryLabel)
        static let moderatePrice = Color.orange
        static let expensivePrice = Color.red
        static let cheapPrice = Color.green
        static let saving = Color.green

        // Markers
        static let markerDefault = Color(.tertiaryLabel)
        static let markerBest = Color(red: 0.13, green: 0.61, blue: 0.35)

        // Gradients — flat, no visual gradients
        static let amberGlow = LinearGradient(colors: [.blue, .blue], startPoint: .leading, endPoint: .trailing)
        static let accentGradient = amberGlow
        static let cheapGradient = LinearGradient(colors: [.green, .green], startPoint: .leading, endPoint: .trailing)
        static let surfaceGradient = LinearGradient(colors: [Color(.systemBackground), Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
        static let priceCardGradient = LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom)
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

        static let priceHero = Font.system(size: 48, weight: .bold, design: .rounded)
        static let priceLarge = Font.system(size: 36, weight: .bold, design: .rounded)
        static let price = Font.system(.title, design: .rounded, weight: .bold)
        static let priceSmall = Font.system(.headline, design: .rounded, weight: .semibold)

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

    enum Shadows {
        static func card(_ scheme: ColorScheme) -> some View { EmptyView() }
        static func cardShadow(_ scheme: ColorScheme) -> Color { .clear }
        static let soft = Color.clear
        static let medium = Color.clear
        static let elevated = Color.clear
        static let glow = Color.clear
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

extension Decimal {
    var priceFormatted: String {
        let number = NSDecimalNumber(decimal: self)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        formatter.decimalSeparator = ","
        return formatter.string(from: number) ?? "\(self)"
    }

    var savingFormatted: String {
        let number = NSDecimalNumber(decimal: self)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.currencySymbol = "€"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: number) ?? "\(self) €"
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

struct PremiumCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }
}

struct SectionCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.md)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }
}

extension View {
    func premiumCard() -> some View { modifier(PremiumCard()) }
    func sectionCard() -> some View { modifier(SectionCard()) }
}
