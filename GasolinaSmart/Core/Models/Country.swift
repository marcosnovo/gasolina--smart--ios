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
    case italy = "IT"
    case usa = "US"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spain: "España"
        case .uk: "United Kingdom"
        case .france: "France"
        case .germany: "Deutschland"
        case .italy: "Italia"
        case .usa: "United States"
        }
    }

    var flag: String {
        switch self {
        case .spain: "🇪🇸"
        case .uk: "🇬🇧"
        case .france: "🇫🇷"
        case .germany: "🇩🇪"
        case .italy: "🇮🇹"
        case .usa: "🇺🇸"
        }
    }

    var currency: String {
        switch self {
        case .spain, .france, .germany, .italy: "EUR"
        case .uk: "GBP"
        case .usa: "USD"
        }
    }

    var currencySymbol: String {
        switch self {
        case .spain, .france, .germany, .italy: "€"
        case .uk: "£"
        case .usa: "$"
        }
    }

    var pricePrecision: Int { 3 }

    /// True when the backend has station-level fuel-price data for this
    /// country. The US is currently charging-only because no public
    /// station-level fuel API exists (EIA is state-weekly averages,
    /// GasBuddy has no public API). Callers use this flag to hide the
    /// fuel UI and force charging-mode for fuel-less countries.
    var hasFuelData: Bool {
        switch self {
        case .spain, .uk, .france, .germany, .italy: true
        case .usa: false
        }
    }

    var defaultFuel: FuelType {
        switch self {
        case .spain: .gasolina95
        case .uk: .e10
        case .france: .e10
        case .germany: .e10
        case .italy: .e5
        // USA never reads this (no fuel UI), but the switch must be
        // exhaustive — pick gasoline 95 as a harmless placeholder.
        case .usa: .gasolina95
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
        case .italy:
            [.e5, .gasolina98, .dieselA, .dieselPremium, .glp, .gnc]
        case .usa:
            []
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
        case .italy:
            BoundingBox(minLatitude: 35.5, maxLatitude: 47.1, minLongitude: 6.6, maxLongitude: 18.5)
        case .usa:
            // Covers CONUS only; AK / HI users need to pick US manually
            // from settings rather than relying on auto-detect.
            BoundingBox(minLatitude: 24.5, maxLatitude: 49.5, minLongitude: -125, maxLongitude: -66.5)
        }
    }

    var dataFreshness: DataFreshness {
        switch self {
        case .germany: .realtime
        case .uk: .within30min
        case .spain, .france: .within1hour
        case .italy, .usa: .daily
        }
    }

    var mapCenter: CLLocationCoordinate2D {
        switch self {
        case .spain: CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038)
        case .uk: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        case .france: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        case .germany: CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050)
        case .italy: CLLocationCoordinate2D(latitude: 41.9028, longitude: 12.4964)
        case .usa: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35) // geographic center of CONUS
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
        case .italy:
            "Ministero delle Imprese e del Made in Italy (MIMIT).\nLicenza IODL 2.0"
        case .usa:
            "Charging data © OpenChargeMap contributors,\nlicensed under CC BY-SA 4.0"
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
