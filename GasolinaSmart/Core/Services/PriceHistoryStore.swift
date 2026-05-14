import Foundation

struct DailyPriceRecord: Codable, Sendable {
    let dateString: String
    let countryRaw: String
    let fuelTypeRaw: String
    let radiusKm: Int
    let cheapestPrice: Double
    let averagePrice: Double
    let stationCount: Int
}

actor PriceHistoryStore {
    static let shared = PriceHistoryStore()

    private var records: [DailyPriceRecord] = []
    private var loaded = false

    private init() {}

    func record(
        country: Country,
        fuelType: FuelType,
        radiusKm: Double,
        cheapest: Decimal,
        average: Decimal,
        stationCount: Int
    ) {
        loadIfNeeded()
        let dateString = Self.dateFormatter.string(from: Date())
        let roundedRadius = Int(radiusKm.rounded())
        let key = "\(dateString)-\(country.rawValue)-\(fuelType.rawValue)-\(roundedRadius)"

        if let idx = records.firstIndex(where: {
            "\($0.dateString)-\($0.countryRaw)-\($0.fuelTypeRaw)-\($0.radiusKm)" == key
        }) {
            records[idx] = DailyPriceRecord(
                dateString: dateString,
                countryRaw: country.rawValue,
                fuelTypeRaw: fuelType.rawValue,
                radiusKm: roundedRadius,
                cheapestPrice: NSDecimalNumber(decimal: cheapest).doubleValue,
                averagePrice: NSDecimalNumber(decimal: average).doubleValue,
                stationCount: stationCount
            )
        } else {
            records.append(DailyPriceRecord(
                dateString: dateString,
                countryRaw: country.rawValue,
                fuelTypeRaw: fuelType.rawValue,
                radiusKm: roundedRadius,
                cheapestPrice: NSDecimalNumber(decimal: cheapest).doubleValue,
                averagePrice: NSDecimalNumber(decimal: average).doubleValue,
                stationCount: stationCount
            ))
        }

        pruneOldRecords()
        save()
    }

    func history(
        for fuelType: FuelType,
        country: Country,
        radiusKm: Double,
        days: Int = 14
    ) -> [DailyPriceRecord] {
        loadIfNeeded()
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        let cutoffString = Self.dateFormatter.string(from: cutoff)
        let roundedRadius = Int(radiusKm.rounded())
        return records
            .filter {
                $0.fuelTypeRaw == fuelType.rawValue
                    && $0.countryRaw == country.rawValue
                    && $0.radiusKm == roundedRadius
                    && $0.dateString >= cutoffString
            }
            .sorted { $0.dateString < $1.dateString }
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([DailyPriceRecord].self, from: data) else { return }
        records = decoded
    }

    private func pruneOldRecords() {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return }
        let cutoffString = Self.dateFormatter.string(from: cutoff)
        records.removeAll { $0.dateString < cutoffString }
    }

    private func save() {
        guard let url = fileURL,
              let data = try? JSONEncoder().encode(records) else { return }
        let snapshot = data
        Task.detached(priority: .background) {
            try? snapshot.write(to: url, options: .atomic)
        }
    }

    private var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("price_history.json")
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
