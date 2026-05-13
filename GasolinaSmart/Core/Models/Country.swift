import Foundation
import CoreLocation

struct BoundingBox: Sendable {
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double

    func contains(latitude: Double, longitude: Double) -> Bool {
        latitude >= minLatitude && latitude <= maxLatitude &&
        longitude >= minLongitude && longitude <= maxLongitude
    }
}

enum DataFreshness: Sendable {
    case realtime
    case within30min
    case within1hour
    case daily

    var displayText: String {
        switch self {
        case .realtime: "Tiempo real"
        case .within30min: "≤30 min"
        case .within1hour: "~1 hora"
        case .daily: "Diaria"
        }
    }
}

enum Country: String, Codable, CaseIterable, Identifiable, Sendable {
    case spain = "ES"
    case uk = "GB"
    case france = "FR"
    case germany = "DE"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spain: "España"
        case .uk: "United Kingdom"
        case .france: "France"
        case .germany: "Deutschland"
        }
    }

    var flag: String {
        switch self {
        case .spain: "🇪🇸"
        case .uk: "🇬🇧"
        case .france: "🇫🇷"
        case .germany: "🇩🇪"
        }
    }

    var currency: String {
        switch self {
        case .spain, .france, .germany: "EUR"
        case .uk: "GBP"
        }
    }

    var currencySymbol: String {
        switch self {
        case .spain, .france, .germany: "€"
        case .uk: "£"
        }
    }

    var pricePrecision: Int { 3 }

    var defaultFuel: FuelType {
        switch self {
        case .spain: .gasolina95
        case .uk: .e10
        case .france: .e10
        case .germany: .e10
        }
    }

    var supportedFuelTypes: [FuelType] {
        switch self {
        case .spain:
            [.gasolina95, .gasolina98, .dieselA, .dieselPremium, .glp]
        case .uk:
            [.e10, .e5, .gasolina98, .dieselA, .dieselPremium]
        case .france:
            [.e10, .e5, .gasolina98, .dieselA, .e85, .glp]
        case .germany:
            [.e5, .e10, .dieselA]
        }
    }

    var boundingBox: BoundingBox {
        switch self {
        case .spain:
            BoundingBox(minLatitude: 27.5, maxLatitude: 43.8, minLongitude: -18.2, maxLongitude: 4.4)
        case .uk:
            BoundingBox(minLatitude: 49.9, maxLatitude: 60.9, minLongitude: -8.2, maxLongitude: 1.8)
        case .france:
            BoundingBox(minLatitude: 41.3, maxLatitude: 51.1, minLongitude: -5.2, maxLongitude: 9.6)
        case .germany:
            BoundingBox(minLatitude: 47.3, maxLatitude: 55.1, minLongitude: 5.9, maxLongitude: 15.0)
        }
    }

    var dataFreshness: DataFreshness {
        switch self {
        case .germany: .realtime
        case .uk: .within30min
        case .spain, .france: .within1hour
        }
    }

    var mapCenter: CLLocationCoordinate2D {
        switch self {
        case .spain: CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038)
        case .uk: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        case .france: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        case .germany: CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050)
        }
    }

    var defaultZoom: Double { 11 }

    var attributionText: String {
        switch self {
        case .spain:
            "Ministerio para la Transición Ecológica y el Reto Demográfico.\nDatos abiertos: geoportalgasolineras.es"
        case .uk:
            "Crown copyright. Source: Fuel Finder, operated by VE3 Global Ltd under the Motor Fuel Price (Open Data) Regulations 2025."
        case .france:
            "Licence Ouverte / Open Licence.\nSource: data.economie.gouv.fr"
        case .germany:
            "Spritpreis-Daten von Tankerkönig (tankerkoenig.de),\nlizenziert unter CC BY 4.0"
        }
    }

    static func detect(from coordinate: CLLocationCoordinate2D) -> Country? {
        for country in Country.allCases {
            if country.boundingBox.contains(latitude: coordinate.latitude, longitude: coordinate.longitude) {
                return country
            }
        }
        return nil
    }
}
