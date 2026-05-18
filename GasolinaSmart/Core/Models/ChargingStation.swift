import Foundation
import CoreLocation

struct ChargingConnection: Equatable, Sendable {
    let typeName: String
    let powerKW: Double?
    let quantity: Int?
}

struct ChargingStation: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let operatorName: String
    let address: String
    let town: String
    let province: String
    let latitude: Double
    let longitude: Double
    let connections: [ChargingConnection]
    let numberOfPoints: Int
    let isOperational: Bool
    let usageCost: String?
    let lastUpdated: Date?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distanceKm(from location: CLLocation) -> Double {
        GeoDistance.distance(
            fromLatitude: location.coordinate.latitude,
            fromLongitude: location.coordinate.longitude,
            toLatitude: latitude,
            toLongitude: longitude
        ) / 1000.0
    }

    func distanceKm(from coordinate: CLLocationCoordinate2D) -> Double {
        GeoDistance.distance(
            fromLatitude: coordinate.latitude,
            fromLongitude: coordinate.longitude,
            toLatitude: latitude,
            toLongitude: longitude
        ) / 1000.0
    }

    var maxPowerKW: Double? {
        connections.compactMap(\.powerKW).max()
    }

    var speedCategory: SpeedCategory {
        if let maxPower = maxPowerKW {
            // 22 kW is the practical "useful for a quick top-up" floor. Most
            // urban public chargers in Spain sit at 22 kW AC; 50 kW+ are
            // DC fast. We collapse both into .fast so the green pill /
            // bolt badge actually fires for the chargers a driver cares
            // about, instead of only DC fast which is rare in mixed-use
            // areas. Anything below 22 kW remains slow/semi.
            if maxPower >= 22 { return .fast }
            if maxPower >= 11 { return .semiFast }
            return .slow
        }
        // When OpenChargeMap doesn't report kW, infer from the connector type:
        // CCS / CHAdeMO / NACS are always DC fast plugs.
        for conn in connections {
            let short = ChargingStation.normalizeConnectorShortName(conn.typeName)
            if short == "CCS" || short == "CHAdeMO" || short == "NACS" {
                return .fast
            }
        }
        return .unknown
    }

    var connectionSummary: String {
        let types = Set(connections.map(\.typeName)).sorted()
        return types.joined(separator: ", ")
    }

    /// Parsed price per kWh extracted from the free-text `usageCost` (e.g.
    /// "0.35€/kWh", "0,30 €/kWh + 0,05€/min"). Returns nil if the string
    /// doesn't contain a recognisable per-kWh price.
    var pricePerKWh: Decimal? {
        guard let cost = usageCost else { return nil }
        return ChargingStation.parseCostPerKWh(cost)
    }

    /// Treats "Gratuito" / "Free" / "Libre" usage costs as a real "0 €/kWh"
    /// signal so the UI can show a green Free badge.
    var isFree: Bool {
        guard let cost = usageCost?.lowercased() else { return false }
        return cost.contains("gratu") || cost.contains("free") || cost.contains("libre") || cost == "0"
    }

    /// Set of normalised connector shortNames the station carries
    /// ("CCS", "Type 2", "CHAdeMO", …). Empty when the data source didn't
    /// report any connectors.
    var connectorShortNames: Set<String> {
        Set(connections.map { ChargingStation.normalizeConnectorShortName($0.typeName) })
    }

    /// True when the station has any connector compatible with `filter`.
    /// Permissive: a station with no connector info at all still matches —
    /// we'd rather show a possibly-compatible station than hide it because
    /// OpenChargeMap didn't have the data.
    ///
    /// Hot path: called once per station per filter pass (thousands of
    /// stations × multiple filter calls per map update). Avoids allocating
    /// a Set per call — short-circuits on the first matching connector.
    func matchesConnectorFilter(_ filter: Set<String>) -> Bool {
        if filter.isEmpty { return true }
        if connections.isEmpty { return true }
        for conn in connections {
            if filter.contains(ChargingStation.normalizeConnectorShortName(conn.typeName)) {
                return true
            }
        }
        return false
    }

    /// Canonicalises an OpenChargeMap typeName ("CCS (Type 2)",
    /// "Type 2 (Tethered Connector)", "Tesla (Model S/X)", …) to one of the
    /// short codes shown in the UI: "CCS", "CHAdeMO", "Type 2", "Type 1",
    /// "NACS", "Schuko", "CEE", or the raw value as a fallback.
    static func normalizeConnectorShortName(_ raw: String) -> String {
        let name = raw.lowercased()
        if name.contains("ccs") { return "CCS" }
        if name.contains("chademo") { return "CHAdeMO" }
        if name.contains("nacs") || name.contains("j3400") || name.contains("tesla") { return "NACS" }
        if name.contains("type 2") || name.contains("mennekes") || name.contains("iec 62196-2") { return "Type 2" }
        if name.contains("type 1") || name.contains("j1772") { return "Type 1" }
        if name.contains("schuko") || name.contains("domestic") { return "Schuko" }
        if name.contains("cee") { return "CEE" }
        return raw
    }

    static func parseCostPerKWh(_ raw: String) -> Decimal? {
        // Matches "0.35", "0,35", "0.35 €", "0,35 €/kWh", "EUR 0.35/kWh", etc.
        // Conservative: only returns a value when a kWh unit is mentioned.
        let lowered = raw.lowercased()
        guard lowered.contains("kwh") || lowered.contains("kw·h") || lowered.contains("kw-h") else {
            return nil
        }

        let pattern = #"(\d+[.,]?\d*)\s*[€$£eur]*\s*[/x ]+\s*kw\s*[h·\-]?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsString = raw as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let match = regex.firstMatch(in: raw, options: [], range: range),
              match.numberOfRanges > 1 else {
            return nil
        }
        let numericRange = match.range(at: 1)
        guard numericRange.location != NSNotFound else { return nil }
        let numberString = nsString.substring(with: numericRange)
            .replacingOccurrences(of: ",", with: ".")
        guard let decimal = Decimal(string: numberString), decimal > 0, decimal < 5 else {
            return nil
        }
        return decimal
    }

    enum SpeedCategory {
        case fast, semiFast, slow, unknown

        var label: String {
            switch self {
            case .fast: "Carga rápida"
            case .semiFast: "Semi-rápida"
            case .slow: "Carga lenta"
            case .unknown: "Desconocida"
            }
        }

        var icon: String {
            switch self {
            case .fast: "bolt.fill"
            case .semiFast: "bolt"
            case .slow: "bolt.slash"
            case .unknown: "questionmark"
            }
        }
    }

    static func == (lhs: ChargingStation, rhs: ChargingStation) -> Bool {
        lhs.id == rhs.id
    }
}
