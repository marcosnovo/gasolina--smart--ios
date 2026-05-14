import SwiftUI

@main
struct GasolinaSmartApp: App {
    @State private var preferences = UserPreferences()
    @State private var locationManager = LocationManager()
    @State private var stationStore = StationStore()
    @State private var chargingStationStore = ChargingStationStore()
    @State private var appState = AppState()
    @State private var notificationManager = NotificationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(preferences)
                .environment(locationManager)
                .environment(stationStore)
                .environment(chargingStationStore)
                .environment(appState)
                .environment(notificationManager)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == WidgetConstants.urlScheme else { return }

        if url.host == "navigate" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let rawURL = components?.queryItems?.first(where: { $0.name == "url" })?.value,
               let navURL = URL(string: rawURL) {
                UIApplication.shared.open(navURL)
                return
            }
            if let latStr = components?.queryItems?.first(where: { $0.name == "lat" })?.value,
               let lonStr = components?.queryItems?.first(where: { $0.name == "lon" })?.value,
               let lat = Double(latStr), let lon = Double(lonStr) {
                let navURL = NavigationHelper.navigationURL(latitude: lat, longitude: lon, app: preferences.preferredNavigationApp)
                UIApplication.shared.open(navURL)
            }
            return
        }

        guard let result = DeeplinkParser.parse(url) else { return }

        let stationId = result.stationId
        if result.country != preferences.selectedCountry {
            preferences.selectedCountry = result.country
            stationStore.switchCountry(result.country)
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
