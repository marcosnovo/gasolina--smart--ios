import SwiftUI

struct ContentView: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(AppState.self) private var appState

    var body: some View {
        if preferences.hasCompletedOnboarding {
            mainTabView
        } else {
            OnboardingView()
        }
    }

    private var mainTabView: some View {
        @Bindable var state = appState

        return TabView(selection: $state.selectedTab) {
            Tab("Mapa", systemImage: "map.fill", value: .map) {
                MapView()
            }

            Tab("Favoritos", systemImage: "heart.fill", value: .favorites) {
                FavoritesView()
            }

            Tab("Ajustes", systemImage: "gearshape.fill", value: .settings) {
                SettingsView()
            }
        }
    }
}
