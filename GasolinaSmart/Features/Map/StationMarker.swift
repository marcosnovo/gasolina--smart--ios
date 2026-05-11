import SwiftUI

struct StationMarker: View {
    let price: Decimal?
    let isCheapest: Bool
    let isFavorite: Bool

    var body: some View {
        ZStack {
            if isCheapest {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 36, height: 36)
                Circle()
                    .fill(Color.blue)
                    .frame(width: 14, height: 14)
            } else if isFavorite {
                Circle()
                    .strokeBorder(Color.blue.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 20, height: 20)
                Circle()
                    .fill(Color(.systemGray))
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(Color(.systemGray))
                    .frame(width: 10, height: 10)
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
    }
}
