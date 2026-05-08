import SwiftUI

@Observable
final class AppState {
    var selectedTab: AppTab = .map
    var selectedStation: FuelStation?
    var showStationDetail = false
}

enum AppTab: Hashable {
    case map
    case favorites
    case settings
}
