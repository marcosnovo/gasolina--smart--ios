import SwiftUI
import WidgetKit

private let accentGreen = Color(red: 0.18, green: 0.72, blue: 0.36)

private struct WidgetColors {
    let isDark: Bool

    var background: Color { isDark ? Color(white: 0.08) : Color(white: 0.95) }
    var streetLine: Color { isDark ? .white : .black }
    var streetOpacity: Double { isDark ? 0.06 : 0.06 }
    var streetThinOpacity: Double { isDark ? 0.1 : 0.08 }
    var blockOpacity: Double { isDark ? 0.04 : 0.05 }
    var primaryText: Color { isDark ? .white : .black }
    var secondaryText: Color { isDark ? .white.opacity(0.45) : .black.opacity(0.35) }
    var pricePillBg: Color { isDark ? .white : Color(white: 0.12) }
    var pricePillText: Color { isDark ? .black : .white }
    var pricePillUnit: Color { isDark ? .black.opacity(0.4) : .white.opacity(0.5) }
    var gradientEnd: Double { isDark ? 0.9 : 0.45 }
    var gradientMid: Double { isDark ? 0.65 : 0.3 }
    var gradientStart: Double { isDark ? 0.35 : 0.12 }
}

struct CheapestStationWidgetView: View {
    let entry: CheapestStationEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        let colors = WidgetColors(isDark: entry.isDark)
        if let data = entry.data {
            switch family {
            case .systemSmall:
                SmallWidgetView(data: data, colors: colors)
            case .systemMedium:
                MediumWidgetView(data: data, colors: colors)
            default:
                SmallWidgetView(data: data, colors: colors)
            }
        } else {
            EmptyWidgetView(colors: colors)
        }
    }
}

// MARK: - Small Widget

private struct SmallWidgetView: View {
    let data: WidgetStationData
    let colors: WidgetColors

    var body: some View {
        ZStack {
            WidgetBackground(colors: colors)

            VStack(spacing: 0) {
                Spacer(minLength: 2)

                SavingBadge(saving: data.savingFormatted, isDark: colors.isDark)
                    .padding(.bottom, 5)

                FuelCircle(data: data, size: 56)

                PricePill(data: data, colors: colors, fontSize: 18)
                    .padding(.top, -8)

                Spacer(minLength: 4)

                HStack(spacing: 0) {
                    Text(data.address)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(colors.primaryText)
                        .lineLimit(1)
                    Text("  \(data.distanceKm.distanceLabel)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(colors.secondaryText)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14)

                Text(data.municipality)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentGreen)
                    .lineLimit(1)
                    .padding(.top, 1)

                Spacer(minLength: 6)
            }
        }
        .widgetURL(data.navigateDeepLinkURL)
    }
}

// MARK: - Medium Widget

private struct MediumWidgetView: View {
    let data: WidgetStationData
    let colors: WidgetColors

    var body: some View {
        ZStack {
            WidgetBackground(colors: colors, gradientEdge: .trailing)

            HStack(spacing: 0) {
                // Left: saving + circle + price
                VStack(spacing: 0) {
                    Spacer(minLength: 2)

                    SavingBadge(saving: data.savingFormatted, isDark: colors.isDark)
                        .padding(.bottom, 5)

                    FuelCircle(data: data, size: 62)

                    PricePill(data: data, colors: colors, fontSize: 18)
                        .padding(.top, -8)

                    Spacer(minLength: 2)
                }
                .frame(width: 130)

                // Right: brand + address + navigate
                VStack(alignment: .trailing, spacing: 0) {
                    Spacer(minLength: 8)

                    Text(data.brand)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(colors.primaryText)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    HStack(spacing: 0) {
                        Text(data.address)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                        Text("  \(data.distanceKm.distanceLabel)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(colors.secondaryText)
                            .lineLimit(1)
                            .layoutPriority(1)
                    }
                    .foregroundStyle(colors.primaryText)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 2)

                    Text(data.municipality)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accentGreen)
                        .lineLimit(1)
                        .padding(.top, 1)

                    Spacer()

                    Link(destination: data.navigateDeepLinkURL) {
                        HStack(spacing: 5) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(WidgetLoc.navigate)
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(accentGreen)
                        .clipShape(Capsule())
                    }

                    Spacer(minLength: 8)
                }
                .padding(.trailing, 16)
            }
        }
        .widgetURL(data.deepLinkURL)
    }
}

// MARK: - Saving Badge

private struct SavingBadge: View {
    let saving: String?
    var isDark: Bool = true

    var body: some View {
        if let saving {
            HStack(spacing: 3) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 8))
                Text(saving)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundStyle(accentGreen)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(isDark ? .black.opacity(0.55) : .white.opacity(0.85))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(isDark ? .white.opacity(0.15) : .black.opacity(0.08), lineWidth: 0.5))
        } else {
            Spacer().frame(height: 8)
        }
    }
}

// MARK: - Price Pill

private struct PricePill: View {
    let data: WidgetStationData
    let colors: WidgetColors
    let fontSize: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(data.priceFormatted)
                .font(.system(size: fontSize, weight: .bold, design: .rounded).monospacedDigit())
            Text(data.fuelTypeUnit ?? "€/L")
                .font(.system(size: fontSize * 0.5, weight: .semibold))
                .foregroundStyle(colors.pricePillUnit)
        }
        .foregroundStyle(colors.pricePillText)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(colors.pricePillBg)
        .clipShape(Capsule())
    }
}

// MARK: - Fuel Circle

private struct FuelCircle: View {
    let data: WidgetStationData
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(accentGreen)

            VStack(spacing: 1) {
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: size * 0.24, weight: .semibold))
                Text(data.fuelTypeShort)
                    .font(.system(size: size * 0.18, weight: .bold))
            }
            .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Background

private struct WidgetBackground: View {
    let colors: WidgetColors
    var gradientEdge: Edge = .bottom

    var body: some View {
        ZStack {
            colors.background

            MapStreets()
                .stroke(colors.streetLine.opacity(colors.streetOpacity), lineWidth: 1.2)

            MapStreets()
                .stroke(colors.streetLine.opacity(colors.streetThinOpacity), lineWidth: 0.4)
                .offset(x: 7, y: 5)

            StreetBlocks()
                .stroke(colors.streetLine.opacity(colors.blockOpacity), lineWidth: 2.5)

            let stops: [Color] = [
                accentGreen.opacity(0),
                accentGreen.opacity(colors.gradientStart),
                accentGreen.opacity(colors.gradientMid),
                accentGreen.opacity(colors.gradientEnd)
            ]

            if gradientEdge == .trailing {
                HStack {
                    Spacer()
                    LinearGradient(
                        colors: stops,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 200)
                }
            } else {
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: stops,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 110)
                }
            }
        }
    }
}

private struct MapStreets: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 28
        let angle: CGFloat = 20 * .pi / 180

        for i in stride(from: -rect.height * 1.5, through: rect.width + rect.height * 1.5, by: spacing) {
            let x1 = i + rect.height * tan(angle)
            path.move(to: CGPoint(x: x1, y: -10))
            path.addLine(to: CGPoint(x: i, y: rect.height + 10))
        }

        for j in stride(from: -rect.width * 1.5, through: rect.height + rect.width * 1.5, by: spacing) {
            let y1 = j - rect.width * tan(angle)
            path.move(to: CGPoint(x: -10, y: y1))
            path.addLine(to: CGPoint(x: rect.width + 10, y: j))
        }

        return path
    }
}

private struct StreetBlocks: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.width * 0.15, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.35, y: rect.height))

        path.move(to: CGPoint(x: rect.width * 0.7, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.55, y: rect.height))

        path.move(to: CGPoint(x: 0, y: rect.height * 0.35))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.25))

        path.move(to: CGPoint(x: 0, y: rect.height * 0.7))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.8))

        return path
    }
}

// MARK: - Empty State

private struct EmptyWidgetView: View {
    let colors: WidgetColors

    var body: some View {
        ZStack {
            WidgetBackground(colors: colors)

            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(accentGreen)
                    Image(systemName: "fuelpump")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: 52, height: 52)

                Text(WidgetLoc.openApp)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(colors.primaryText)
                Text(WidgetLoc.toSeeStations)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(colors.secondaryText)
            }
        }
    }
}

// MARK: - Helpers

private extension Double {
    var distanceLabel: String {
        if self < 1 {
            return String(format: "%.0f m", self * 1000)
        }
        return String(format: "%.1f km", self)
    }
}

// MARK: - Previews

#Preview("Small Dark", as: .systemSmall) {
    CheapestStationDarkWidget()
} timeline: {
    CheapestStationEntry(date: .now, data: .placeholder, isDark: true)
}

#Preview("Small Light", as: .systemSmall) {
    CheapestStationLightWidget()
} timeline: {
    CheapestStationEntry(date: .now, data: .placeholder, isDark: false)
}

#Preview("Medium Dark", as: .systemMedium) {
    CheapestStationDarkWidget()
} timeline: {
    CheapestStationEntry(date: .now, data: .placeholder, isDark: true)
}

#Preview("Medium Light", as: .systemMedium) {
    CheapestStationLightWidget()
} timeline: {
    CheapestStationEntry(date: .now, data: .placeholder, isDark: false)
}
