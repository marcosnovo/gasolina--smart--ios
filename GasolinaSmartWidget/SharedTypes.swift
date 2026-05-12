import Foundation

enum WidgetConstants {
    static let appGroupId = "group.MarcosNovo.GasolinaSmart"
    static let widgetDataKey = "widget_station_data"
    static let urlScheme = "gasolinasmart"
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

    var deepLinkURL: URL {
        URL(string: "\(WidgetConstants.urlScheme)://station/\(stationId)")!
    }

    var navigationURL: URL? {
        URL(string: navigationURLString)
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
        navigationURLString: "http://maps.apple.com/?daddr=40.4168,-3.7038&dirflg=d"
    )
}

enum VehicleType: String {
    case sedan, suv, hatchback, van, motorcycle
}

enum VehicleColor: String {
    case black, white, silver, red, blue, darkBlue, green, orange, yellow, brown
}
