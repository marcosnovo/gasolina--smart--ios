import SwiftUI

struct SettingsView: View {
    @Environment(UserPreferences.self) private var preferences
    @State private var showAddVehicle = false
    @State private var editingVehicle: Vehicle?

    var body: some View {
        NavigationStack {
            Form {
                vehiclesSection
                searchSection
                infoSection
                privacySection
                appSection
            }
            .navigationTitle("Ajustes")
            .sheet(isPresented: $showAddVehicle) {
                VehicleEditSheet(
                    onSave: { vehicle in
                        preferences.addVehicle(vehicle)
                    }
                )
            }
            .sheet(item: $editingVehicle) { vehicle in
                VehicleEditSheet(
                    vehicle: vehicle,
                    onSave: { updated in
                        preferences.selectedVehicle = updated
                    }
                )
            }
        }
    }

    private var vehiclesSection: some View {
        Section {
            ForEach(preferences.vehicles) { vehicle in
                Button {
                    preferences.selectedVehicleId = vehicle.id
                } label: {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: vehicle.fuelType.icon)
                            .font(.title3)
                            .foregroundStyle(.tint)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(vehicle.name)
                                .font(Theme.Fonts.headline)
                                .foregroundStyle(Theme.Colors.label)
                            Text("\(vehicle.fuelType.displayName) · \(Int(vehicle.tankSizeLiters)) L")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.secondaryLabel)
                        }

                        Spacer()

                        if preferences.selectedVehicleId == vehicle.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    if preferences.vehicles.count > 1 {
                        Button(role: .destructive) {
                            preferences.removeVehicle(vehicle)
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                    Button {
                        editingVehicle = vehicle
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }

            Button {
                showAddVehicle = true
            } label: {
                Label("Añadir vehículo", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Mis vehículos")
        } footer: {
            Text("El vehículo seleccionado determina el tipo de combustible que se muestra en el mapa.")
        }
    }

    private var searchSection: some View {
        @Bindable var prefs = preferences
        return Section("Búsqueda") {
            Picker("Radio de búsqueda", selection: $prefs.preferredRadiusKm) {
                ForEach(UserPreferences.availableRadii, id: \.self) { radius in
                    Text("\(Int(radius)) km").tag(radius)
                }
            }
        }
    }

    private var infoSection: some View {
        Section("Información") {
            HStack {
                Text("Fuente de datos")
                Spacer()
                Text("Ministerio de Industria")
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }

            HStack {
                Text("Frecuencia de actualización")
                Spacer()
                Text("Cada 30 minutos")
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
        }
    }

    private var privacySection: some View {
        Section("Privacidad") {
            Label {
                Text("Tu ubicación se usa solo localmente para encontrar gasolineras cercanas. No se comparte ni se almacena en ningún servidor.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.tint)
            }
        }
    }

    private var appSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("Gasolina Smart")
                        .font(Theme.Fonts.headline)
                    Text("v1.0")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.tertiaryLabel)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Vehicle Edit Sheet

struct VehicleEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var fuelType: FuelType
    @State private var tankSize: Double
    private let isEditing: Bool
    private let onSave: (Vehicle) -> Void
    private let vehicleId: UUID?

    init(vehicle: Vehicle? = nil, onSave: @escaping (Vehicle) -> Void) {
        let v = vehicle ?? .defaultVehicle
        _name = State(initialValue: vehicle?.name ?? "")
        _fuelType = State(initialValue: v.fuelType)
        _tankSize = State(initialValue: v.tankSizeLiters)
        self.isEditing = vehicle != nil
        self.onSave = onSave
        self.vehicleId = vehicle?.id
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Ej: Mi coche, Coche de trabajo", text: $name)
                }

                Section("Combustible") {
                    ForEach(FuelType.allCases) { fuel in
                        Button {
                            fuelType = fuel
                        } label: {
                            HStack {
                                Image(systemName: fuel.icon)
                                    .frame(width: 24)
                                    .foregroundStyle(.tint)
                                Text(fuel.displayName)
                                    .foregroundStyle(Theme.Colors.label)
                                Spacer()
                                if fuelType == fuel {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }

                Section("Depósito") {
                    HStack {
                        Text("Tamaño del depósito")
                        Spacer()
                        TextField("Litros", value: $tankSize, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("L")
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar vehículo" : "Nuevo vehículo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveVehicle()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func saveVehicle() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let finalName = trimmedName.isEmpty ? "Mi coche" : trimmedName
        var vehicle = Vehicle(name: finalName, fuelType: fuelType, tankSizeLiters: tankSize)
        if let existingId = vehicleId {
            vehicle = Vehicle(id: existingId, name: finalName, fuelType: fuelType, tankSizeLiters: tankSize)
        }
        onSave(vehicle)
    }
}
