import SwiftUI

@Observable
final class AppState {
    var selectedTab: AppTab = .map
    var selectedStation: FuelStation?
    var showStationDetail = false
    var pendingStationId: String?
    var pendingSearchQuery: String?
}

enum AppTab: Hashable {
    case map
    case favorites
    case search
    case settings
}
