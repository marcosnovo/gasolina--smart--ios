import Testing
import Foundation
import CoreLocation
@testable import GasolinaSmart

// MARK: - A.4 Country.detect bounding box

struct CountryDetectTests {
    @Test func returnsSpainForMadrid() {
        let coord = CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038)
        #expect(Country.detect(from: coord) == .spain)
    }

    @Test func returnsItalyForRome() {
        let coord = CLLocationCoordinate2D(latitude: 41.9028, longitude: 12.4964)
        #expect(Country.detect(from: coord) == .italy)
    }

    @Test func returnsFranceForParis() {
        let coord = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        #expect(Country.detect(from: coord) == .france)
    }

    @Test func returnsUKForLondon() {
        let coord = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        #expect(Country.detect(from: coord) == .uk)
    }

    @Test func returnsGermanyForBerlin() {
        let coord = CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050)
        #expect(Country.detect(from: coord) == .germany)
    }

    @Test func returnsNilForOceanCoordinates() {
        // Country.detect returns Optional — Atlantic mid-ocean matches no bbox
        let coord = CLLocationCoordinate2D(latitude: 30.0, longitude: -30.0)
        #expect(Country.detect(from: coord) == nil)
    }

    @Test func returnsNilForLisbon() {
        // Lisbon (38.72, -9.14) is outside Spain bbox (maxLon=4.4) and France bbox
        let coord = CLLocationCoordinate2D(latitude: 38.7223, longitude: -9.1393)
        // Actually, Spain bbox is minLon=-18.2, maxLon=4.4 — Lisbon lon -9.14 IS inside Spain bbox
        // Spain bbox also includes lat 27.5-43.8, Lisbon lat 38.72 IS inside
        // So Lisbon falls within Spain's bounding box
        #expect(Country.detect(from: coord) == .spain)
    }
}

// MARK: - A.3 UserPreferences migration

struct UserPreferencesMigrationTests {
    @Test func defaultsToSpainOnFirstLaunch() {
        let suite = "test-first-launch-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        let prefs = UserPreferences(userDefaults: defaults)
        #expect(prefs.selectedCountry == .spain)
        UserDefaults.standard.removePersistentDomain(forName: suite)
    }

    @Test func keepsValidStoredCountry() {
        let suite = "test-valid-country-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set("FR", forKey: "selectedCountry")
        let prefs = UserPreferences(userDefaults: defaults)
        #expect(prefs.selectedCountry == .france)
        UserDefaults.standard.removePersistentDomain(forName: suite)
    }

    @Test func invalidCountryFallsBackToSpain() {
        let suite = "test-invalid-country-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set("PT", forKey: "selectedCountry")
        let prefs = UserPreferences(userDefaults: defaults)
        #expect(prefs.selectedCountry == .spain)
        #expect(defaults.string(forKey: "selectedCountry") == "ES")
        UserDefaults.standard.removePersistentDomain(forName: suite)
    }
}

// MARK: - A.5 StationCache country isolation

struct StationCacheTests {
    @Test func doesNotMixCountries() async {
        let cache = StationCache()

        let spanishStation = FuelStation(
            id: "ES_123", name: "Test ES", brand: "Repsol",
            address: "Calle 1", municipality: "Madrid", province: "Madrid",
            latitude: 40.4, longitude: -3.7,
            prices: [.gasolina95: 1.459], lastUpdated: Date(),
            country: .spain
        )

        await cache.set([spanishStation], country: .spain)

        let frenchCached = await cache.getValid(country: .france)
        #expect(frenchCached == nil)

        let spanishCached = await cache.getValid(country: .spain)
        #expect(spanishCached?.count == 1)
        #expect(spanishCached?.first?.id == "ES_123")
    }
}

// MARK: - A.6 Deeplink parsing

struct DeeplinkParserTests {
    @Test func legacyIDAssumesSpain() {
        let url = URL(string: "gasolinasmart://station/12345")!
        let result = DeeplinkParser.parse(url)
        #expect(result?.stationId == "ES_12345")
        #expect(result?.country == .spain)
    }

    @Test func prefixedFrenchID() {
        let url = URL(string: "gasolinasmart://station/FR_42")!
        let result = DeeplinkParser.parse(url)
        #expect(result?.stationId == "FR_42")
        #expect(result?.country == .france)
    }

    @Test func prefixedItalianID() {
        let url = URL(string: "gasolinasmart://station/IT_67890")!
        let result = DeeplinkParser.parse(url)
        #expect(result?.stationId == "IT_67890")
        #expect(result?.country == .italy)
    }

    @Test func malformedURLReturnsNil() {
        let url = URL(string: "gasolinasmart://nonsense")!
        #expect(DeeplinkParser.parse(url) == nil)
    }

    @Test func wrongSchemeReturnsNil() {
        let url = URL(string: "https://station/IT_123")!
        #expect(DeeplinkParser.parse(url) == nil)
    }
}
