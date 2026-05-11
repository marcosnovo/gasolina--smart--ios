import SwiftUI

@main
struct GasolinaSmartApp: App {
    @State private var preferences = UserPreferences()
    @State private var locationManager = LocationManager()
    @State private var stationStore = StationStore()
    @State private var appState = AppState()
    @State private var notificationManager = NotificationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(preferences)
                .environment(locationManager)
                .environment(stationStore)
                .environment(appState)
                .environment(notificationManager)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == WidgetConstants.urlScheme,
              url.host == "station",
              let stationId = url.pathComponents.dropFirst().first else {
            return
        }

        appState.selectedTab = .map

        if let station = stationStore.allStations.first(where: { $0.id == stationId }) {
            appState.selectedStation = station
            appState.showStationDetail = true
        } else {
            appState.pendingStationId = stationId
        }
    }
}
