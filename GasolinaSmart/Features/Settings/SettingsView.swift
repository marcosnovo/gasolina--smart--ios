import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(NotificationManager.self) private var notificationManager
    @State private var showAddVehicle = false
    @State private var editingVehicle: Vehicle?

    var body: some View {
        NavigationStack {
            Form {
                vehiclesSection
                appearanceSection
                navigationSection
                searchSection
                notificationsSection
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
                    HStack(spacing: 12) {
                        VehicleAvatar(vehicle: vehicle, size: 42)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(vehicle.name)
                                    .font(.headline)
                                if !vehicle.brand.isEmpty {
                                    Text("· \(vehicle.brand)")
                                        .font(.subheadline)
                                        .foregroundStyle(Color(.secondaryLabel))
                                }
                            }
                            Text("\(vehicle.fuelType.displayName) · \(Int(vehicle.tankSizeLiters)) L")
                                .font(.caption)
                                .foregroundStyle(Color(.secondaryLabel))
                        }

                        Spacer()

                        if preferences.selectedVehicleId == vehicle.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Colors.accent)
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
                    .foregroundStyle(Theme.Colors.accent)
            }
        } header: {
            Text("Mis vehículos")
        } footer: {
            Text("El vehículo seleccionado determina el combustible del mapa.")
        }
    }

    private var appearanceSection: some View {
        @Bindable var prefs = preferences
        return Section("Apariencia") {
            Picker("Tema", selection: $prefs.appearance) {
                ForEach(AppAppearance.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var navigationSection: some View {
        Section {
            ForEach(PreferredNavigationApp.allCases, id: \.self) { app in
                Button {
                    preferences.preferredNavigationApp = app
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: app.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Theme.Colors.accent)
                            .frame(width: 28)
                        Text(app.displayName)
                            .foregroundStyle(Color(.label))
                        Spacer()
                        if preferences.preferredNavigationApp == app {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Theme.Colors.accent)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Navegación")
        } footer: {
            Text("Servicio de navegación para el widget y accesos directos.")
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

    private var notificationsSection: some View {
        Section {
            if notificationManager.hasBeenDenied {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notificaciones desactivadas")
                            .font(.subheadline)
                        Text("Actívalas en Ajustes del sistema.")
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                } icon: {
                    Image(systemName: "bell.slash")
                        .foregroundStyle(.orange)
                }
                Button("Abrir Ajustes") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.subheadline)
            } else {
                if !notificationManager.isAuthorized {
                    Button {
                        Task { await notificationManager.requestAuthorization() }
                    } label: {
                        Label("Activar notificaciones", systemImage: "bell.badge")
                    }
                }

                ForEach(AlertType.allCases, id: \.rawValue) { alertType in
                    Toggle(isOn: Binding(
                        get: { notificationManager.isAlertEnabled(alertType) },
                        set: { _ in
                            if !notificationManager.isAuthorized {
                                Task { await notificationManager.requestAuthorization() }
                            }
                            notificationManager.toggleAlertType(alertType)
                        }
                    )) {
                        Text(alertType.displayName)
                            .font(.subheadline)
                    }
                    .tint(Theme.Colors.accent)
                }
            }
        } header: {
            Text("Notificaciones")
        } footer: {
            Text("Recibe alertas cuando los precios cambien según tus preferencias.")
        }
    }

    private var infoSection: some View {
        Section("Información") {
            HStack {
                Text("Fuente de datos")
                Spacer()
                Text("Ministerio de Industria")
                    .foregroundStyle(Color(.secondaryLabel))
            }
            HStack {
                Text("Actualización")
                Spacer()
                Text("Cada 30 minutos")
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
    }

    private var privacySection: some View {
        Section("Privacidad") {
            Label {
                Text("Tu ubicación se usa solo en el dispositivo. No se comparte ni almacena.")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.blue)
            }
        }
    }

    private var appSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 2) {
                    Text("Gasolina Smart")
                        .font(.headline)
                    Text("v1.0")
                        .font(.caption)
                        .foregroundStyle(Color(.tertiaryLabel))
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
    @State private var brand: String
    @State private var fuelType: FuelType
    @State private var tankSize: Double
    @State private var consumptionL100Km: Double
    @State private var vehicleType: VehicleType
    @State private var vehicleColor: VehicleColor
    @State private var brandSuggestions: [String] = []
    private let isEditing: Bool
    private let onSave: (Vehicle) -> Void
    private let vehicleId: UUID?

    init(vehicle: Vehicle? = nil, onSave: @escaping (Vehicle) -> Void) {
        let v = vehicle ?? .defaultVehicle
        _name = State(initialValue: vehicle?.name ?? "")
        _brand = State(initialValue: vehicle?.brand ?? "")
        _fuelType = State(initialValue: v.fuelType)
        _tankSize = State(initialValue: v.tankSizeLiters)
        _consumptionL100Km = State(initialValue: v.consumptionL100Km)
        _vehicleType = State(initialValue: v.vehicleType)
        _vehicleColor = State(initialValue: v.vehicleColor)
        self.isEditing = vehicle != nil
        self.onSave = onSave
        self.vehicleId = vehicle?.id
    }

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                nameSection
                brandSection
                typeSection
                colorSection
                fuelSection
                tankSection
                consumptionSection
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
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var previewVehicle: Vehicle {
        Vehicle(name: name, brand: brand, fuelType: fuelType,
                tankSizeLiters: tankSize, consumptionL100Km: consumptionL100Km,
                vehicleType: vehicleType, vehicleColor: vehicleColor)
    }

    private var previewSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    VehicleAvatar(vehicle: previewVehicle, size: 80)

                    if !name.isEmpty || !brand.isEmpty {
                        VStack(spacing: 2) {
                            if !name.isEmpty {
                                Text(name)
                                    .font(.headline)
                            }
                            if !brand.isEmpty {
                                Text(brand)
                                    .font(.subheadline)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }
                        }
                    }
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
            .padding(.vertical, 8)
        }
    }

    private var nameSection: some View {
        Section("Nombre") {
            TextField("Ej: Mi coche", text: $name)
        }
    }

    private var brandSection: some View {
        Section("Marca") {
            TextField("Ej: Toyota, Seat...", text: $brand)
                .onChange(of: brand) { _, newValue in
                    updateBrandSuggestions(newValue)
                }
            if !brandSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(brandSuggestions, id: \.self) { suggestion in
                            Button {
                                brand = suggestion
                                brandSuggestions = []
                            } label: {
                                Text(suggestion)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.tertiarySystemFill))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
            }
        }
    }

    private var typeSection: some View {
        Section("Tipo de vehículo") {
            HStack(spacing: 12) {
                ForEach(VehicleType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            let wasDefault = consumptionL100Km == Vehicle.defaultConsumption(for: vehicleType)
                            vehicleType = type
                            if wasDefault || !isEditing {
                                consumptionL100Km = Vehicle.defaultConsumption(for: type)
                            }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.system(size: 20, weight: .medium))
                                .frame(width: 44, height: 44)
                                .background(
                                    vehicleType == type
                                        ? Theme.Colors.accent.opacity(0.15)
                                        : Color(.tertiarySystemFill)
                                )
                                .foregroundStyle(
                                    vehicleType == type
                                        ? Theme.Colors.accent
                                        : Color(.secondaryLabel)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(vehicleType == type ? Theme.Colors.accent : .clear, lineWidth: 2)
                                )
                            Text(type.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(vehicleType == type ? Theme.Colors.accent : Color(.secondaryLabel))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    private var colorSection: some View {
        Section("Color") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(VehicleColor.allCases, id: \.self) { vc in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { vehicleColor = vc }
                    } label: {
                        Circle()
                            .fill(vc.color)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(vehicleColor == vc ? Color(.label) : .clear, lineWidth: 2.5)
                                    .padding(-3)
                            )
                            .overlay(
                                vehicleColor == vc
                                    ? Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(vc == .white || vc == .yellow ? .black : .white)
                                    : nil
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var fuelSection: some View {
        Section("Combustible") {
            ForEach(FuelType.allCases) { fuel in
                Button {
                    fuelType = fuel
                } label: {
                    HStack {
                        Image(systemName: fuel.icon)
                            .frame(width: 24)
                            .foregroundStyle(Theme.Colors.accent)
                        Text(fuel.displayName)
                        Spacer()
                        if fuelType == fuel {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Theme.Colors.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var tankSection: some View {
        Section("Depósito") {
            HStack {
                Text("Tamaño")
                Spacer()
                TextField("Litros", value: $tankSize, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("L")
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
    }

    private var consumptionSection: some View {
        Section {
            HStack {
                Text("Consumo medio")
                Spacer()
                TextField("L/100km", value: $consumptionL100Km, format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("L/100km")
                    .foregroundStyle(Color(.secondaryLabel))
            }
        } header: {
            Text("Consumo")
        } footer: {
            Text("Se usa para calcular el coste real por kilómetro.")
        }
    }

    private func updateBrandSuggestions(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.count >= 1 else {
            brandSuggestions = []
            return
        }
        brandSuggestions = Vehicle.commonBrands
            .filter { $0.lowercased().hasPrefix(trimmed) && $0.lowercased() != trimmed }
            .prefix(4)
            .map { $0 }
    }

    private func saveVehicle() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let finalName = trimmedName.isEmpty ? "Mi coche" : trimmedName
        let trimmedBrand = brand.trimmingCharacters(in: .whitespaces)

        let vehicle = Vehicle(
            id: vehicleId ?? UUID(),
            name: finalName,
            brand: trimmedBrand,
            fuelType: fuelType,
            tankSizeLiters: tankSize,
            consumptionL100Km: consumptionL100Km,
            vehicleType: vehicleType,
            vehicleColor: vehicleColor
        )
        onSave(vehicle)
    }
}
