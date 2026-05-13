import SwiftUI

struct Vehicle3DView: View {
    let vehicleType: VehicleType
    let vehicleColor: VehicleColor
    var height: CGFloat = 200

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            vehicleColor.color.opacity(0.35),
                            vehicleColor.color.opacity(0.12),
                            vehicleColor.color.opacity(0.04)
                        ],
                        center: .center,
                        startRadius: height * 0.08,
                        endRadius: height * 0.48
                    )
                )
                .frame(width: height * 0.85, height: height * 0.85)

            Circle()
                .fill(vehicleColor.color.opacity(0.12))
                .frame(width: height * 0.55, height: height * 0.55)

            Image(systemName: vehicleType.icon)
                .font(.system(size: height * 0.22, weight: .semibold))
                .foregroundStyle(vehicleColor.color)
                .shadow(color: vehicleColor.color.opacity(0.3), radius: 8, y: 2)
        }
        .frame(height: height)
    }
}
