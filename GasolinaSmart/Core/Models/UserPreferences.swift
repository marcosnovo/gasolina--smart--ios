import Foundation
import SwiftUI

enum AppAppearance: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: "Sistema"
        case .light: "Claro"
        case .dark: "Oscuro"
        }
    }
}

enum PreferredNavigationApp: String, CaseIterable, Codable {
    case appleMaps
    case googleMaps
    case waze

    var displayName: String {
        switch self {
        case .appleMaps: "Apple Maps"
        case .googleMaps: "Google Maps"
        case .waze: "Waze"
        }
    }

    var icon: String {
        switch self {
        case .appleMaps: "map.fill"
        case .googleMaps: "mappin.circle.fill"
        case .waze: "car.fill"
        }
    }
}

struct FavoriteAddress: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var savedDate: Date

    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.savedDate = Date()
    }
}

@Observable
final class UserPreferences {
    var vehicles: [Vehicle] {
        didSet { save() }
    }
    var selectedVehicleId: UUID {
        didSet {
            // Switching vehicle: drop any session override so the new vehicle
            // shows its own primary fuel.
            if oldValue != selectedVehicleId, fuelFilterOverride != nil {
                fuelFilterOverride = nil
            }
            save()
        }
    }
    var preferredRadiusKm: Double {
        didSet { save() }
    }
    var hasCompletedOnboarding: Bool {
        didSet { save() }
    }
    var favoriteStationIds: Set<String> {
        didSet { save() }
    }
    var appearance: AppAppearance {
        didSet { save() }
    }
    var enabledNavigationApps: Set<PreferredNavigationApp> {
        didSet { save() }
    }
    var favoriteAddresses: [FavoriteAddress] {
        didSet { save() }
    }
    var showChargingStations: Bool {
        didSet { save() }
    }
    var selectedCountry: Country {
        didSet {
            if oldValue != selectedCountry {
                let supported = selectedCountry.supportedFuelTypes
                // Drop an override that's no longer valid for the new country.
                if let override = fuelFilterOverride, !supported.contains(override) {
                    fuelFilterOverride = nil
                }
                // If the vehicle's own fuel isn't supported either, fall back
                // to the country's default (becomes the new override). Skip
                // when the country has no fuel data — no override makes sense.
                if selectedCountry.hasFuelData,
                   !supported.contains(selectedVehicle.fuelType),
                   fuelFilterOverride == nil {
                    fuelFilterOverride = selectedCountry.defaultFuel
                }
                save()
            }
        }
    }
    var appLanguage: AppLanguage {
        didSet { save() }
    }
    var autoDetectCountry: Bool {
        didSet { save() }
    }

    var loc: Loc { Loc(appLanguage) }
    var resolvedLanguage: AppLanguage { appLanguage.resolved }

    var preferredNavigationApp: PreferredNavigationApp {
        if enabledNavigationApps.count == 1, let single = enabledNavigationApps.first {
            return single
        }
        return .appleMaps
    }

    var colorScheme: ColorScheme? {
        switch appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var selectedVehicle: Vehicle {
        get { vehicles.first { $0.id == selectedVehicleId } ?? vehicles.first ?? .defaultVehicle }
        set {
            if let idx = vehicles.firstIndex(where: { $0.id == newValue.id }) {
                vehicles[idx] = newValue
            }
        }
    }

    // Map filter override for the current session. nil means "use the vehicle's
    // primary fuel". Set when the user picks a different fuel in the picker
    // (typical case: GLP cars also filling with gasoline). Cleared when the
    // user switches vehicle, so each vehicle starts on its own primary fuel.
    var fuelFilterOverride: FuelType? {
        didSet { save() }
    }

    var selectedFuelType: FuelType {
        get { fuelFilterOverride ?? selectedVehicle.fuelType }
        set {
            if newValue == selectedVehicle.fuelType {
                // Picking the vehicle's own fuel clears any override.
                if fuelFilterOverride != nil { fuelFilterOverride = nil }
            } else {
                fuelFilterOverride = newValue
            }
        }
    }

    // Every fuel the selected vehicle can actually run on. Mono-fuel vehicles
    // return just [primary]; LPG-equipped vehicles also include .glp. Battery
    // electric vehicles return [] — they use charging points instead.
    // Fuel-less countries (US) return [] regardless of vehicle so the map
    // never queries non-existent fuel data.
    var vehicleSupportedFuels: [FuelType] {
        if !selectedCountry.hasFuelData { return [] }
        if selectedVehicle.isElectric { return [] }
        var fuels: [FuelType] = [selectedVehicle.fuelType]
        if selectedVehicle.hasGLP, !fuels.contains(.glp) {
            fuels.append(.glp)
        }
        return fuels
    }

    /// True when charging-station markers should be visible: either the user
    /// explicitly enabled them, the active vehicle is an EV (forcing it on),
    /// or the active country has no fuel data (US — charging is the only
    /// thing we can show).
    var effectiveShowChargingStations: Bool {
        showChargingStations || selectedVehicle.isElectric || !selectedCountry.hasFuelData
    }

    /// True when the map is operating in a "chargers only" mode — either
    /// because the vehicle is electric or because the country has no fuel
    /// data. Drives UI decisions in MapView (vehicle pill chip, area
    /// search branch, vehicle-switch state cleanup).
    var isChargingOnlyMode: Bool {
        selectedVehicle.isElectric || !selectedCountry.hasFuelData
    }

    var tankSizeLiters: Double {
        get { selectedVehicle.tankSizeLiters }
        set {
            var v = selectedVehicle
            v.tankSizeLiters = newValue
            selectedVehicle = v
        }
    }

    var consumptionL100Km: Double {
        get { selectedVehicle.consumptionL100Km }
        set {
            var v = selectedVehicle
            v.consumptionL100Km = newValue
            selectedVehicle = v
        }
    }

    static let availableRadii: [Double] = [2, 5, 10, 20, 30, 50]

    private let defaults: UserDefaults
    private let vehiclesKey = "vehicles_v2"
    private let selectedVehicleIdKey = "selectedVehicleId_v2"
    // Reused across save/load — JSONCoders aren't free and we save on every
    // setting change (favourites, vehicles, radius, …).
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        let loadedVehicles: [Vehicle]
        if let data = defaults.data(forKey: vehiclesKey),
           let decoded = try? decoder.decode([Vehicle].self, from: data),
           !decoded.isEmpty {
            loadedVehicles = decoded
        } else {
            let fuelRaw = defaults.string(forKey: "selectedFuelType") ?? FuelType.gasolina95.rawValue
            let fuel = FuelType(rawValue: fuelRaw) ?? .gasolina95
            let tank = defaults.double(forKey: "tankSizeLiters").nonZero ?? 50.0
            loadedVehicles = [Vehicle(name: "Mi coche", fuelType: fuel, tankSizeLiters: tank)]
        }

        vehicles = loadedVehicles

        if let idString = defaults.string(forKey: selectedVehicleIdKey),
           let id = UUID(uuidString: idString) {
            selectedVehicleId = id
        } else {
            selectedVehicleId = loadedVehicles.first?.id ?? UUID()
        }

        preferredRadiusKm = defaults.double(forKey: "preferredRadiusKm").nonZero ?? 5.0
        hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        let ids = defaults.stringArray(forKey: "favoriteStationIds") ?? []
        favoriteStationIds = Set(ids)
        let appearanceRaw = defaults.string(forKey: "appearance") ?? AppAppearance.system.rawValue
        appearance = AppAppearance(rawValue: appearanceRaw) ?? .system
        if let addrData = defaults.data(forKey: "favoriteAddresses"),
           let decoded = try? decoder.decode([FavoriteAddress].self, from: addrData) {
            favoriteAddresses = decoded
        } else {
            favoriteAddresses = []
        }
        if let navArray = defaults.stringArray(forKey: "enabledNavigationApps") {
            enabledNavigationApps = Set(navArray.compactMap { PreferredNavigationApp(rawValue: $0) })
        } else if let navRaw = defaults.string(forKey: "preferredNavigationApp"),
                  let app = PreferredNavigationApp(rawValue: navRaw) {
            enabledNavigationApps = [app]
        } else {
            enabledNavigationApps = [.appleMaps]
        }
        showChargingStations = defaults.object(forKey: "showChargingStations") as? Bool ?? false
        let countryRaw = defaults.string(forKey: "selectedCountry") ?? Country.spain.rawValue
        if let country = Country(rawValue: countryRaw) {
            selectedCountry = country
        } else {
            selectedCountry = .spain
            defaults.set(Country.spain.rawValue, forKey: "selectedCountry")
        }
        let langRaw = defaults.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
        appLanguage = AppLanguage(rawValue: langRaw) ?? .system
        autoDetectCountry = defaults.object(forKey: "autoDetectCountry") as? Bool ?? false
        if let overrideRaw = defaults.string(forKey: "fuelFilterOverride"),
           let override = FuelType(rawValue: overrideRaw) {
            fuelFilterOverride = override
        } else {
            fuelFilterOverride = nil
        }
    }

    func addVehicle(_ vehicle: Vehicle) {
        vehicles.append(vehicle)
        selectedVehicleId = vehicle.id
    }

    func removeVehicle(_ vehicle: Vehicle) {
        vehicles.removeAll { $0.id == vehicle.id }
        if selectedVehicleId == vehicle.id {
            selectedVehicleId = vehicles.first?.id ?? UUID()
        }
    }

    func toggleFavorite(_ stationId: String) {
        if favoriteStationIds.contains(stationId) {
            favoriteStationIds.remove(stationId)
        } else {
            favoriteStationIds.insert(stationId)
        }
    }

    func isFavorite(_ stationId: String) -> Bool {
        favoriteStationIds.contains(stationId)
    }

    func addFavoriteAddress(_ address: FavoriteAddress) {
        favoriteAddresses.append(address)
    }

    func removeFavoriteAddress(_ address: FavoriteAddress) {
        favoriteAddresses.removeAll { $0.id == address.id }
    }

    private var saveTask: Task<Void, Never>?

    private func save() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.persistToDisk()
        }
    }

    private func persistToDisk() {
        if let data = try? encoder.encode(vehicles) {
            defaults.set(data, forKey: vehiclesKey)
        }
        defaults.set(selectedVehicleId.uuidString, forKey: selectedVehicleIdKey)
        defaults.set(preferredRadiusKm, forKey: "preferredRadiusKm")
        defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        defaults.set(Array(favoriteStationIds), forKey: "favoriteStationIds")
        if let addrData = try? encoder.encode(favoriteAddresses) {
            defaults.set(addrData, forKey: "favoriteAddresses")
        }
        defaults.set(appearance.rawValue, forKey: "appearance")
        defaults.set(enabledNavigationApps.map(\.rawValue), forKey: "enabledNavigationApps")
        defaults.set(showChargingStations, forKey: "showChargingStations")
        defaults.set(selectedCountry.rawValue, forKey: "selectedCountry")
        defaults.set(appLanguage.rawValue, forKey: "appLanguage")
        defaults.set(autoDetectCountry, forKey: "autoDetectCountry")
        if let override = fuelFilterOverride {
            defaults.set(override.rawValue, forKey: "fuelFilterOverride")
        } else {
            defaults.removeObject(forKey: "fuelFilterOverride")
        }
        let shared = UserDefaults(suiteName: "group.MarcosNovo.GasolinaSmart")
        shared?.set(appLanguage.rawValue, forKey: "appLanguage")
        shared?.set(selectedCountry.rawValue, forKey: "selectedCountry")
    }
}

private extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}
