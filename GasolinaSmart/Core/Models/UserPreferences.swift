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

@Observable
final class UserPreferences {
    var vehicles: [Vehicle] {
        didSet { save() }
    }
    var selectedVehicleId: UUID {
        didSet { save() }
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
    var preferredNavigationApp: PreferredNavigationApp {
        didSet { save() }
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

    var selectedFuelType: FuelType {
        get { selectedVehicle.fuelType }
        set {
            var v = selectedVehicle
            v.fuelType = newValue
            selectedVehicle = v
        }
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

    private let defaults = UserDefaults.standard
    private let vehiclesKey = "vehicles_v2"
    private let selectedVehicleIdKey = "selectedVehicleId_v2"

    init() {
        let loadedVehicles: [Vehicle]
        if let data = defaults.data(forKey: vehiclesKey),
           let decoded = try? JSONDecoder().decode([Vehicle].self, from: data),
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
        let navRaw = defaults.string(forKey: "preferredNavigationApp") ?? PreferredNavigationApp.appleMaps.rawValue
        preferredNavigationApp = PreferredNavigationApp(rawValue: navRaw) ?? .appleMaps
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

    private var saveWork: DispatchWorkItem?

    private func save() {
        saveWork?.cancel()
        saveWork = DispatchWorkItem { [weak self] in
            self?.persistToDisk()
        }
        DispatchQueue.main.async(execute: saveWork!)
    }

    private func persistToDisk() {
        if let data = try? JSONEncoder().encode(vehicles) {
            defaults.set(data, forKey: vehiclesKey)
        }
        defaults.set(selectedVehicleId.uuidString, forKey: selectedVehicleIdKey)
        defaults.set(preferredRadiusKm, forKey: "preferredRadiusKm")
        defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        defaults.set(Array(favoriteStationIds), forKey: "favoriteStationIds")
        defaults.set(appearance.rawValue, forKey: "appearance")
        defaults.set(preferredNavigationApp.rawValue, forKey: "preferredNavigationApp")
    }
}

private extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}
