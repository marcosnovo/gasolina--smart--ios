import UIKit

enum NavigationHelper {
    static var isWazeInstalled: Bool {
        guard let url = URL(string: "waze://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    static var isGoogleMapsInstalled: Bool {
        guard let url = URL(string: "comgooglemaps://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    static func openAppleMaps(station: FuelStation) {
        guard let url = URL(string: "http://maps.apple.com/?daddr=\(station.latitude),\(station.longitude)&dirflg=d") else { return }
        UIApplication.shared.open(url)
    }

    static func openWaze(station: FuelStation) {
        guard let url = URL(string: "waze://?ll=\(station.latitude),\(station.longitude)&navigate=yes") else { return }
        UIApplication.shared.open(url)
    }

    static func openGoogleMaps(station: FuelStation) {
        if isGoogleMapsInstalled {
            guard let url = URL(string: "comgooglemaps://?daddr=\(station.latitude),\(station.longitude)&directionsmode=driving") else { return }
            UIApplication.shared.open(url)
        } else {
            guard let url = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(station.latitude),\(station.longitude)&travelmode=driving") else { return }
            UIApplication.shared.open(url)
        }
    }

    static func navigationURL(latitude: Double, longitude: Double, app: PreferredNavigationApp) -> URL {
        switch app {
        case .appleMaps:
            return URL(string: "http://maps.apple.com/?daddr=\(latitude),\(longitude)&dirflg=d")!
        case .googleMaps:
            if isGoogleMapsInstalled {
                return URL(string: "comgooglemaps://?daddr=\(latitude),\(longitude)&directionsmode=driving")!
            }
            return URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(latitude),\(longitude)&travelmode=driving")!
        case .waze:
            if isWazeInstalled {
                return URL(string: "waze://?ll=\(latitude),\(longitude)&navigate=yes")!
            }
            return URL(string: "http://maps.apple.com/?daddr=\(latitude),\(longitude)&dirflg=d")!
        }
    }

    static func openPreferred(station: FuelStation, app: PreferredNavigationApp) {
        let url = navigationURL(latitude: station.latitude, longitude: station.longitude, app: app)
        UIApplication.shared.open(url)
    }

    static func openCharging(station: ChargingStation, app: PreferredNavigationApp) {
        let url = navigationURL(latitude: station.latitude, longitude: station.longitude, app: app)
        UIApplication.shared.open(url)
    }
}
