import SwiftUI

struct CheapestStationCard: View {
    let station: FuelStation
    let fuelType: FuelType
    let averagePrice: Decimal?
    let tankLiters: Double
    let distance: Double
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var price: Decimal? {
        station.price(for: fuelType)
    }

    private var saving: Decimal? {
        guard let price, let averagePrice else { return nil }
        return (averagePrice - price) * Decimal(tankLiters)
    }

    private var worthIt: WorthItLevel {
        guard let saving else { return .neutral }
        if saving < 1 { return .neutral }
        if saving <= 3 { return .moderate }
        return .good
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Colors.cheapGradient)
                    .frame(width: 4)
                    .padding(.vertical, Theme.Spacing.sm)

                HStack(spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                            Text("Más barata cerca")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .foregroundStyle(Theme.Colors.secondaryLabel)
                        }

                        Text(station.name)
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.label)
                            .lineLimit(1)

                        HStack(spacing: Theme.Spacing.sm) {
                            if let price {
                                Text("\(price.priceFormatted) €/L")
                                    .font(Theme.Fonts.priceSmall)
                                    .foregroundStyle(Theme.Colors.cheapPrice)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 9))
                                Text(distance.distanceFormatted)
                                    .font(Theme.Fonts.caption)
                            }
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        if let saving, saving > 0 {
                            Text("-\(saving.savingFormatted)")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(Theme.Colors.saving)

                            HStack(spacing: 3) {
                                Image(systemName: worthIt.icon)
                                    .font(.system(size: 10))
                                Text(worthIt.message)
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.Colors.tertiaryLabel)
                    }
                }
                .padding(.leading, Theme.Spacing.md)
                .padding(.trailing, Theme.Spacing.md)
            }
            .padding(.vertical, Theme.Spacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
            .shadow(color: Theme.Shadows.cardShadow(colorScheme), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
    }
}
