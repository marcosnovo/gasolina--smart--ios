import Foundation

actor StationCache {
    static let shared = StationCache()

    private var memoryCache: [String: CachedData] = [:]

    init() {}

    struct CachedData: Codable, Sendable {
        let stations: [FuelStation]
        let timestamp: Date

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 30 * 60
        }

        var age: TimeInterval {
            Date().timeIntervalSince(timestamp)
        }
    }

    func get(country: Country = .spain) -> CachedData? {
        let key = country.rawValue
        if let memory = memoryCache[key] {
            return memory
        }
        if let disk = loadFromDisk(country: country) {
            memoryCache[key] = disk
            return disk
        }
        return nil
    }

    func getValid(country: Country = .spain) -> [FuelStation]? {
        guard let cached = get(country: country), !cached.isExpired else { return nil }
        return cached.stations
    }

    func getStale(country: Country = .spain) -> [FuelStation]? {
        get(country: country)?.stations
    }

    func set(_ stations: [FuelStation], country: Country = .spain) {
        let data = CachedData(stations: stations, timestamp: Date())
        memoryCache[country.rawValue] = data
        saveToDisk(data, country: country)
    }

    func cacheAge(country: Country = .spain) -> TimeInterval? {
        get(country: country)?.age
    }

    func isStale(country: Country = .spain) -> Bool {
        get(country: country)?.isExpired ?? true
    }

    private func cacheURL(country: Country) -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("stations_cache_\(country.rawValue).json")
    }

    private func saveToDisk(_ data: CachedData, country: Country) {
        guard let url = cacheURL(country: country) else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let encoded = try? encoder.encode(data) else { return }
        try? encoded.write(to: url, options: .atomic)
    }

    private func loadFromDisk(country: Country) -> CachedData? {
        guard let url = cacheURL(country: country),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CachedData.self, from: data)
    }
}
