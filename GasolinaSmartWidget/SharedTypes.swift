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
    /// vehicle or a specific fuel. The main app writes these alongside
    /// the default key so a widget bound to "Coche A" reads its own data.
    static func vehicleSnapshotKey(_ vehicleId: String) -> String {
        "widget_data:vehicle:\(vehicleId)"
    }
    static func fuelSnapshotKey(_ fuelRaw: String) -> String {
        "widget_data:fuel:\(fuelRaw)"
    }
}

/// Compact vehicle summary the main app publishes to the App Group so
/// the widget editor can list the user's vehicles. Mirrors only the
/// fields the picker / preview UI needs — full Vehicle model lives in
/// the main app target.
struct WidgetVehicleSummary: Codable, Hashable {
    let id: String           // UUID string
    let name: String
    let fuelTypeRaw: String  // FuelType raw value of the vehicle's primary fuel
    let vehicleTypeRaw: String
    let vehicleColorRaw: String
    let isElectric: Bool
}

/// Compact fuel descriptor for the widget's fuel picker. The display
/// name is pre-localised for the user's active country (so e.g. "SP95"
/// vs "Gasolina 95" depending on locale).
struct WidgetFuelSummary: Codable, Hashable {
    let raw: String          // FuelType raw value
    let displayName: String
    let shortLabel: String
}

struct WidgetStationData: Codable {
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

    var navigateDeepLinkURL: URL {
        URL(string: "\(WidgetConstants.urlScheme)://navigate?lat=\(stationLatitude)&lon=\(stationLongitude)")!
    }

    static let placeholder = WidgetStationData(
        stationId: "placeholder",
        stationName: "E.S. La Estacion",
        brand: "REPSOL",
        price: 1.459,
        priceFormatted: "1,459",
        fuelTypeRaw: "gasolina95",
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
        vehicleTypeRaw: "sedan",
        vehicleColorRaw: "blue",
        radiusKm: 5,
        stationCount: 12,
        lastUpdated: Date(),
        isDarkMode: false,
        navigationURLString: "http://maps.apple.com/?daddr=40.4168,-3.7038&dirflg=d",
        fuelTypeUnit: "€/L"
    )
}

enum VehicleType: String {
    case sedan, suv, hatchback, van, motorcycle
}

enum VehicleColor: String {
    case black, white, silver, red, blue, darkBlue, green, orange, yellow, brown
}

// MARK: - Widget Localization

enum WidgetLoc {
    private static var lang: String {
        if let defaults = UserDefaults(suiteName: WidgetConstants.appGroupId),
           let raw = defaults.string(forKey: "appLanguage"), raw != "system" {
            return raw
        }
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("es") { return "es" }
        if preferred.hasPrefix("fr") { return "fr" }
        if preferred.hasPrefix("de") { return "de" }
        if preferred.hasPrefix("pt") { return "pt" }
        return "en"
    }

    private static func s(_ es: String, _ en: String, _ fr: String, _ de: String, _ pt: String) -> String {
        switch lang {
        case "es": es; case "fr": fr; case "de": de; case "pt": pt; default: en
        }
    }

    static var navigate: String { s("Navegar", "Navigate", "Naviguer", "Navigieren", "Navegar") }
    static var openApp: String { s("Abre Gasolina Smart", "Open Gasolina Smart", "Ouvrez Gasolina Smart", "Gasolina Smart öffnen", "Abra Gasolina Smart") }
    static var toSeeStations: String { s("para ver gasolineras", "to see fuel stations", "pour voir les stations", "um Tankstellen zu sehen", "para ver postos") }
    static var darkWidgetName: String { s("Gasolinera - Oscuro", "Station - Dark", "Station - Sombre", "Tankstelle - Dunkel", "Posto - Escuro") }
    static var darkWidgetDesc: String { s("Precio y navegación con fondo oscuro.", "Price and navigation with dark background.", "Prix et navigation sur fond sombre.", "Preis und Navigation mit dunklem Hintergrund.", "Preço e navegação com fundo escuro.") }
    static var lightWidgetName: String { s("Gasolinera - Claro", "Station - Light", "Station - Clair", "Tankstelle - Hell", "Posto - Claro") }
    static var lightWidgetDesc: String { s("Precio y navegación con fondo claro.", "Price and navigation with light background.", "Prix et navigation sur fond clair.", "Preis und Navigation mit hellem Hintergrund.", "Preço e navegação com fundo claro.") }
}
