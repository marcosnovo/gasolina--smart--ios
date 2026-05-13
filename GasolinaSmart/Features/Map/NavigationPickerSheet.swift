import SwiftUI

struct NavigationPickerSheet: View {
    let station: FuelStation
    var availableApps: Set<PreferredNavigationApp> = Set(PreferredNavigationApp.allCases)
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss

    private var loc: Loc { preferences.loc }

    private var sortedApps: [PreferredNavigationApp] {
        PreferredNavigationApp.allCases.filter { availableApps.contains($0) }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text(loc.howToGet)
                .font(Theme.Fonts.headline)
                .padding(.top, Theme.Spacing.sm)

            HStack(spacing: 28) {
                ForEach(sortedApps, id: \.self) { app in
                    navigationButton(for: app)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.xl)
    }

    @ViewBuilder
    private func navigationButton(for app: PreferredNavigationApp) -> some View {
        Button {
            NavigationHelper.openPreferred(station: station, app: app)
            dismiss()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    appBackground(for: app)
                    appIcon(for: app)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(app.displayName)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Color(.label))
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func appBackground(for app: PreferredNavigationApp) -> some View {
        switch app {
        case .appleMaps:
            LinearGradient(
                colors: [Color(red: 0.25, green: 0.72, blue: 0.32), Color(red: 0.2, green: 0.55, blue: 0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .googleMaps:
            Color(red: 0.96, green: 0.96, blue: 0.96)
        case .waze:
            Color(red: 0.2, green: 0.82, blue: 0.98)
        }
    }

    @ViewBuilder
    private func appIcon(for app: PreferredNavigationApp) -> some View {
        switch app {
        case .appleMaps:
            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
        case .googleMaps:
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 30, weight: .medium))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color(red: 0.92, green: 0.26, blue: 0.21))
        case .waze:
            Image(systemName: "car.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
