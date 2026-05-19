import SwiftUI

@Observable
final class AppState {
    var selectedTab: AppTab = .map
    var selectedStation: FuelStation?
    var showStationDetail = false
    var pendingStationId: String?
    var pendingSearchQuery: String?

    /// When non-nil, ContentView shows a full-screen "Welcome to X" overlay
    /// (Citymapper-style transition). Set when the user picks a new country
    /// from Settings or when auto-detect swaps countries on launch. The
    /// overlay clears the field itself once the animation finishes.
    var countryTransition: Country?
}

enum AppTab: Hashable {
    case map
    case favorites
    case search
    case settings
}
