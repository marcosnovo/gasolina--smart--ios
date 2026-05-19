import SwiftUI

struct ContentView: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(AppState.self) private var appState

    /// Shows the launch splash only on cold launch; iOS keeps ContentView
    /// alive between background/foreground so this @State stays false
    /// after the first time it flips.
    @State private var showSplash = true

    private var loc: Loc { preferences.loc }

    var body: some View {
        @Bindable var state = appState
        ZStack {
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

            // "Welcome to X" overlay (Citymapper-style). The view drives
            // itself: spring in, hold, fade out, then clear the trigger.
            if let country = appState.countryTransition {
                CountryTransitionOverlay(country: country)
                    .transition(.opacity)
                    .zIndex(100)
            }

            // Cold-launch splash — only shown the first time ContentView
            // appears in this process. Skipped if the user hasn't
            // completed onboarding (we don't want it to flash before the
            // onboarding hero).
            if showSplash && preferences.hasCompletedOnboarding {
                SplashView(onComplete: {
                    showSplash = false
                })
                .transition(.opacity)
                .zIndex(200)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.countryTransition)
        .animation(.easeInOut(duration: 0.2), value: showSplash)
    }
}
