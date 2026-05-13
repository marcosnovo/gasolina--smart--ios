import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(NotificationManager.self) private var notificationManager
    @State private var showAddVehicle = false
    @State private var editingVehicle: Vehicle?
    private var loc: Loc { preferences.loc }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    countrySection
                    languageSection
                    vehiclesSection
                    mapSection
                    navigationSection
                    appearanceSection
                    notificationsSection
                    infoSection
                    appSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(loc.settingsTitle)
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

    // MARK: - Country

    private var countrySection: some View {
        SettingsCard {
            SettingsSectionHeader(icon: "globe", title: loc.settingsCountry, color: .green)

            ForEach(Country.allCases) { country in
                let isSelected = preferences.selectedCountry == country
                Button {
                    preferences.selectedCountry = country
                } label: {
                    HStack(spacing: 12) {
                        Text(country.flag)
                            .font(.system(size: 24))
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(country.displayName)
                                .font(.system(size: 15, weight: .semibold))
                            Text(loc.freshnessText(country.dataFreshness))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if country != Country.allCases.last {
                    Divider().padding(.leading, 44)
                }
            }

            Text(loc.settingsCountryFooter)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
                .padding(.top, 4)
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        @Bindable var prefs = preferences
        return SettingsCard {
            SettingsSectionHeader(icon: "globe.americas.fill", title: loc.settingsLanguage, color: .cyan)

            ForEach(AppLanguage.allCases) { language in
                let isSelected = preferences.appLanguage == language
                Button {
                    preferences.appLanguage = language
                } label: {
                    HStack(spacing: 12) {
                        Text(language.flag)
                            .font(.system(size: 24))
                            .frame(width: 28)
                        Text(language.displayName)
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.cyan)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if language != AppLanguage.allCases.last {
                    Divider().padding(.leading, 44)
                }
            }

            Text(loc.settingsLanguageFooter)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
                .padding(.top, 4)
        }
    }

    // MARK: - Vehicles

    private var vehiclesSection: some View {
        SettingsCard {
            SettingsSectionHeader(icon: "car.fill", title: loc.settingsVehicles, color: Theme.Colors.accent)

            ForEach(preferences.vehicles) { vehicle in
                let isSelected = preferences.selectedVehicleId == vehicle.id
                Button {
                    preferences.selectedVehicleId = vehicle.id
                } label: {
                    HStack(spacing: 12) {
                        VehicleAvatar(vehicle: vehicle, size: 42)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(vehicle.name)
                                    .font(.system(size: 15, weight: .semibold))
                                if !vehicle.brand.isEmpty {
                                    Text("· \(vehicle.brand)")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(.secondaryLabel))
                                }
                            }
                            Text("\(vehicle.fuelType.displayName(for: preferences.selectedCountry)) · \(Int(vehicle.tankSizeLiters)) L · \(String(format: "%.1f", vehicle.consumptionL100Km)) L/100km")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Theme.Colors.accent)
                        }
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        editingVehicle = vehicle
                    } label: {
                        Label(loc.edit, systemImage: "pencil")
                    }
                    if preferences.vehicles.count > 1 {
                        Button(role: .destructive) {
                            preferences.removeVehicle(vehicle)
                        } label: {
                            Label(loc.delete, systemImage: "trash")
                        }
                    }
                }

                if vehicle.id != preferences.vehicles.last?.id {
                    Divider()
                        .padding(.leading, 54)
                }
            }

            Button {
                showAddVehicle = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text(loc.settingsAddVehicle)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Theme.Colors.accent)
                .padding(.top, 4)
            }
            .buttonStyle(.plain)

            Text(loc.settingsVehicleFooter)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
                .padding(.top, 4)
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        @Bindable var prefs = preferences
        return SettingsCard {
            SettingsSectionHeader(icon: "map.fill", title: loc.settingsMap, color: .orange)

            SettingsRow(icon: "scope", label: loc.settingsSearchRadius, color: .orange) {
                Picker("", selection: $prefs.preferredRadiusKm) {
                    ForEach(UserPreferences.availableRadii, id: \.self) { radius in
                        Text("\(Int(radius)) km").tag(radius)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color(.label))
            }

            Divider().padding(.leading, 44)

            SettingsRow(icon: "bolt.car.fill", label: loc.settingsCharging, color: Theme.Colors.charging) {
                Toggle("", isOn: $prefs.showChargingStations)
                    .tint(Theme.Colors.charging)
                    .labelsHidden()
            }

            Text(loc.settingsChargingFooter)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
                .padding(.top, 4)
        }
    }

    // MARK: - Navigation

    private var navigationSection: some View {
        SettingsCard {
            SettingsSectionHeader(icon: "location.fill", title: loc.settingsNavigation, color: .blue)

            ForEach(PreferredNavigationApp.allCases, id: \.self) { app in
                let isEnabled = preferences.enabledNavigationApps.contains(app)
                SettingsRow(icon: app.icon, label: app.displayName, color: .blue) {
                    Toggle("", isOn: Binding(
                        get: { isEnabled },
                        set: { newValue in
                            if newValue {
                                preferences.enabledNavigationApps.insert(app)
                            } else if preferences.enabledNavigationApps.count > 1 {
                                preferences.enabledNavigationApps.remove(app)
                            }
                        }
                    ))
                    .tint(Theme.Colors.accent)
                    .labelsHidden()
                }

                if app != PreferredNavigationApp.allCases.last {
                    Divider().padding(.leading, 44)
                }
            }

            Text(preferences.enabledNavigationApps.count == 1
                 ? loc.settingsNavSingle
                 : loc.settingsNavMultiple)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
                .padding(.top, 4)
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        @Bindable var prefs = preferences
        return SettingsCard {
            SettingsSectionHeader(icon: "paintbrush.fill", title: loc.settingsAppearance, color: .purple)

            Picker(loc.settingsTheme, selection: $prefs.appearance) {
                ForEach(AppAppearance.allCases, id: \.self) { option in
                    Text(loc.appearanceName(option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        SettingsCard {
            SettingsSectionHeader(icon: "bell.fill", title: loc.settingsNotifications, color: .red)

            if notificationManager.hasBeenDenied {
                HStack(spacing: 12) {
                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.orange)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.settingsNotifDisabled)
                            .font(.system(size: 14, weight: .semibold))
                        Text(loc.settingsNotifOpenSystem)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    Spacer()
                    Button(loc.settingsOpen) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.orange)
                    .clipShape(Capsule())
                }
            } else {
                if !notificationManager.isAuthorized {
                    Button {
                        Task { await notificationManager.requestAuthorization() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 14))
                            Text(loc.settingsNotifEnable)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Theme.Colors.accent)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(AlertType.allCases, id: \.rawValue) { alertType in
                    SettingsRow(icon: "bell.badge", label: loc.alertTypeName(alertType), color: .red) {
                        Toggle("", isOn: Binding(
                            get: { notificationManager.isAlertEnabled(alertType) },
                            set: { _ in
                                if !notificationManager.isAuthorized {
                                    Task { await notificationManager.requestAuthorization() }
                                }
                                notificationManager.toggleAlertType(alertType)
                            }
                        ))
                        .tint(Theme.Colors.accent)
                        .labelsHidden()
                    }
                }
            }

            Text(loc.settingsNotifFooter)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
                .padding(.top, 4)
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        let country = preferences.selectedCountry
        return SettingsCard {
            SettingsSectionHeader(icon: "info.circle.fill", title: loc.settingsInfo, color: .gray)

            SettingsRow(icon: "building.columns.fill", label: loc.settingsDataSource, color: .gray) {
                Text(country.flag)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            attributionView(for: country)
                .padding(.leading, 44)

            Divider().padding(.leading, 44)

            SettingsRow(icon: "arrow.clockwise", label: loc.settingsUpdate, color: .gray) {
                Text(loc.freshnessText(country.dataFreshness))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Divider().padding(.leading, 44)

            SettingsRow(icon: "bolt.fill", label: loc.settingsChargingSource, color: Theme.Colors.charging) {
                Text("OpenStreetMap")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Divider().padding(.leading, 44)

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                }
                Text(loc.settingsPrivacy)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func attributionView(for country: Country) -> some View {
        switch country {
        case .germany:
            VStack(alignment: .leading, spacing: 4) {
                Text("Spritpreis-Daten von ")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
                +
                Text("Tankerkönig")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.blue)
                +
                Text(", lizenziert unter ")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
                +
                Text("CC BY 4.0")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.blue)

                HStack(spacing: 12) {
                    Button {
                        if let url = URL(string: "https://creativecommons.tankerkoenig.de") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Tankerkönig", systemImage: "link")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    Button {
                        if let url = URL(string: "https://creativecommons.org/licenses/by/4.0/") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("CC BY 4.0", systemImage: "link")
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
            }
        default:
            Text(country.attributionText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
        }
    }

    // MARK: - App

    private var appSection: some View {
        VStack(spacing: 4) {
            Text("Gasolina Smart")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(.secondaryLabel))
            Text("v1.0")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Settings Card

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Section Header

private struct SettingsSectionHeader: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.system(size: 16, weight: .bold))
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Settings Row

private struct SettingsRow<Trailing: View>: View {
    let icon: String
    let label: String
    let color: Color
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 14, weight: .medium))
            Spacer()
            trailing
        }
    }
}

// MARK: - Vehicle Edit Sheet

struct VehicleEditSheet: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    private var loc: Loc { preferences.loc }
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
            .navigationTitle(isEditing ? loc.vehicleEdit : loc.vehicleNew)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.save) {
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
            VStack(spacing: 8) {
                Vehicle3DView(
                    vehicleType: vehicleType,
                    vehicleColor: vehicleColor,
                    height: 240
                )

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
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .padding(.vertical, 4)
        }
    }

    private var nameSection: some View {
        Section(loc.name) {
            TextField(loc.namePlaceholder, text: $name)
        }
    }

    private var brandSection: some View {
        Section(loc.brand) {
            TextField(loc.brandPlaceholder, text: $brand)
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
        Section(loc.vehicleType) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(VehicleType.allCases, id: \.self) { type in
                        let isSelected = vehicleType == type
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
                                    .font(.system(size: 22, weight: .medium))
                                    .frame(width: 60, height: 60)
                                    .background(
                                        isSelected
                                            ? Theme.Colors.accent.opacity(0.15)
                                            : Color(.tertiarySystemFill)
                                    )
                                    .foregroundStyle(
                                        isSelected ? Theme.Colors.accent : Color(.secondaryLabel)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(isSelected ? Theme.Colors.accent : .clear, lineWidth: 2)
                                    )
                                Text(loc.vehicleTypeName(type))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(isSelected ? Theme.Colors.accent : Color(.secondaryLabel))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var colorSection: some View {
        Section(loc.color) {
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
        Section(loc.fuel) {
            ForEach(preferences.selectedCountry.supportedFuelTypes) { fuel in
                Button {
                    fuelType = fuel
                } label: {
                    HStack {
                        Image(systemName: fuel.icon)
                            .frame(width: 24)
                            .foregroundStyle(Theme.Colors.accent)
                        Text(fuel.displayName(for: preferences.selectedCountry))
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
        Section(loc.tank) {
            HStack {
                Text(loc.tankSize)
                Spacer()
                TextField(loc.liters, value: $tankSize, format: .number)
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
                Text(loc.avgConsumption)
                Spacer()
                TextField("L/100km", value: $consumptionL100Km, format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("L/100km")
                    .foregroundStyle(Color(.secondaryLabel))
            }
        } header: {
            Text(loc.consumption)
        } footer: {
            Text(loc.consumptionFooter)
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
