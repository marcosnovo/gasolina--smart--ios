import SwiftUI

struct StationMarker: View {
    let price: Decimal?
    let isCheapest: Bool
    let isFavorite: Bool

    var body: some View {
        ZStack {
            if isCheapest {
                Circle()
                    .fill(Theme.Colors.cheapPrice.opacity(0.2))
                    .frame(width: 46, height: 46)

                Circle()
                    .fill(Theme.Colors.cheapGradient)
                    .frame(width: 36, height: 36)
                    .shadow(color: Theme.Colors.cheapPrice.opacity(0.4), radius: 6, y: 2)
            } else {
                Circle()
                    .fill(Theme.Colors.accentGradient)
                    .frame(width: 28, height: 28)
                    .shadow(color: Theme.Shadows.medium, radius: 4, y: 2)
            }

            Image(systemName: "fuelpump.fill")
                .font(.system(size: isCheapest ? 15 : 11, weight: .semibold))
                .foregroundStyle(.white)
        }
        .overlay(alignment: .topTrailing) {
            if isFavorite {
                Circle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.pink)
                    )
                    .offset(x: isCheapest ? 4 : 2, y: isCheapest ? -4 : -2)
            }
        }
    }
}
