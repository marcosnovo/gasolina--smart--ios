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
                SmallWidgetView(data: data, mapSnapshot: entry.mapSnapshot)
            case .systemMedium:
                MediumWidgetView(data: data, mapSnapshot: entry.mapSnapshot)
            default:
                SmallWidgetView(data: data, mapSnapshot: entry.mapSnapshot)
            }
        } else {
            EmptyWidgetView()
        }
    }
}

// MARK: - Map Background

private struct MapBackground: View {
    let snapshotData: Data?

    var body: some View {
        GeometryReader { geo in
            if let data = snapshotData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else {
                Color(.systemGray5)
            }
        }
    }
}

// MARK: - Small Widget

private struct SmallWidgetView: View {
    let data: WidgetStationData
    let mapSnapshot: Data?

    var body: some View {
        ZStack(alignment: .bottom) {
            MapBackground(snapshotData: mapSnapshot)

            HStack(spacing: 10) {
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(widgetAccent)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(data.priceFormatted)
                            .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color(.label))
                        Text("€/L")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }

                    Text("\(data.brand) · \(data.distanceKm.distanceLabel)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(.secondaryLabel))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(8)
        }
        .widgetURL(data.deepLinkURL)
    }
}

// MARK: - Medium Widget

private struct MediumWidgetView: View {
    let data: WidgetStationData
    let mapSnapshot: Data?

    var body: some View {
        ZStack(alignment: .bottom) {
            MapBackground(snapshotData: mapSnapshot)

            HStack(spacing: 10) {
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(widgetAccent)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(data.brand)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                    Text(data.distanceKm.distanceLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(data.priceFormatted)
                            .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color(.label))
                        Text("€/L")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    Text(data.fuelTypeShort)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(10)
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
    CheapestStationEntry(date: .now, data: .placeholder, mapSnapshot: nil)
}

#Preview("Medium", as: .systemMedium) {
    CheapestStationWidget()
} timeline: {
    CheapestStationEntry(date: .now, data: .placeholder, mapSnapshot: nil)
}
