import Foundation
import CoreLocation
import SwiftUI

@Observable
final class StationStore {
    private(set) var allStations: [FuelStation] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var lastUpdated: Date?
    private(set) var isUsingCache = false
    private(set) var cachedAveragePrice: Decimal?
    private var loadedRadiusKm: Double = 0
    private var loadGeneration = 0

    func loadCacheImmediately() async {
        guard allStations.isEmpty else { return }
        if let cached = await StationCache.shared.getStale() {
            allStations = cached
            lastUpdated = await StationCache.shared.get()?.timestamp
            isUsingCache = true
        }
    }

    func loadStations(near location: CLLocation? = nil, radiusKm: Double = 50) async {
        await loadFromNetwork(location: location, radiusKm: radiusKm)
    }

    func reloadIfNeeded(location: CLLocation?, radiusKm: Double) async {
        guard radiusKm > loadedRadiusKm else { return }
        await loadFromNetwork(location: location, radiusKm: radiusKm, force: true)
    }

    // MARK: - Network loading

    private func loadFromNetwork(location: CLLocation?, radiusKm: Double, force: Bool = false) async {
        loadGeneration += 1
        let myGeneration = loadGeneration

        if !force, let age = await StationCache.shared.cacheAge(), age < 5 * 60, !allStations.isEmpty {
            isLoading = false
            return
        }

        isLoading = allStations.isEmpty
        error = nil

        guard let location else {
            isLoading = false
            return
        }

        let fetchRadius = max(radiusKm + 10, 30)

        do {
            guard myGeneration == loadGeneration else { return }
            try await loadFromBackendAPI(location: location, radiusKm: fetchRadius, generation: myGeneration)
            guard myGeneration == loadGeneration else { return }
            loadedRadiusKm = fetchRadius
            isUsingCache = false
        } catch {
            guard myGeneration == loadGeneration else { return }
            do {
                try await loadFromDirectAPI(location: location, generation: myGeneration)
                guard myGeneration == loadGeneration else { return }
                loadedRadiusKm = 60
                isUsingCache = false
            } catch {
                guard myGeneration == loadGeneration else { return }
                if allStations.isEmpty {
                    self.error = error.localizedDescription
                }
            }
        }
        if myGeneration == loadGeneration {
            isLoading = false
        }
    }

    private func loadFromBackendAPI(location: CLLocation, radiusKm: Double, generation: Int) async throws {
        let response = try await BackendAPIService.shared.fetchStationsNearby(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radiusKm: radiusKm,
            limit: 500
        )
        guard generation == loadGeneration else { return }
        let stations = response.stations.map { $0.toFuelStation() }
        allStations = stations
        if let avg = response.average_price {
            cachedAveragePrice = Decimal(avg)
        }
        if let updated = response.last_updated {
            lastUpdated = BackendAPIService.isoFormatter.date(from: updated) ?? Date()
        } else {
            lastUpdated = Date()
        }
        await StationCache.shared.set(stations)
    }

    private func loadFromDirectAPI(location: CLLocation, generation: Int) async throws {
        let result = try await FuelAPIService.shared.fetchStationsProgressively(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        guard generation == loadGeneration else { return }
        allStations = result.all
        lastUpdated = Date()
        await StationCache.shared.set(result.all)
    }

    // MARK: - Queries (local filtering)

    func nearbyStations(
        location: CLLocation,
        radiusKm: Double,
        fuelType: FuelType,
        limit: Int? = nil
    ) -> [FuelStation] {
        var result = allStations
            .filter { $0.price(for: fuelType) != nil && $0.distanceKm(from: location) <= radiusKm }
            .sorted { $0.distance(from: location) < $1.distance(from: location) }
        if let limit { result = Array(result.prefix(limit)) }
        return result
    }

    func cheapestStation(
        location: CLLocation,
        radiusKm: Double,
        fuelType: FuelType
    ) -> FuelStation? {
        allStations
            .filter { $0.price(for: fuelType) != nil && $0.distanceKm(from: location) <= radiusKm }
            .min { ($0.price(for: fuelType) ?? .greatestFiniteMagnitude) < ($1.price(for: fuelType) ?? .greatestFiniteMagnitude) }
    }

    func averagePrice(
        location: CLLocation,
        radiusKm: Double,
        fuelType: FuelType
    ) -> Decimal? {
        let prices = allStations
            .filter { $0.price(for: fuelType) != nil && $0.distanceKm(from: location) <= radiusKm }
            .compactMap { $0.price(for: fuelType) }
        guard !prices.isEmpty else { return cachedAveragePrice }
        return prices.reduce(Decimal.zero, +) / Decimal(prices.count)
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

    func fuelDecisionMessage(
        stationPrice: Decimal?,
        averagePrice: Decimal?,
        tankLiters: Double,
        distanceKm: Double?
    ) -> FuelDecision {
        guard let stationPrice, let averagePrice else {
            return FuelDecision(verdict: .noData, saving: nil)
        }
        let saving = (averagePrice - stationPrice) * Decimal(tankLiters)
        let level = worthItLevel(saving: saving)

        if let distanceKm, distanceKm > 15, level != .good {
            return FuelDecision(verdict: .tooFar, saving: saving)
        }

        switch level {
        case .good:
            return FuelDecision(verdict: .refuelNow, saving: saving)
        case .moderate:
            return FuelDecision(verdict: .goodOption, saving: saving)
        case .neutral:
            return FuelDecision(verdict: .average, saving: saving)
        }
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

    func priceOpportunity(
        stationPrice: Decimal?,
        averagePrice: Decimal?,
        tankLiters: Double
    ) -> PriceOpportunity {
        guard let stationPrice, let averagePrice else { return .unknown }
        let saving = (averagePrice - stationPrice) * Decimal(tankLiters)
        if saving > 3 { return .great }
        if saving > 0 { return .fair }
        return .poor
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

struct FuelDecision {
    enum Verdict {
        case refuelNow
        case goodOption
        case average
        case tooFar
        case noData

        var title: String {
            switch self {
            case .refuelNow: "Reposta ahora"
            case .goodOption: "Buena oportunidad"
            case .average: "Precio normal"
            case .tooFar: "No compensa desviarse"
            case .noData: "Sin datos suficientes"
            }
        }

        var icon: String {
            switch self {
            case .refuelNow: "bolt.fill"
            case .goodOption: "hand.thumbsup.fill"
            case .average: "equal.circle"
            case .tooFar: "location.slash"
            case .noData: "questionmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .refuelNow: Theme.Colors.goodPrice
            case .goodOption: Theme.Colors.moderatePrice
            case .average: Theme.Colors.neutralPrice
            case .tooFar: Theme.Colors.expensivePrice
            case .noData: Theme.Colors.secondaryLabel
            }
        }
    }

    let verdict: Verdict
    let saving: Decimal?
}
