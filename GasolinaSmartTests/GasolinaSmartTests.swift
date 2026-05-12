import Testing
import Foundation
import CoreLocation
@testable import GasolinaSmart

// MARK: - Vehicle Tests

struct VehicleTests {
    @Test func defaultConsumptionPerType() {
        #expect(Vehicle.defaultConsumption(for: .sedan) == 7.0)
        #expect(Vehicle.defaultConsumption(for: .suv) == 9.0)
        #expect(Vehicle.defaultConsumption(for: .hatchback) == 6.0)
        #expect(Vehicle.defaultConsumption(for: .van) == 10.0)
        #expect(Vehicle.defaultConsumption(for: .motorcycle) == 4.5)
    }

    @Test func vehicleDefaultValues() {
        let v = Vehicle(name: "Test", fuelType: .gasolina95)
        #expect(v.tankSizeLiters == 50)
        #expect(v.consumptionL100Km == 7.0)
        #expect(v.vehicleType == .sedan)
        #expect(v.vehicleColor == .silver)
    }

    @Test func vehicleCustomConsumption() {
        let v = Vehicle(name: "SUV", fuelType: .dieselA, consumptionL100Km: 8.5, vehicleType: .suv)
        #expect(v.consumptionL100Km == 8.5)
        #expect(v.vehicleType == .suv)
    }

    @Test func vehicleCodingRoundTrip() throws {
        let original = Vehicle(
            name: "Mi coche", brand: "Seat", fuelType: .gasolina95,
            tankSizeLiters: 45, consumptionL100Km: 6.5,
            vehicleType: .hatchback, vehicleColor: .red
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Vehicle.self, from: data)
        #expect(decoded.name == original.name)
        #expect(decoded.consumptionL100Km == 6.5)
        #expect(decoded.vehicleType == .hatchback)
    }

    @Test func vehicleDecodingWithoutConsumption() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","name":"Viejo","fuelType":"gasolina95","tankSizeLiters":50,"vehicleType":"suv"}
        """
        let data = json.data(using: .utf8)!
        let v = try JSONDecoder().decode(Vehicle.self, from: data)
        #expect(v.consumptionL100Km == 9.0)
    }
}

// MARK: - FuelStation Tests

struct FuelStationTests {
    static let sampleStation = FuelStation(
        id: "1", name: "E.S. Test", brand: "REPSOL",
        address: "Calle Mayor 1", municipality: "Madrid", province: "Madrid",
        latitude: 40.4168, longitude: -3.7038,
        prices: [.gasolina95: Decimal(string: "1.459")!, .dieselA: Decimal(string: "1.389")!],
        lastUpdated: Date()
    )

    @Test func priceForFuelType() {
        let station = Self.sampleStation
        #expect(station.price(for: .gasolina95) == Decimal(string: "1.459"))
        #expect(station.price(for: .dieselA) == Decimal(string: "1.389"))
        #expect(station.price(for: .glp) == nil)
    }

    @Test func distanceCalculation() {
        let station = Self.sampleStation
        let location = CLLocation(latitude: 40.4200, longitude: -3.7038)
        let km = station.distanceKm(from: location)
        #expect(km > 0 && km < 1)
    }

    @Test func coordinate() {
        let station = Self.sampleStation
        #expect(station.coordinate.latitude == 40.4168)
        #expect(station.coordinate.longitude == -3.7038)
    }

    @Test func codingRoundTrip() throws {
        let original = Self.sampleStation
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FuelStation.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.price(for: .gasolina95) == original.price(for: .gasolina95))
        #expect(decoded.brand == "REPSOL")
    }
}

// MARK: - StationStore Tests

struct StationStoreTests {
    @Test func estimatedSaving() {
        let store = StationStore()
        let saving = store.estimatedSaving(
            stationPrice: Decimal(string: "1.400")!,
            averagePrice: Decimal(string: "1.500")!,
            tankLiters: 50
        )
        #expect(saving == Decimal(5))
    }

    @Test func worthItLevels() {
        let store = StationStore()
        #expect(store.worthItLevel(saving: Decimal(string: "0.5")!) == .neutral)
        #expect(store.worthItLevel(saving: Decimal(string: "2.0")!) == .moderate)
        #expect(store.worthItLevel(saving: Decimal(string: "5.0")!) == .good)
    }

    @Test func fuelDecisionNoData() {
        let store = StationStore()
        let decision = store.fuelDecisionMessage(
            stationPrice: nil, averagePrice: nil,
            tankLiters: 50, distanceKm: nil
        )
        #expect(decision.verdict == .noData)
        #expect(decision.saving == nil)
    }

    @Test func fuelDecisionRefuelNow() {
        let store = StationStore()
        let decision = store.fuelDecisionMessage(
            stationPrice: Decimal(string: "1.300")!,
            averagePrice: Decimal(string: "1.500")!,
            tankLiters: 50, distanceKm: 2.0
        )
        #expect(decision.verdict == .refuelNow)
    }

    @Test func fuelDecisionTooFar() {
        let store = StationStore()
        let decision = store.fuelDecisionMessage(
            stationPrice: Decimal(string: "1.480")!,
            averagePrice: Decimal(string: "1.500")!,
            tankLiters: 50, distanceKm: 20.0
        )
        #expect(decision.verdict == .tooFar)
    }

    @Test func priceOpportunityLevels() {
        let store = StationStore()
        #expect(store.priceOpportunity(stationPrice: Decimal(string: "1.300")!, averagePrice: Decimal(string: "1.500")!, tankLiters: 50) == .great)
        #expect(store.priceOpportunity(stationPrice: Decimal(string: "1.480")!, averagePrice: Decimal(string: "1.500")!, tankLiters: 50) == .fair)
        #expect(store.priceOpportunity(stationPrice: Decimal(string: "1.550")!, averagePrice: Decimal(string: "1.500")!, tankLiters: 50) == .poor)
        #expect(store.priceOpportunity(stationPrice: nil, averagePrice: nil, tankLiters: 50) == .unknown)
    }
}

// MARK: - Formatter Tests

struct FormatterTests {
    @Test func priceFormatted() {
        let price = Decimal(string: "1.459")!
        #expect(price.priceFormatted == "1,459")
    }

    @Test func savingFormatted() {
        let saving = Decimal(string: "3.20")!
        let formatted = saving.savingFormatted
        #expect(formatted.contains("3"))
        #expect(formatted.contains("€"))
    }

    @Test func distanceFormattedMeters() {
        #expect(0.5.distanceFormatted == "500 m")
    }

    @Test func distanceFormattedKm() {
        #expect(2.3.distanceFormatted == "2.3 km")
    }
}

// MARK: - NavigationHelper Tests

struct NavigationHelperTests {
    @Test func appleMapsURL() {
        let url = NavigationHelper.navigationURL(latitude: 40.4168, longitude: -3.7038, app: .appleMaps)
        #expect(url.absoluteString.contains("maps.apple.com"))
        #expect(url.absoluteString.contains("40.4168"))
    }

    @Test func googleMapsURL() {
        let url = NavigationHelper.navigationURL(latitude: 40.4168, longitude: -3.7038, app: .googleMaps)
        #expect(url.absoluteString.contains("google"))
        #expect(url.absoluteString.contains("40.4168"))
    }
}

// MARK: - WidgetStationData Tests

struct WidgetStationDataTests {
    @Test func placeholderHasValidData() {
        let p = WidgetStationData.placeholder
        #expect(p.stationId == "placeholder")
        #expect(p.price == 1.459)
        #expect(!p.navigationURLString.isEmpty)
    }

    @Test func deepLinkURL() {
        let p = WidgetStationData.placeholder
        #expect(p.deepLinkURL.scheme == "gasolinasmart")
        #expect(p.deepLinkURL.absoluteString.contains("placeholder"))
    }

    @Test func codingRoundTrip() throws {
        let original = WidgetStationData.placeholder
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetStationData.self, from: data)
        #expect(decoded.stationId == original.stationId)
        #expect(decoded.navigationURLString == original.navigationURLString)
    }
}

// MARK: - PreferredNavigationApp Tests

struct PreferredNavigationAppTests {
    @Test func allCasesExist() {
        #expect(PreferredNavigationApp.allCases.count == 3)
    }

    @Test func displayNames() {
        #expect(PreferredNavigationApp.appleMaps.displayName == "Apple Maps")
        #expect(PreferredNavigationApp.googleMaps.displayName == "Google Maps")
        #expect(PreferredNavigationApp.waze.displayName == "Waze")
    }

    @Test func rawValues() {
        #expect(PreferredNavigationApp(rawValue: "appleMaps") == .appleMaps)
        #expect(PreferredNavigationApp(rawValue: "invalid") == nil)
    }
}

// MARK: - PriceOpportunity Tests

struct PriceOpportunityTests {
    @Test func colorsAndLabels() {
        #expect(PriceOpportunity.great.label == "Buena oportunidad")
        #expect(PriceOpportunity.fair.label == "Precio normal")
        #expect(PriceOpportunity.poor.label == "Por encima de la media")
        #expect(PriceOpportunity.unknown.label == "Sin datos suficientes")
    }

    @Test func icons() {
        #expect(PriceOpportunity.great.icon == "checkmark.seal.fill")
        #expect(PriceOpportunity.unknown.icon == "questionmark.circle")
    }
}
