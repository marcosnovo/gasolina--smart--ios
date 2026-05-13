import SwiftUI

struct RadarPanel: View {
    let station: FuelStation
    let fuelType: FuelType
    let averagePrice: Decimal?
    let tankLiters: Double
    let distance: Double
    let onTap: () -> Void
    let onNavigate: () -> Void

    @Environment(StationStore.self) private var store
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    private var loc: Loc { preferences.loc }

    private var price: Decimal? {
        station.price(for: fuelType)
    }

    private var opportunity: PriceOpportunity {
        store.priceOpportunity(
            stationPrice: price,
            averagePrice: averagePrice,
            tankLiters: tankLiters
        )
    }

    private var saving: Decimal? {
        guard let price, let averagePrice else { return nil }
        let s = (averagePrice - price) * Decimal(tankLiters)
        return s > 0 ? s : nil
    }

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        HStack(spacing: 0) {
            // Left: saving badge + fuel circle + price pill
            VStack(spacing: 0) {
                if let saving {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 9))
                        Text(saving.savingFormatted)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Theme.Colors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isDark ? Color.black.opacity(0.4) : Color.white.opacity(0.85))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(isDark ? .white.opacity(0.1) : .black.opacity(0.06), lineWidth: 0.5))
                    .padding(.bottom, 6)
                }

                if let price {
                    Button(action: onTap) {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.accent)
                                    .frame(width: 56, height: 56)
                                VStack(spacing: 1) {
                                    Image(systemName: "fuelpump.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text(fuelType.shortLabel(for: station.country))
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundStyle(.white)
                            }

                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(price.priceFormatted)
                                    .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                                Text(fuelType.unit(for: station.country))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(isDark ? .black.opacity(0.4) : .white.opacity(0.5))
                            }
                            .foregroundStyle(isDark ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(isDark ? .white : Color(white: 0.12))
                            .clipShape(Capsule())
                            .padding(.top, -10)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 120)

            // Right: station info + opportunity + navigate
            VStack(alignment: .trailing, spacing: 0) {
                Text(station.brand)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                HStack(spacing: 0) {
                    Text(station.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text("  \(distance.distanceFormatted)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(.secondaryLabel))
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                .foregroundStyle(Color(.label))
                .minimumScaleFactor(0.8)
                .padding(.top, 2)

                HStack(spacing: 5) {
                    Circle()
                        .fill(opportunity.color)
                        .frame(width: 6, height: 6)
                    Text(loc.opportunityLabel(opportunity))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(opportunity.color)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 3)
                .padding(.bottom, 12)

                Button(action: onNavigate) {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(loc.navigate)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Theme.Colors.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 16)
        }
        .padding(.leading, 10)
        .padding(.vertical, 14)
        .background(
            ZStack {
                Color.clear
                HStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Theme.Colors.accent.opacity(0),
                            Theme.Colors.accent.opacity(isDark ? 0.30 : 0.10),
                            Theme.Colors.accent.opacity(isDark ? 0.50 : 0.20),
                            Theme.Colors.accent.opacity(isDark ? 0.70 : 0.32)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 200)
                }
            }
        )
    }
}

typealias CheapestStationCard = RadarPanel
