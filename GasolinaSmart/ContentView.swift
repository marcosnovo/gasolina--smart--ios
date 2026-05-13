import SwiftUI

struct ContentView: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(AppState.self) private var appState

    private var loc: Loc { preferences.loc }

    var body: some View {
        @Bindable var state = appState
        if preferences.hasCompletedOnboarding {
            TabView(selection: $state.selectedTab) {
                Tab(loc.tabMap, systemImage: "map", value: .map) {
                    MapView()
                }
                Tab(loc.tabFavorites, systemImage: "star", value: .favorites) {
                    FavoritesView()
                }
                Tab(loc.tabSearch, systemImage: "magnifyingglass", value: .search) {
                    SearchView()
                }
                Tab(loc.tabSettings, systemImage: "gearshape", value: .settings) {
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
