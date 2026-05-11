import SwiftUI

struct VehicleAvatar: View {
    let vehicle: Vehicle
    var size: CGFloat = 40

    private var iconSize: CGFloat { size * 0.42 }
    private var cornerRadius: CGFloat { size * 0.26 }
    private var shadowRadius: CGFloat { size * 0.1 }

    private var gradientColors: [Color] {
        let base = vehicle.vehicleColor.color
        return [base, base.opacity(0.65)]
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(0.15))
                .padding(1)
                .mask(
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            Image(systemName: vehicle.vehicleType.icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
        }
        .frame(width: size, height: size)
        .shadow(color: vehicle.vehicleColor.color.opacity(0.35), radius: shadowRadius, y: shadowRadius * 0.6)
    }
}
