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
    @Environment(\.colorScheme) private var colorScheme

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
        VStack(alignment: .leading, spacing: 0) {
            if let price {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(price.priceFormatted)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(isDark ? Theme.Colors.accent : Color(.label))
                        .contentTransition(.numericText())

                    Text("€/L")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(.bottom, 6)
            }

            Button(action: onTap) {
                Text("\(station.name.uppercased()) · \(distance.distanceFormatted)")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)

            HStack(spacing: 5) {
                Image(systemName: opportunity.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(opportunity.color)

                if let saving {
                    Text("\(opportunity.label) · Ahorras \(saving.savingFormatted)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(opportunity.color)
                } else {
                    Text(opportunity.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(opportunity.color)
                }
            }
            .padding(.bottom, 16)

            Button(action: onNavigate) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Cómo llegar")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Theme.Colors.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }
}

typealias CheapestStationCard = RadarPanel
