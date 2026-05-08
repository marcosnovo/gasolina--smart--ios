import Foundation
import CoreLocation

@Observable
final class StationStore {
    private(set) var allStations: [FuelStation] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var lastUpdated: Date?
    private(set) var isUsingCache = false

    func loadStations() async {
        if allStations.isEmpty, let cached = await StationCache.shared.getStale() {
            allStations = cached
            lastUpdated = await StationCache.shared.get()?.timestamp
            isUsingCache = true
        }

        if let age = await StationCache.shared.cacheAge(), age < 15 * 60 {
            isLoading = false
            return
        }

        isLoading = allStations.isEmpty
        error = nil

        do {
            let stations = try await FuelAPIService.shared.fetchStations()
            allStations = stations
            await StationCache.shared.set(stations)
            lastUpdated = Date()
            isUsingCache = false
        } catch {
            if allStations.isEmpty {
                self.error = error.localizedDescription
            }
        }
        isLoading = false
    }

    func nearbyStations(
        location: CLLocation,
        radiusKm: Double,
        fuelType: FuelType
    ) -> [FuelStation] {
        allStations
            .filter { $0.price(for: fuelType) != nil }
            .filter { $0.distanceKm(from: location) <= radiusKm }
            .sorted { $0.distance(from: location) < $1.distance(from: location) }
    }

    func cheapestStation(
        location: CLLocation,
        radiusKm: Double,
        fuelType: FuelType
    ) -> FuelStation? {
        nearbyStations(location: location, radiusKm: radiusKm, fuelType: fuelType)
            .sorted {
                let p1 = $0.price(for: fuelType) ?? Decimal.greatestFiniteMagnitude
                let p2 = $1.price(for: fuelType) ?? Decimal.greatestFiniteMagnitude
                return p1 < p2
            }
            .first
    }

    func averagePrice(
        location: CLLocation,
        radiusKm: Double,
        fuelType: FuelType
    ) -> Decimal? {
        let stations = nearbyStations(location: location, radiusKm: radiusKm, fuelType: fuelType)
        let prices = stations.compactMap { $0.price(for: fuelType) }
        guard !prices.isEmpty else { return nil }
        let sum = prices.reduce(Decimal.zero, +)
        return sum / Decimal(prices.count)
    }

    func estimatedSaving(
        stationPrice: Decimal,
        averagePrice: Decimal,
        tankLiters: Double
    ) -> Decimal {
        (averagePrice - stationPrice) * Decimal(tankLiters)
    }

    func worthItLevel(saving: Decimal) -> WorthItLevel {
        if saving < 1 { return .neutral }
        if saving <= 3 { return .moderate }
        return .good
    }

    var dataFreshnessText: String {
        guard let lastUpdated else { return "Sin datos" }
        let minutes = Int(Date().timeIntervalSince(lastUpdated) / 60)
        let prefix = isLoading ? "Actualizando... · " : ""
        if minutes < 1 { return "\(prefix)Actualizado ahora" }
        if minutes < 60 { return "\(prefix)Hace \(minutes) min" }
        let hours = minutes / 60
        return "\(prefix)Hace \(hours) h"
    }
}

enum WorthItLevel {
    case neutral
    case moderate
    case good

    var message: String {
        switch self {
        case .neutral: "Precio similar a la media"
        case .moderate: "Puede compensar"
        case .good: "Buena oportunidad"
        }
    }

    var icon: String {
        switch self {
        case .neutral: "equal.circle"
        case .moderate: "arrow.down.circle"
        case .good: "arrow.down.circle.fill"
        }
    }

    var shortMessage: String {
        switch self {
        case .neutral: "Similar"
        case .moderate: "Compensa"
        case .good: "Buen precio"
        }
    }
}
