import SwiftUI

@main
struct GasolinaSmartApp: App {
    @State private var preferences = UserPreferences()
    @State private var locationManager = LocationManager()
    @State private var stationStore = StationStore()
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(preferences)
                .environment(locationManager)
                .environment(stationStore)
                .environment(appState)
        }
    }
}
