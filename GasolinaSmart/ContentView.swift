import SwiftUI

struct ContentView: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        if preferences.hasCompletedOnboarding {
            TabView(selection: $state.selectedTab) {
                Tab("Mapa", systemImage: "map", value: .map) {
                    MapView()
                }
                Tab("Favoritos", systemImage: "heart", value: .favorites) {
                    FavoritesView()
                }
                Tab("Buscar", systemImage: "magnifyingglass", value: .search) {
                    SearchView()
                }
                Tab("Ajustes", systemImage: "gearshape", value: .settings) {
                    SettingsView()
                }
            }
            .tint(Theme.Colors.accent)
            .preferredColorScheme(preferences.colorScheme)
        } else {
            OnboardingView()
        }
    }
}
