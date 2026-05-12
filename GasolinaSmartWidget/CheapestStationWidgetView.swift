import SwiftUI
import WidgetKit

private let widgetAccent = Color(red: 0.054, green: 0.486, blue: 0.482)

struct CheapestStationWidgetView: View {
    let entry: CheapestStationEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        if let data = entry.data {
            switch family {
            case .systemSmall:
                SmallWidgetView(data: data)
            case .systemMedium:
                MediumWidgetView(data: data)
            default:
                SmallWidgetView(data: data)
            }
        } else {
            EmptyWidgetView()
        }
    }
}

// MARK: - Small Widget

private struct SmallWidgetView: View {
    let data: WidgetStationData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 9, weight: .bold))
                Text(data.fuelTypeShort)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(widgetAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(widgetAccent.opacity(0.12))
            .clipShape(Capsule())

            Spacer(minLength: 4)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(data.priceFormatted)
                    .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color(.label))
                    .minimumScaleFactor(0.7)
                Text("€/L")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }

            Text(data.brand)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(.label))
                .lineLimit(1)
                .padding(.top, 1)

            Text(data.distanceKm.distanceLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))

            if let saving = data.savingFormatted {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 9))
                    Text(saving)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.green)
                .padding(.top, 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(data.navigationURL ?? data.deepLinkURL)
    }
}

// MARK: - Medium Widget

private struct MediumWidgetView: View {
    let data: WidgetStationData

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "fuelpump.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(data.fuelTypeShort)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(widgetAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(widgetAccent.opacity(0.12))
                .clipShape(Capsule())

                Spacer(minLength: 4)

                Text(data.brand)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)

                Text("\(data.address) · \(data.distanceKm.distanceLabel)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(1)
                    .padding(.top, 1)

                if let saving = data.savingFormatted {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                        Text("Ahorras \(saving)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.green)
                    .padding(.top, 4)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(data.priceFormatted)
                        .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color(.label))
                        .minimumScaleFactor(0.8)
                    Text("€/L")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }

                Spacer(minLength: 8)

                if let navURL = data.navigationURL {
                    Link(destination: navURL) {
                        HStack(spacing: 5) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Navegar")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(widgetAccent)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .widgetURL(data.deepLinkURL)
    }
}

// MARK: - Empty State

private struct EmptyWidgetView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "fuelpump")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(widgetAccent)
            Text("Abre Gasolina Smart")
                .font(.system(size: 12, weight: .semibold))
            Text("para ver gasolineras")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
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

#Preview("Small", as: .systemSmall) {
    CheapestStationWidget()
} timeline: {
    CheapestStationEntry(date: .now, data: .placeholder)
}

#Preview("Medium", as: .systemMedium) {
    CheapestStationWidget()
} timeline: {
    CheapestStationEntry(date: .now, data: .placeholder)
}
