import SwiftUI

struct CheapestStationCard: View {
    let station: FuelStation
    let fuelType: FuelType
    let averagePrice: Decimal?
    let tankLiters: Double
    let distance: Double
    let onTap: () -> Void

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
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "trophy.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.cheapPrice)
                        Text("Más barata cerca")
                            .font(Theme.Fonts.caption)
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
                        Text("·")
                            .foregroundStyle(Theme.Colors.tertiaryLabel)
                        Text(distance.distanceFormatted)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                    if let saving, saving > 0 {
                        Text("Ahorras \(saving.savingFormatted)")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.saving)

                        HStack(spacing: 4) {
                            Image(systemName: worthIt.icon)
                                .font(.caption2)
                            Text(worthIt.message)
                                .font(.caption2)
                        }
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.tertiaryLabel)
                }
            }
            .padding(Theme.Spacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
