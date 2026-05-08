import SwiftUI

struct StationMarker: View {
    let price: Decimal?
    let isCheapest: Bool
    let isFavorite: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(markerColor)
                    .frame(width: markerSize, height: markerSize)

                Image(systemName: "fuelpump.fill")
                    .font(.system(size: isCheapest ? 14 : 10))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            .overlay(alignment: .topTrailing) {
                if isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.pink)
                        .offset(x: 4, y: -4)
                }
            }
        }
    }

    private var markerColor: Color {
        if isCheapest { return Theme.Colors.cheapPrice }
        return Color.accentColor
    }

    private var markerSize: CGFloat {
        isCheapest ? 36 : 28
    }
}
