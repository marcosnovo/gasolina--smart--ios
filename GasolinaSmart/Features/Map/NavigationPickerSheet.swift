import SwiftUI

struct NavigationPickerSheet: View {
    let station: FuelStation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Cómo llegar")
                .font(Theme.Fonts.headline)
                .padding(.top, Theme.Spacing.sm)

            HStack(spacing: 28) {
                appleMapsButton
                googleMapsButton
                if NavigationHelper.isWazeInstalled {
                    wazeButton
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.xl)
    }

    private var appleMapsButton: some View {
        Button {
            NavigationHelper.openAppleMaps(station: station)
            dismiss()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.25, green: 0.72, blue: 0.32), Color(red: 0.2, green: 0.55, blue: 0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("Apple Maps")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Color(.label))
            }
        }
        .buttonStyle(.plain)
    }

    private var googleMapsButton: some View {
        Button {
            NavigationHelper.openGoogleMaps(station: station)
            dismiss()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Color(red: 0.96, green: 0.96, blue: 0.96)
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 30, weight: .medium))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color(red: 0.92, green: 0.26, blue: 0.21))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("Google Maps")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Color(.label))
            }
        }
        .buttonStyle(.plain)
    }

    private var wazeButton: some View {
        Button {
            NavigationHelper.openWaze(station: station)
            dismiss()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Color(red: 0.2, green: 0.82, blue: 0.98)
                    Image(systemName: "car.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("Waze")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Color(.label))
            }
        }
        .buttonStyle(.plain)
    }
}
