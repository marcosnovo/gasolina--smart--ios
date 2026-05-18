import Foundation
import CoreLocation
import WidgetKit

enum WidgetDataProvider {
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetConstants.appGroupId)
    }

    // Reused across update calls — JSON coders are not free to instantiate
    // and we encode on every location/radius/fuel change. Stays on the
    // main actor since WidgetDataProvider is called from the main MapView.
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func update(
        cheapestStation: FuelStation,
        fuelType: FuelType,
        country: Country,
        averagePrice: Decimal?,
        tankLiters: Double,
        userLocation: CLLocation,
        vehicle: Vehicle,
        radiusKm: Double,
        stationCount: Int,
        isDarkMode: Bool,
        navigationURLString: String
    ) {
        guard let defaults = sharedDefaults else { return }

        let data = buildFuelSnapshot(
            cheapestStation: cheapestStation,
            fuelType: fuelType,
            country: country,
            averagePrice: averagePrice,
            tankLiters: tankLiters,
            userLocation: userLocation,
            vehicle: vehicle,
            radiusKm: radiusKm,
            stationCount: stationCount,
            isDarkMode: isDarkMode,
            navigationURLString: navigationURLString
        )

        var didChange = false
        // Default key: mirrors the currently-active vehicle/fuel, used by
        // widgets the user hasn't configured for a specific vehicle.
        didChange = writeIfChanged(data, forKey: WidgetConstants.widgetDataKey, in: defaults) || didChange
        // Per-vehicle snapshot keyed by UUID — what a widget pinned to
        // "Coche A" reads. The active vehicle gets a fresh write on every
        // update; other vehicles are refreshed in `refreshAllSnapshots`.
        didChange = writeIfChanged(data, forKey: WidgetConstants.vehicleSnapshotKey(vehicle.id.uuidString), in: defaults) || didChange
        // Per-fuel snapshot — what a widget pinned to "Gasolina 95"
        // reads, irrespective of which vehicle is active in the app.
        didChange = writeIfChanged(data, forKey: WidgetConstants.fuelSnapshotKey(fuelType.rawValue), in: defaults) || didChange

        if didChange {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// EV variant: pushes the cheapest nearby charging station into the
    /// widget snapshot. Reuses WidgetStationData by mapping operator/price/
    /// kWh onto the same fields so the existing widget UI just works.
    static func updateForCharging(
        cheapest: ChargingStation,
        averagePricePerKWh: Decimal?,
        batteryCapacityKWh: Double?,
        userLocation: CLLocation,
        vehicle: Vehicle,
        radiusKm: Double,
        stationCount: Int,
        isDarkMode: Bool,
        navigationURLString: String
    ) {
        guard let defaults = sharedDefaults else { return }

        let data = buildChargingSnapshot(
            cheapest: cheapest,
            averagePricePerKWh: averagePricePerKWh,
            batteryCapacityKWh: batteryCapacityKWh,
            userLocation: userLocation,
            vehicle: vehicle,
            radiusKm: radiusKm,
            stationCount: stationCount,
            isDarkMode: isDarkMode,
            navigationURLString: navigationURLString
        )

        var didChange = false
        didChange = writeIfChanged(data, forKey: WidgetConstants.widgetDataKey, in: defaults) || didChange
        didChange = writeIfChanged(data, forKey: WidgetConstants.vehicleSnapshotKey(vehicle.id.uuidString), in: defaults) || didChange
        // EV doesn't have a useful per-fuel key; widgets pinned to a fuel
        // simply fall back to the default snapshot via the provider.

        if didChange {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    static func read() -> WidgetStationData? {
        readSnapshot(forKey: WidgetConstants.widgetDataKey)
    }

    static func clear() {
        sharedDefaults?.removeObject(forKey: WidgetConstants.widgetDataKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Refresh all snapshots

    /// Recomputes per-vehicle and per-fuel snapshots from in-memory data
    /// for every vehicle the user has + every supported fuel in the
    /// active country. Called after the full-country dataset loads so
    /// widgets bound to non-active vehicles also stay fresh.
    static func refreshAllSnapshots(
        vehicles: [Vehicle],
        allStations: [FuelStation],
        country: Country,
        userLocation: CLLocation,
        radiusKm: Double,
        isDarkMode: Bool,
        navigationApp: PreferredNavigationApp
    ) {
        guard let defaults = sharedDefaults else { return }
        guard !allStations.isEmpty else { return }

        var didChange = false

        // For each vehicle: cheapest station for its primary fuel.
        for vehicle in vehicles where !vehicle.isElectric {
            let fuel = vehicle.fuelType
            guard let snapshot = computeFuelSnapshot(
                fuel: fuel,
                country: country,
                userLocation: userLocation,
                radiusKm: radiusKm,
                allStations: allStations,
                vehicle: vehicle,
                isDarkMode: isDarkMode,
                navigationApp: navigationApp
            ) else { continue }
            let key = WidgetConstants.vehicleSnapshotKey(vehicle.id.uuidString)
            didChange = writeIfChanged(snapshot, forKey: key, in: defaults) || didChange
        }

        // Per-fuel snapshots: pick a representative vehicle (the first
        // combustion vehicle, or default) so the savings calc has a tank
        // size to work with. The widget bound to "Gasolina 95" will read
        // this regardless of which vehicle is currently active.
        let representativeVehicle = vehicles.first { !$0.isElectric } ?? .defaultVehicle
        for fuel in country.supportedFuelTypes {
            guard let snapshot = computeFuelSnapshot(
                fuel: fuel,
                country: country,
                userLocation: userLocation,
                radiusKm: radiusKm,
                allStations: allStations,
                vehicle: representativeVehicle,
                isDarkMode: isDarkMode,
                navigationApp: navigationApp
            ) else { continue }
            let key = WidgetConstants.fuelSnapshotKey(fuel.rawValue)
            didChange = writeIfChanged(snapshot, forKey: key, in: defaults) || didChange
        }

        if didChange {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Helpers

    private static func writeIfChanged(
        _ data: WidgetStationData,
        forKey key: String,
        in defaults: UserDefaults
    ) -> Bool {
        if data.hasSameVisibleContent(as: readSnapshot(forKey: key, in: defaults)) {
            return false
        }
        if let encoded = try? encoder.encode(data) {
            defaults.set(encoded, forKey: key)
            return true
        }
        return false
    }

    private static func readSnapshot(forKey key: String, in defaults: UserDefaults? = sharedDefaults) -> WidgetStationData? {
        guard let defaults,
              let data = defaults.data(forKey: key),
              let decoded = try? decoder.decode(WidgetStationData.self, from: data) else {
            return nil
        }
        return decoded
    }

    private static func computeFuelSnapshot(
        fuel: FuelType,
        country: Country,
        userLocation: CLLocation,
        radiusKm: Double,
        allStations: [FuelStation],
        vehicle: Vehicle,
        isDarkMode: Bool,
        navigationApp: PreferredNavigationApp
    ) -> WidgetStationData? {
        // Inline radius-filter + cheapest/average computation. Mirrors
        // StationStore.nearbySummary but is callable from a non-actor
        // context (refreshAllSnapshots runs from MapView).
        let origin = userLocation.coordinate
        let radiusM = radiusKm * 1000

        var cheapest: FuelStation?
        var cheapestPrice: Decimal?
        var sum: Decimal = 0
        var count: Int = 0

        for station in allStations {
            guard let price = station.price(for: fuel) else { continue }
            let dM = station.distanceMeters(from: origin)
            guard dM <= radiusM else { continue }
            sum += price
            count += 1
            if cheapestPrice == nil || price < cheapestPrice! {
                cheapestPrice = price
                cheapest = station
            }
        }

        guard let cheapest else { return nil }
        let avg: Decimal? = count == 0 ? nil : sum / Decimal(count)
        let navURL = NavigationHelper.navigationURL(
            latitude: cheapest.latitude,
            longitude: cheapest.longitude,
            app: navigationApp
        )

        return buildFuelSnapshot(
            cheapestStation: cheapest,
            fuelType: fuel,
            country: country,
            averagePrice: avg,
            tankLiters: vehicle.tankSizeLiters,
            userLocation: userLocation,
            vehicle: vehicle,
            radiusKm: radiusKm,
            stationCount: count,
            isDarkMode: isDarkMode,
            navigationURLString: navURL.absoluteString
        )
    }

    private static func buildFuelSnapshot(
        cheapestStation: FuelStation,
        fuelType: FuelType,
        country: Country,
        averagePrice: Decimal?,
        tankLiters: Double,
        userLocation: CLLocation,
        vehicle: Vehicle,
        radiusKm: Double,
        stationCount: Int,
        isDarkMode: Bool,
        navigationURLString: String
    ) -> WidgetStationData {
        let price = cheapestStation.price(for: fuelType) ?? 0
        let priceDouble = NSDecimalNumber(decimal: price).doubleValue
        let distance = cheapestStation.distanceKm(from: userLocation)

        var savingText: String?
        var opportunityKey = "unknown"

        if let avg = averagePrice {
            let saving = (avg - price) * Decimal(tankLiters)
            if saving > 0 {
                savingText = saving.savingFormatted
            }
            if saving > 3 {
                opportunityKey = "great"
            } else if saving > 0 {
                opportunityKey = "fair"
            } else {
                opportunityKey = "poor"
            }
        }

        return WidgetStationData(
            stationId: cheapestStation.id,
            stationName: cheapestStation.name,
            brand: cheapestStation.brand,
            price: priceDouble,
            priceFormatted: price.priceFormatted,
            fuelTypeRaw: fuelType.rawValue,
            fuelTypeLabel: fuelType.displayName,
            fuelTypeShort: fuelType.shortLabel,
            distanceKm: distance,
            address: cheapestStation.address,
            municipality: cheapestStation.municipality,
            stationLatitude: cheapestStation.latitude,
            stationLongitude: cheapestStation.longitude,
            userLatitude: userLocation.coordinate.latitude,
            userLongitude: userLocation.coordinate.longitude,
            averagePrice: averagePrice.map { NSDecimalNumber(decimal: $0).doubleValue },
            savingFormatted: savingText,
            opportunity: opportunityKey,
            vehicleName: vehicle.name,
            vehicleTypeRaw: vehicle.vehicleType.rawValue,
            vehicleColorRaw: vehicle.vehicleColor.rawValue,
            radiusKm: radiusKm,
            stationCount: stationCount,
            lastUpdated: Date(),
            isDarkMode: isDarkMode,
            navigationURLString: navigationURLString,
            fuelTypeUnit: fuelType.unit(for: country)
        )
    }

    private static func buildChargingSnapshot(
        cheapest: ChargingStation,
        averagePricePerKWh: Decimal?,
        batteryCapacityKWh: Double?,
        userLocation: CLLocation,
        vehicle: Vehicle,
        radiusKm: Double,
        stationCount: Int,
        isDarkMode: Bool,
        navigationURLString: String
    ) -> WidgetStationData {
        let price = cheapest.pricePerKWh ?? 0
        let priceDouble = NSDecimalNumber(decimal: price).doubleValue
        let distance = cheapest.distanceKm(from: userLocation)
        let displayName = cheapest.operatorName.isEmpty ? cheapest.name : cheapest.operatorName

        var savingText: String?
        var opportunityKey = "unknown"

        if let avg = averagePricePerKWh, price > 0 {
            let kWh = batteryCapacityKWh ?? 50
            let saving = (avg - price) * Decimal(kWh)
            if saving > 0 { savingText = saving.savingFormatted }
            if saving > 3 { opportunityKey = "great" }
            else if saving > 0 { opportunityKey = "fair" }
            else { opportunityKey = "poor" }
        }

        return WidgetStationData(
            stationId: cheapest.id,
            stationName: cheapest.name,
            brand: displayName,
            price: priceDouble,
            priceFormatted: price > 0 ? price.priceFormatted : "—",
            fuelTypeRaw: "ev",
            fuelTypeLabel: "Electric",
            fuelTypeShort: "EV",
            distanceKm: distance,
            address: cheapest.address,
            municipality: cheapest.town,
            stationLatitude: cheapest.latitude,
            stationLongitude: cheapest.longitude,
            userLatitude: userLocation.coordinate.latitude,
            userLongitude: userLocation.coordinate.longitude,
            averagePrice: averagePricePerKWh.map { NSDecimalNumber(decimal: $0).doubleValue },
            savingFormatted: savingText,
            opportunity: opportunityKey,
            vehicleName: vehicle.name,
            vehicleTypeRaw: vehicle.vehicleType.rawValue,
            vehicleColorRaw: vehicle.vehicleColor.rawValue,
            radiusKm: radiusKm,
            stationCount: stationCount,
            lastUpdated: Date(),
            isDarkMode: isDarkMode,
            navigationURLString: navigationURLString,
            fuelTypeUnit: "€/kWh"
        )
    }
}
