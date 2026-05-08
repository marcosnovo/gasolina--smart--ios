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

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.cheapGradient)
                        .frame(width: 36, height: 36)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(station.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.label)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let price {
                            Text("\(price.priceFormatted) €/L")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.cheapPrice)
                        }
                        Text(distance.distanceFormatted)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                    }
                }

                Spacer(minLength: 4)

                if let saving, saving > 0 {
                    Text("-\(saving.savingFormatted)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.saving)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Colors.tertiaryLabel)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .shadow(color: Theme.Shadows.cardShadow(colorScheme), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }
}
