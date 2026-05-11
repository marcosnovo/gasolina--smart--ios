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
            if let saving {
                Text(saving.savingFormatted)
                    .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color(.label))
                    .contentTransition(.numericText())
                    .padding(.bottom, 2)

                Text("vs media de la zona en tu depósito")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.bottom, 10)
            } else if let price {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(price.priceFormatted)
                        .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(isDark ? Theme.Colors.accent : Color(.label))
                        .contentTransition(.numericText())
                    Text("€/L")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(.bottom, 10)
            }

            Button(action: onTap) {
                Text("\(station.name) · \(distance.distanceFormatted)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)

            if saving != nil, let price {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(price.priceFormatted)
                        .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color(.label))
                    Text("€/L")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(.bottom, 8)
            }

            HStack(spacing: 5) {
                Image(systemName: opportunity.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(opportunity.color)
                Text(opportunity.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(opportunity.color)
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
