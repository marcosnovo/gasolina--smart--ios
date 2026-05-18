import AppIntents
import Foundation

// MARK: - Vehicle entity

/// A single vehicle exposed to the widget configuration editor. Backed by
/// the App-Group-published list that the main app keeps in sync from
/// UserPreferences.persistToDisk.
struct VehicleEntity: AppEntity, Identifiable, Hashable {
    let id: String
    let name: String
    let fuelTypeRaw: String
    let isElectric: Bool

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Vehículo")
    }
    static var defaultQuery = VehicleQuery()

    var displayRepresentation: DisplayRepresentation {
        let subtitle: String?
        if isElectric {
            subtitle = "EV"
        } else {
            subtitle = fuelTypeRaw.isEmpty ? nil : fuelTypeRaw
        }
        if let subtitle {
            return DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
        }
        return DisplayRepresentation(title: "\(name)")
    }
}

struct VehicleQuery: EntityQuery {
    func entities(for identifiers: [VehicleEntity.ID]) async throws -> [VehicleEntity] {
        allVehicles().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [VehicleEntity] {
        allVehicles()
    }

    func defaultResult() async -> VehicleEntity? {
        allVehicles().first
    }

    private func allVehicles() -> [VehicleEntity] {
        guard let defaults = UserDefaults(suiteName: WidgetConstants.appGroupId),
              let data = defaults.data(forKey: WidgetConstants.vehiclesKey),
              let summaries = try? JSONDecoder().decode([WidgetVehicleSummary].self, from: data) else {
            return []
        }
        return summaries.map {
            VehicleEntity(
                id: $0.id,
                name: $0.name,
                fuelTypeRaw: $0.fuelTypeRaw,
                isElectric: $0.isElectric
            )
        }
    }
}

// MARK: - Fuel entity

struct FuelEntity: AppEntity, Identifiable, Hashable {
    let id: String        // FuelType raw value
    let displayName: String
    let shortLabel: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Combustible")
    }
    static var defaultQuery = FuelQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", subtitle: "\(shortLabel)")
    }
}

struct FuelQuery: EntityQuery {
    func entities(for identifiers: [FuelEntity.ID]) async throws -> [FuelEntity] {
        allFuels().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [FuelEntity] {
        allFuels()
    }

    private func allFuels() -> [FuelEntity] {
        guard let defaults = UserDefaults(suiteName: WidgetConstants.appGroupId),
              let data = defaults.data(forKey: WidgetConstants.supportedFuelsKey),
              let summaries = try? JSONDecoder().decode([WidgetFuelSummary].self, from: data) else {
            return []
        }
        return summaries.map {
            FuelEntity(id: $0.raw, displayName: $0.displayName, shortLabel: $0.shortLabel)
        }
    }
}

// MARK: - Configuration intent

/// User-facing configuration for the cheapest-station widget. The user
/// can pin the widget to a specific vehicle, to a specific fuel, or
/// leave both blank to mirror whatever vehicle is currently active in
/// the app (the original behaviour).
///
/// Vehicle takes precedence over fuel when both are set, since a vehicle
/// already implies its own fuel.
struct CheapestStationConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configurar widget"
    static var description = IntentDescription(
        "Elige un coche (de los configurados en Ajustes) o un combustible concreto. Si lo dejas vacío, el widget seguirá al coche activo en la app."
    )

    @Parameter(title: "Coche")
    var vehicle: VehicleEntity?

    @Parameter(title: "Combustible")
    var fuel: FuelEntity?
}
