import Foundation
import CoreLocation
import WidgetKit

enum WidgetDataProvider {
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetConstants.appGroupId)
    }

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

        let data = WidgetStationData(
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

        if read() == data { return }

        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: WidgetConstants.widgetDataKey)
        }

        WidgetCenter.shared.reloadAllTimelines()
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

        let price = cheapest.pricePerKWh ?? 0
        let priceDouble = NSDecimalNumber(decimal: price).doubleValue
        let distance = cheapest.distanceKm(from: userLocation)
        let displayName = cheapest.operatorName.isEmpty ? cheapest.name : cheapest.operatorName

        var savingText: String?
        var opportunityKey = "unknown"

        // Saving is expressed as money for a full battery charge so the
        // widget mirrors the fuel "tank fill saving" semantics.
        if let avg = averagePricePerKWh, price > 0 {
            let kWh = batteryCapacityKWh ?? 50
            let saving = (avg - price) * Decimal(kWh)
            if saving > 0 { savingText = saving.savingFormatted }
            if saving > 3 { opportunityKey = "great" }
            else if saving > 0 { opportunityKey = "fair" }
            else { opportunityKey = "poor" }
        }

        let data = WidgetStationData(
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

        if read() == data { return }

        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: WidgetConstants.widgetDataKey)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    static func read() -> WidgetStationData? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: WidgetConstants.widgetDataKey),
              let decoded = try? JSONDecoder().decode(WidgetStationData.self, from: data) else {
            return nil
        }
        return decoded
    }

    static func clear() {
        sharedDefaults?.removeObject(forKey: WidgetConstants.widgetDataKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
