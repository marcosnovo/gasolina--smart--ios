import SwiftUI

enum Theme {
    enum Colors {
        static let primary = Color("AccentColor")
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let tertiaryBackground = Color(.tertiarySystemBackground)
        static let label = Color(.label)
        static let secondaryLabel = Color(.secondaryLabel)
        static let tertiaryLabel = Color(.tertiaryLabel)

        static let accent = Color(red: 0.16, green: 0.30, blue: 0.42)
        static let accentWarm = Color(red: 0.85, green: 0.62, blue: 0.25)

        static let goodPrice = Color(red: 0.20, green: 0.55, blue: 0.45)
        static let neutralPrice = Color(red: 0.45, green: 0.45, blue: 0.50)
        static let cheapPrice = Color(red: 0.20, green: 0.55, blue: 0.45)
        static let moderatePrice = Color(red: 0.85, green: 0.62, blue: 0.25)
        static let expensivePrice = Color(red: 0.70, green: 0.35, blue: 0.30)
        static let saving = Color(red: 0.20, green: 0.55, blue: 0.45)
        static let cardBackground = Color(.secondarySystemBackground)

        static let cheapGradient = LinearGradient(
            colors: [goodPrice, goodPrice.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let accentGradient = LinearGradient(
            colors: [accent, accent.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let priceCardGradient = LinearGradient(
            colors: [accent.opacity(0.08), accent.opacity(0.02)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let markerDefault = Color(red: 0.55, green: 0.55, blue: 0.60)
        static let markerBest = accent
    }

    enum Fonts {
        static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
        static let title = Font.system(.title2, design: .rounded, weight: .semibold)
        static let title3 = Font.system(.title3, design: .rounded, weight: .semibold)
        static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
        static let body = Font.system(.body, design: .default)
        static let subheadline = Font.system(.subheadline, design: .default)
        static let caption = Font.system(.caption, design: .default)
        static let mono = Font.system(.caption2, design: .monospaced)
        static let price = Font.system(.title, design: .rounded, weight: .bold)
        static let priceHero = Font.system(size: 38, weight: .bold, design: .rounded)
        static let priceLarge = Font.system(size: 42, weight: .bold, design: .rounded)
        static let priceSmall = Font.system(.headline, design: .rounded, weight: .semibold)
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
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    enum Shadows {
        static func card(_ scheme: ColorScheme) -> some View {
            EmptyView()
        }

        static func cardShadow(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? .white.opacity(0.04) : .black.opacity(0.08)
        }

        static let soft = Color.black.opacity(0.06)
        static let medium = Color.black.opacity(0.1)
        static let elevated = Color.black.opacity(0.15)
    }
}

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
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xxl, style: .continuous))
            .shadow(color: Theme.Shadows.cardShadow(colorScheme), radius: 16, y: 8)
    }
}

struct SectionCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
    }
}

extension View {
    func premiumCard() -> some View {
        modifier(PremiumCard())
    }

    func sectionCard() -> some View {
        modifier(SectionCard())
    }
}
