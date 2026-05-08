import SwiftUI

struct CheapestStationCard: View {
    let station: FuelStation
    let fuelType: FuelType
    let averagePrice: Decimal?
    let tankLiters: Double
    let distance: Double
    let onTap: () -> Void
    let onNavigate: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(StationStore.self) private var store

    private var price: Decimal? {
        station.price(for: fuelType)
    }

    private var decision: FuelDecision {
        store.fuelDecisionMessage(
            stationPrice: price,
            averagePrice: averagePrice,
            tankLiters: tankLiters,
            distanceKm: distance
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: decision.verdict.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(decision.verdict.color)
                Text("Mejor opción ahora")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.label)
                        .lineLimit(1)

                    Text(decision.verdict.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(decision.verdict.color)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    if let price {
                        Text(price.priceFormatted)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.label)
                        Text("€/L")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                    }
                }
            }
            .padding(.horizontal, 16)

            HStack(spacing: 10) {
                HStack(spacing: 12) {
                    if let saving = decision.saving, saving > 0 {
                        Label("-\(saving.savingFormatted)", systemImage: "arrow.down.right")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.saving)
                    }
                    Label(distance.distanceFormatted, systemImage: "location.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: onTap) {
                        Text("Detalles")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Theme.Colors.accent.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onNavigate) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                .font(.system(size: 11))
                            Text("Ir")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Theme.Colors.accentGradient)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .shadow(color: Theme.Shadows.cardShadow(colorScheme), radius: 16, y: 8)
    }
}
