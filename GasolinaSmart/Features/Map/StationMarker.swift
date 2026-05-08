import SwiftUI

struct StationMarker: View {
    let price: Decimal?
    let isCheapest: Bool
    let isFavorite: Bool

    var body: some View {
        ZStack {
            if isCheapest {
                Circle()
                    .fill(Theme.Colors.accent.opacity(0.12))
                    .frame(width: 52, height: 52)

                Circle()
                    .fill(Theme.Colors.accentGradient)
                    .frame(width: 38, height: 38)
                    .shadow(color: Theme.Colors.accent.opacity(0.35), radius: 8, y: 3)

                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .fill(Theme.Colors.markerDefault.opacity(0.85))
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.1), radius: 3, y: 1)

                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isFavorite {
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.pink)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                    .offset(x: isCheapest ? 5 : 3, y: isCheapest ? -5 : -3)
            }
        }
    }
}
