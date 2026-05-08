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

    func loadStations(near location: CLLocation? = nil) async {
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
            if let location {
                let result = try await FuelAPIService.shared.fetchStationsProgressively(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                if allStations.isEmpty {
                    allStations = result.nearby
                }
                allStations = result.all
            } else {
                let stations = try await FuelAPIService.shared.fetchStations()
                allStations = stations
            }
            await StationCache.shared.set(allStations)
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
        fuelType: FuelType,
        limit: Int? = nil
    ) -> [FuelStation] {
        var result = allStations
            .filter { $0.price(for: fuelType) != nil }
            .filter { $0.distanceKm(from: location) <= radiusKm }
            .sorted { $0.distance(from: location) < $1.distance(from: location) }
        if let limit { result = Array(result.prefix(limit)) }
        return result
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
