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
            navigationURLString: navigationURLString
        )

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
