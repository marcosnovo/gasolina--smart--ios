import Foundation
import CoreLocation

struct FuelStation: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let brand: String
    let address: String
    let municipality: String
    let province: String
    let latitude: Double
    let longitude: Double
    let prices: [FuelType: Decimal]
    let lastUpdated: Date
    var isFavorite: Bool
    var country: Country

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func price(for fuelType: FuelType) -> Decimal? {
        prices[fuelType]
    }

    func distance(from location: CLLocation) -> CLLocationDistance {
        GeoDistance.distance(
            fromLatitude: location.coordinate.latitude,
            fromLongitude: location.coordinate.longitude,
            toLatitude: latitude,
            toLongitude: longitude
        )
    }

    func distanceKm(from location: CLLocation) -> Double {
        distance(from: location) / 1000.0
    }

    func distanceMeters(from coordinate: CLLocationCoordinate2D) -> Double {
        GeoDistance.distance(
            fromLatitude: coordinate.latitude,
            fromLongitude: coordinate.longitude,
            toLatitude: latitude,
            toLongitude: longitude
        )
    }

    func distanceKm(from coordinate: CLLocationCoordinate2D) -> Double {
        distanceMeters(from: coordinate) / 1000.0
    }

    static func == (lhs: FuelStation, rhs: FuelStation) -> Bool {
        lhs.id == rhs.id
    }

    enum CodingKeys: String, CodingKey {
        case id, name, brand, address, municipality, province
        case latitude, longitude, prices, lastUpdated, isFavorite, country
    }

    init(id: String, name: String, brand: String, address: String,
         municipality: String, province: String,
         latitude: Double, longitude: Double,
         prices: [FuelType: Decimal], lastUpdated: Date,
         isFavorite: Bool = false, country: Country = .spain) {
        self.id = id
        self.name = name
        self.brand = brand
        self.address = address
        self.municipality = municipality
        self.province = province
        self.latitude = latitude
        self.longitude = longitude
        self.prices = prices
        self.lastUpdated = lastUpdated
        self.isFavorite = isFavorite
        self.country = country
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        brand = try container.decode(String.self, forKey: .brand)
        address = try container.decode(String.self, forKey: .address)
        municipality = try container.decode(String.self, forKey: .municipality)
        province = try container.decode(String.self, forKey: .province)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        country = try container.decodeIfPresent(Country.self, forKey: .country) ?? .spain

        let rawPrices = try container.decode([String: String].self, forKey: .prices)
        var decoded: [FuelType: Decimal] = [:]
        for (key, value) in rawPrices {
            if let fuelType = FuelType(rawValue: key), let decimal = Decimal(string: value) {
                decoded[fuelType] = decimal
            }
        }
        prices = decoded
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(brand, forKey: .brand)
        try container.encode(address, forKey: .address)
        try container.encode(municipality, forKey: .municipality)
        try container.encode(province, forKey: .province)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(lastUpdated, forKey: .lastUpdated)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(country, forKey: .country)

        var rawPrices: [String: String] = [:]
        for (key, value) in prices {
            rawPrices[key.rawValue] = "\(value)"
        }
        try container.encode(rawPrices, forKey: .prices)
    }
}

enum GeoDistance {
    static func distance(
        fromLatitude: Double,
        fromLongitude: Double,
        toLatitude: Double,
        toLongitude: Double
    ) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = fromLatitude * .pi / 180
        let lat2 = toLatitude * .pi / 180
        let deltaLat = (toLatitude - fromLatitude) * .pi / 180
        let deltaLon = (toLongitude - fromLongitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }
}
