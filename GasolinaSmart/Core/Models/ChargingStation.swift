import Foundation
import CoreLocation

struct ChargingConnection: Equatable, Sendable {
    let typeName: String
    let powerKW: Double?
    let quantity: Int?
    /// Canonical short name ("CCS", "Type 2", …) computed once at init so
    /// hot-path filters and badges don't redo `.lowercased()` per access.
    let shortName: String

    nonisolated init(typeName: String, powerKW: Double?, quantity: Int?) {
        self.typeName = typeName
        self.powerKW = powerKW
        self.quantity = quantity
        self.shortName = ChargingStation.normalizeConnectorShortName(typeName)
    }
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

    // Derived fields cached at init. We have tens of thousands of stations
    // in memory and these are read from filters, sorts and pin views on
    // every map update — recomputing the regex, lowercasing and connector
    // scans per access showed up as a measurable cost in the previous
    // perf audit.
    let pricePerKWh: Decimal?
    let isFree: Bool
    let maxPowerKW: Double?
    let speedCategory: SpeedCategory
    let connectorShortNames: Set<String>

    nonisolated init(
        id: String,
        name: String,
        operatorName: String,
        address: String,
        town: String,
        province: String,
        latitude: Double,
        longitude: Double,
        connections: [ChargingConnection],
        numberOfPoints: Int,
        isOperational: Bool,
        usageCost: String?,
        lastUpdated: Date?
    ) {
        self.id = id
        self.name = name
        self.operatorName = operatorName
        self.address = address
        self.town = town
        self.province = province
        self.latitude = latitude
        self.longitude = longitude
        self.connections = connections
        self.numberOfPoints = numberOfPoints
        self.isOperational = isOperational
        self.usageCost = usageCost
        self.lastUpdated = lastUpdated

        self.pricePerKWh = Self.parsePricePerKWh(from: usageCost)
        self.isFree = Self.parseIsFree(from: usageCost)
        let maxPower = connections.compactMap(\.powerKW).max()
        self.maxPowerKW = maxPower
        self.speedCategory = Self.computeSpeedCategory(maxPower: maxPower, connections: connections)
        var names = Set<String>()
        names.reserveCapacity(connections.count)
        for c in connections { names.insert(c.shortName) }
        self.connectorShortNames = names
    }

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

    var connectionSummary: String {
        let types = Set(connections.map(\.typeName)).sorted()
        return types.joined(separator: ", ")
    }

    /// True when the station has any connector compatible with `filter`.
    /// Permissive: a station with no connector info at all still matches —
    /// we'd rather show a possibly-compatible station than hide it because
    /// OpenChargeMap didn't have the data.
    ///
    /// Uses the pre-normalised `connectorShortNames` set so the hot path
    /// is a single set intersection check, no per-call lowercasing.
    func matchesConnectorFilter(_ filter: Set<String>) -> Bool {
        if filter.isEmpty { return true }
        if connections.isEmpty { return true }
        for name in connectorShortNames {
            if filter.contains(name) { return true }
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

    private static let costParsingRegex: NSRegularExpression? = {
        let pattern = #"(\d+[.,]?\d*)\s*[€$£eur]*\s*[/x ]+\s*kw\s*[h·\-]?"#
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// Parses a price-per-kWh out of a free-text usageCost. Returns nil if
    /// the string doesn't unambiguously mention a kWh unit.
    static func parseCostPerKWh(_ raw: String) -> Decimal? {
        parsePricePerKWh(from: raw)
    }

    private static func parsePricePerKWh(from raw: String?) -> Decimal? {
        guard let raw else { return nil }
        let lowered = raw.lowercased()
        guard lowered.contains("kwh") || lowered.contains("kw·h") || lowered.contains("kw-h") else {
            return nil
        }
        guard let regex = costParsingRegex else { return nil }
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

    private static func parseIsFree(from raw: String?) -> Bool {
        guard let cost = raw?.lowercased() else { return false }
        return cost.contains("gratu") || cost.contains("free") || cost.contains("libre") || cost == "0"
    }

    private static func computeSpeedCategory(
        maxPower: Double?,
        connections: [ChargingConnection]
    ) -> SpeedCategory {
        if let maxPower {
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
            if conn.shortName == "CCS" || conn.shortName == "CHAdeMO" || conn.shortName == "NACS" {
                return .fast
            }
        }
        return .unknown
    }

    enum SpeedCategory: Sendable {
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
