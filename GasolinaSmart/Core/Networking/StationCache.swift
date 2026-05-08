import Foundation

actor StationCache {
    static let shared = StationCache()

    private var memoryCache: CachedData?
    private let cacheFileName = "stations_cache.json"

    private init() {}

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

    func get() -> CachedData? {
        if let memory = memoryCache {
            return memory
        }
        if let disk = loadFromDisk() {
            memoryCache = disk
            return disk
        }
        return nil
    }

    func getValid() -> [FuelStation]? {
        guard let cached = get(), !cached.isExpired else { return nil }
        return cached.stations
    }

    func getStale() -> [FuelStation]? {
        get()?.stations
    }

    func set(_ stations: [FuelStation]) {
        let data = CachedData(stations: stations, timestamp: Date())
        memoryCache = data
        saveToDisk(data)
    }

    func cacheAge() -> TimeInterval? {
        get()?.age
    }

    func isStale() -> Bool {
        get()?.isExpired ?? true
    }

    private var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(cacheFileName)
    }

    private func saveToDisk(_ data: CachedData) {
        guard let url = cacheURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let encoded = try? encoder.encode(data) else { return }
        try? encoded.write(to: url, options: .atomic)
    }

    private func loadFromDisk() -> CachedData? {
        guard let url = cacheURL,
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CachedData.self, from: data)
    }
}
