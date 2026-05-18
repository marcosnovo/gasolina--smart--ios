import Foundation

enum WidgetConstants {
    static let appGroupId = "group.MarcosNovo.GasolinaSmart"
    /// Default snapshot. Used by widgets without a per-vehicle / per-fuel
    /// configuration, plus as a fallback for newly-installed widgets.
    static let widgetDataKey = "widget_station_data"
    static let urlScheme = "gasolinasmart"

    /// App-group key under which the main app publishes the list of
    /// vehicles a user has, so the widget editor can offer them in its
    /// configuration picker.
    static let vehiclesKey = "widget_vehicles"

    /// App-group key under which the main app publishes the fuels
    /// supported by the active country, again to feed the widget editor's
    /// fuel picker.
    static let supportedFuelsKey = "widget_supported_fuels"

    /// Snapshot keys used when the widget is configured for a specific
    /// vehicle or a specific fuel.
    static func vehicleSnapshotKey(_ vehicleId: String) -> String {
        "widget_data:vehicle:\(vehicleId)"
    }
    static func fuelSnapshotKey(_ fuelRaw: String) -> String {
        "widget_data:fuel:\(fuelRaw)"
    }
}

/// Compact vehicle summary the main app publishes to the App Group so
/// the widget editor can list the user's vehicles. Mirrors only the
/// fields the picker / preview UI needs.
struct WidgetVehicleSummary: Codable, Hashable {
    let id: String
    let name: String
    let fuelTypeRaw: String
    let vehicleTypeRaw: String
    let vehicleColorRaw: String
    let isElectric: Bool
}

/// Compact fuel descriptor for the widget's fuel picker, pre-localised
/// for the user's active country.
struct WidgetFuelSummary: Codable, Hashable {
    let raw: String
    let displayName: String
    let shortLabel: String
}

struct WidgetStationData: Codable, Equatable {
    let stationId: String
    let stationName: String
    let brand: String
    let price: Double
    let priceFormatted: String
    let fuelTypeRaw: String
    let fuelTypeLabel: String
    let fuelTypeShort: String
    let distanceKm: Double
    let address: String
    let municipality: String
    let stationLatitude: Double
    let stationLongitude: Double
    let userLatitude: Double
    let userLongitude: Double
    let averagePrice: Double?
    let savingFormatted: String?
    let opportunity: String
    let vehicleName: String
    let vehicleTypeRaw: String
    let vehicleColorRaw: String
    let radiusKm: Double
    let stationCount: Int
    let lastUpdated: Date
    let isDarkMode: Bool
    let navigationURLString: String
    var fuelTypeUnit: String?

    var deepLinkURL: URL {
        URL(string: "\(WidgetConstants.urlScheme)://station/\(stationId)")!
    }

    var fuelType: FuelType? {
        FuelType(rawValue: fuelTypeRaw)
    }

    var vehicleType: VehicleType? {
        VehicleType(rawValue: vehicleTypeRaw)
    }

    var vehicleColor: VehicleColor? {
        VehicleColor(rawValue: vehicleColorRaw)
    }

    var navigateDeepLinkURL: URL {
        guard let encoded = navigationURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return deepLinkURL
        }
        return URL(string: "\(WidgetConstants.urlScheme)://navigate?url=\(encoded)") ?? deepLinkURL
    }

    /// Field-by-field equality that ignores `lastUpdated`. Used by the
    /// widget data provider to skip JSON encoding + `reloadAllTimelines`
    /// when nothing visible to the user changed (the synthesised `==`
    /// would always fail because we stamp `Date()` on each update).
    func hasSameVisibleContent(as other: WidgetStationData?) -> Bool {
        guard let other else { return false }
        return stationId == other.stationId
            && stationName == other.stationName
            && brand == other.brand
            && price == other.price
            && priceFormatted == other.priceFormatted
            && fuelTypeRaw == other.fuelTypeRaw
            && fuelTypeLabel == other.fuelTypeLabel
            && fuelTypeShort == other.fuelTypeShort
            && distanceKm == other.distanceKm
            && address == other.address
            && municipality == other.municipality
            && stationLatitude == other.stationLatitude
            && stationLongitude == other.stationLongitude
            && userLatitude == other.userLatitude
            && userLongitude == other.userLongitude
            && averagePrice == other.averagePrice
            && savingFormatted == other.savingFormatted
            && opportunity == other.opportunity
            && vehicleName == other.vehicleName
            && vehicleTypeRaw == other.vehicleTypeRaw
            && vehicleColorRaw == other.vehicleColorRaw
            && radiusKm == other.radiusKm
            && stationCount == other.stationCount
            && isDarkMode == other.isDarkMode
            && navigationURLString == other.navigationURLString
            && fuelTypeUnit == other.fuelTypeUnit
    }

    static let placeholder = WidgetStationData(
        stationId: "placeholder",
        stationName: "E.S. La Estacion",
        brand: "REPSOL",
        price: 1.459,
        priceFormatted: "1,459",
        fuelTypeRaw: FuelType.gasolina95.rawValue,
        fuelTypeLabel: "Gasolina 95",
        fuelTypeShort: "G95",
        distanceKm: 2.3,
        address: "Calle Mayor 10",
        municipality: "Madrid",
        stationLatitude: 40.4168,
        stationLongitude: -3.7038,
        userLatitude: 40.4150,
        userLongitude: -3.7070,
        averagePrice: 1.523,
        savingFormatted: "3,20 €",
        opportunity: "great",
        vehicleName: "Mi coche",
        vehicleTypeRaw: VehicleType.sedan.rawValue,
        vehicleColorRaw: VehicleColor.blue.rawValue,
        radiusKm: 5,
        stationCount: 12,
        lastUpdated: Date(),
        isDarkMode: false,
        navigationURLString: "http://maps.apple.com/?daddr=40.4168,-3.7038&dirflg=d",
        fuelTypeUnit: "€/L"
    )
}
