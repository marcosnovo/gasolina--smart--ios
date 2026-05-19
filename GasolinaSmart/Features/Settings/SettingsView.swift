import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(NotificationManager.self) private var notificationManager
    @State private var showVehiclesSheet = false
    @State private var showNavigationSheet = false
    @State private var showMapSheet = false
    @State private var showAppearanceSheet = false
    @State private var showNotificationsSheet = false
    @State private var showCountrySheet = false
    @State private var showLanguageSheet = false
    @State private var showInfoSheet = false
    @State private var showAddVehicle = false
    @State private var editingVehicle: Vehicle?
    private var loc: Loc { preferences.loc }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SettingsCard {
                        vehicleRow
                        SettingsDivider()
                        summaryRow(icon: "location.fill", color: .blue, title: loc.settingsNavigation, value: navigationSummary) {
                            showNavigationSheet = true
                        }
                        SettingsDivider()
                        summaryRow(icon: "map.fill", color: .orange, title: loc.settingsMap, value: mapSummary) {
                            showMapSheet = true
                        }
                    }

                    SettingsCard {
                        summaryRow(icon: "paintbrush.fill", color: .purple, title: loc.settingsAppearance, value: loc.appearanceName(preferences.appearance)) {
                            showAppearanceSheet = true
                        }
                        SettingsDivider()
                        summaryRow(icon: "bell.fill", color: .red, title: loc.settingsNotifications, value: notificationsSummary) {
                            showNotificationsSheet = true
                        }
                    }

                    SettingsCard {
                        countrySummaryRow {
                            showCountrySheet = true
                        }
                        SettingsDivider()
                        summaryRow(icon: "globe.americas.fill", color: .cyan, title: loc.settingsLanguage, value: languageSummary) {
                            showLanguageSheet = true
                        }
                    }

                    SettingsCard {
                        summaryRow(icon: "info.circle.fill", color: .gray, title: loc.settingsInfo, value: loc.settingsOfficialData) {
                            showInfoSheet = true
                        }
                    }

                    appSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(loc.settingsTitle)
            .sheet(isPresented: $showVehiclesSheet) {
                VehiclesSheet(
                    onEdit: { vehicle in
                        showVehiclesSheet = false
                        editingVehicle = vehicle
                    },
                    onAdd: {
                        showVehiclesSheet = false
                        showAddVehicle = true
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showNavigationSheet) {
                NavigationSettingsSheet()
                    .presentationDetents([.height(320)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showMapSheet) {
                MapSettingsSheet()
                    .presentationDetents([.height(340)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAppearanceSheet) {
                AppearanceSheet()
                    .presentationDetents([.height(200)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showNotificationsSheet) {
                NotificationsSheet()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCountrySheet) {
                CountrySheet()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showLanguageSheet) {
                LanguageSheet()
                    .presentationDetents([.height(380)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showInfoSheet) {
                InfoSheet()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAddVehicle) {
                VehicleEditSheet(onSave: { vehicle in
                    preferences.addVehicle(vehicle)
                })
            }
            .sheet(item: $editingVehicle) { vehicle in
                VehicleEditSheet(vehicle: vehicle, onSave: { updated in
                    preferences.selectedVehicle = updated
                })
            }
        }
    }

    // MARK: - Vehicle Row (special layout)

    private var vehicleRow: some View {
        Button { showVehiclesSheet = true } label: {
            HStack(spacing: 12) {
                VehicleAvatar(vehicle: preferences.selectedVehicle, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(preferences.selectedVehicle.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(preferences.selectedFuelType.displayName(for: preferences.selectedCountry))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(.secondaryLabel))
                        if !preferences.selectedVehicle.brand.isEmpty {
                            Text("·")
                                .foregroundStyle(Color(.tertiaryLabel))
                            Text(preferences.selectedVehicle.brand)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                    }
                    .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generic Summary Row

    private func summaryRow(icon: String, color: Color, title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(.label))
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Specialised row for the country setting: renders the active country
    /// as a CountryFlagView instead of an emoji so it matches the rest of
    /// the picker / transition design.
    private func countrySummaryRow(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.green)
                }
                Text(loc.settingsCountry)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(.label))
                Spacer()
                CountryFlagView(country: preferences.selectedCountry, height: 16, cornerRadius: 3)
                Text(preferences.autoDetectCountry
                     ? loc.settingsAutomatic
                     : preferences.selectedCountry.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Summary Values

    private var navigationSummary: String {
        preferences.enabledNavigationApps.map(\.displayName).sorted().joined(separator: ", ")
    }

    private var mapSummary: String {
        var parts = ["\(Int(preferences.preferredRadiusKm)) km"]
        if preferences.showChargingStations {
            parts.append(loc.settingsChargingOn)
        }
        return parts.joined(separator: " · ")
    }

    private var notificationsSummary: String {
        if notificationManager.hasBeenDenied {
            return loc.settingsNotifDisabled
        }
        let count = notificationManager.enabledAlertTypes.count
        return count > 0 ? loc.settingsActiveAlerts(count) : loc.settingsNoAlerts
    }

    private var countrySummary: String {
        if preferences.autoDetectCountry {
            return "\(preferences.selectedCountry.flag) \(loc.settingsAutomatic)"
        }
        return "\(preferences.selectedCountry.flag) \(preferences.selectedCountry.displayName)"
    }

    private var languageSummary: String {
        "\(preferences.appLanguage.flag) \(preferences.appLanguage.displayName)"
    }

    // MARK: - App Footer

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
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, 6)
            .padding(.leading, 42)
    }
}

// MARK: - Vehicles Sheet

private struct VehiclesSheet: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    let onEdit: (Vehicle) -> Void
    let onAdd: () -> Void
    private var loc: Loc { preferences.loc }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
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
                                    Text("\(vehicle.fuelType.displayName(for: preferences.selectedCountry)) · \(Int(vehicle.tankSizeLiters)) L")
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
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                onEdit(vehicle)
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
                    }

                    HStack(spacing: 16) {
                        Button {
                            if let vehicle = preferences.vehicles.first(where: { $0.id == preferences.selectedVehicleId }) {
                                onEdit(vehicle)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(loc.edit)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(Theme.Colors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.Colors.accent.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            onAdd()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(loc.settingsAddVehicle)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(Theme.Colors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.Colors.accent.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(loc.settingsVehicles)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc.close) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Navigation Settings Sheet

private struct NavigationSettingsSheet: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    private var loc: Loc { preferences.loc }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ForEach(PreferredNavigationApp.allCases, id: \.self) { app in
                    let isEnabled = preferences.enabledNavigationApps.contains(app)
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: app.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.blue)
                        }
                        Text(app.displayName)
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
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
                        Divider().padding(.leading, 40)
                    }
                }

                Text(preferences.enabledNavigationApps.count == 1
                     ? loc.settingsNavSingle
                     : loc.settingsNavMultiple)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .navigationTitle(loc.settingsNavigation)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc.close) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Map Settings Sheet

private struct MapSettingsSheet: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    private var loc: Loc { preferences.loc }
    @State private var sliderValue: Double = 5

    var body: some View {
        @Bindable var prefs = preferences
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Text("\(Int(sliderValue)) km")
                        .font(Theme.Fonts.priceLarge)
                        .contentTransition(.numericText(value: sliderValue))
                        .animation(.snappy(duration: 0.2), value: sliderValue)

                    Slider(value: $sliderValue, in: 1...50, step: 1)
                        .tint(Theme.Colors.accent)

                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(UserPreferences.availableRadii, id: \.self) { radius in
                            Button {
                                withAnimation(.snappy(duration: 0.2)) { sliderValue = radius }
                            } label: {
                                Text("\(Int(radius))")
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Int(sliderValue) == Int(radius) ? Theme.Colors.accent : Color(.tertiarySystemFill))
                                    .foregroundStyle(Int(sliderValue) == Int(radius) ? .white : Color(.label))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Theme.Colors.charging.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: "bolt.car.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.Colors.charging)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(loc.settingsCharging)
                            .font(.system(size: 15, weight: .medium))
                        Text(loc.settingsChargingFooter)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(.tertiaryLabel))
                            .lineLimit(2)
                    }
                    Spacer()
                    Toggle("", isOn: $prefs.showChargingStations)
                        .tint(Theme.Colors.charging)
                        .labelsHidden()
                }
            }
            .padding(20)
            .navigationTitle(loc.settingsMap)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc.mapApply) {
                        preferences.preferredRadiusKm = sliderValue
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
            }
            .onAppear { sliderValue = preferences.preferredRadiusKm }
        }
    }
}

// MARK: - Appearance Sheet

private struct AppearanceSheet: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    private var loc: Loc { preferences.loc }

    var body: some View {
        @Bindable var prefs = preferences
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    ForEach(AppAppearance.allCases, id: \.self) { option in
                        let isSelected = preferences.appearance == option
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                preferences.appearance = option
                            }
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(appearanceFill(option))
                                        .frame(height: 56)
                                    Image(systemName: appearanceIcon(option))
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundStyle(isSelected ? Theme.Colors.accent : Color(.secondaryLabel))
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(isSelected ? Theme.Colors.accent : .clear, lineWidth: 2)
                                )
                                Text(loc.appearanceName(option))
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                    .foregroundStyle(isSelected ? Theme.Colors.accent : Color(.secondaryLabel))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .navigationTitle(loc.settingsAppearance)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc.close) { dismiss() }
                }
            }
        }
    }

    private func appearanceIcon(_ option: AppAppearance) -> String {
        switch option {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    private func appearanceFill(_ option: AppAppearance) -> Color {
        switch option {
        case .system: Color(.tertiarySystemFill)
        case .light: Color(.systemGray6)
        case .dark: Color(.systemGray3)
        }
    }
}

// MARK: - Notifications Sheet

private struct NotificationsSheet: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(\.dismiss) private var dismiss
    private var loc: Loc { preferences.loc }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if notificationManager.hasBeenDenied {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc.settingsNotifDisabled)
                                .font(.system(size: 15, weight: .semibold))
                            Text(loc.settingsNotifOpenSystem)
                                .font(.system(size: 13))
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
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.Colors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(AlertType.allCases, id: \.rawValue) { alertType in
                        HStack(spacing: 12) {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 13))
                                .foregroundStyle(.red)
                                .frame(width: 28)
                            Text(loc.alertTypeName(alertType))
                                .font(.system(size: 15, weight: .medium))
                            Spacer()
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

                        if alertType != AlertType.allCases.last {
                            Divider().padding(.leading, 40)
                        }
                    }
                }

                Text(loc.settingsNotifFooter)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .navigationTitle(loc.settingsNotifications)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc.close) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Country Sheet (Citymapper-style picker)

private struct CountrySheet: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    private var loc: Loc { preferences.loc }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Hero header — sets the tone before the cards.
                    VStack(alignment: .leading, spacing: 6) {
                        Text(loc.countryPickerHeader)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(loc.countryPickerSubheader)
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabel))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    autoDetectCard

                    ForEach(Country.allCases) { country in
                        countryCard(country)
                    }

                    Text(loc.settingsCountryFooter)
                        .font(.footnote)
                        .foregroundStyle(Color(.tertiaryLabel))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(loc.settingsCountry)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc.close) { dismiss() }
                }
            }
        }
    }

    private var autoDetectCard: some View {
        Button {
            preferences.autoDetectCountry = true
            dismiss()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accent.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: "location.fill.viewfinder")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.countryPickerAuto)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(.label))
                    Text(loc.settingsAutoCountryFooter)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.secondaryLabel))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                if preferences.autoDetectCountry {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        preferences.autoDetectCountry ? Theme.Colors.accent.opacity(0.45) : .clear,
                        lineWidth: 2
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(CountryCardButtonStyle())
    }

    private func countryCard(_ country: Country) -> some View {
        let isActive = preferences.selectedCountry == country && !preferences.autoDetectCountry
        return Button {
            preferences.autoDetectCountry = false
            let didChange = preferences.selectedCountry != country
            preferences.selectedCountry = country
            dismiss()
            // Fire the welcome-to-X overlay only when the picker
            // actually changed the active country.
            if didChange {
                appState.countryTransition = country
            }
        } label: {
            HStack(spacing: 14) {
                CountryFlagView(country: country, height: 36, cornerRadius: 6)
                    .frame(width: 54, height: 52, alignment: .center)

                VStack(alignment: .leading, spacing: 4) {
                    Text(country.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(.label))

                    HStack(spacing: 6) {
                        Image(systemName: country.hasFuelData ? "fuelpump.fill" : "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(country.hasFuelData
                             ? loc.countryBadgeFuelCharging
                             : loc.countryBadgeChargingOnly)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(country.hasFuelData ? Theme.Colors.accent : Theme.Colors.charging)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (country.hasFuelData ? Theme.Colors.accent : Theme.Colors.charging)
                            .opacity(0.12)
                    )
                    .clipShape(Capsule())

                    Text(loc.freshnessText(country.dataFreshness))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                }

                Spacer(minLength: 8)
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isActive ? Theme.Colors.accent.opacity(0.45) : .clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(CountryCardButtonStyle())
    }
}

private struct CountryCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Language Sheet

private struct LanguageSheet: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    private var loc: Loc { preferences.loc }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
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
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Text(loc.settingsLanguageFooter)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(loc.settingsLanguage)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc.close) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Info Sheet

private struct InfoSheet: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    private var loc: Loc { preferences.loc }

    var body: some View {
        let country = preferences.selectedCountry
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    infoRow(icon: "building.columns.fill", label: loc.settingsDataSource, value: "\(country.flag) \(country.displayName)")
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        attributionView(for: country)
                    }
                    Divider()

                    infoRow(icon: "arrow.clockwise", label: loc.settingsUpdate, value: loc.freshnessText(country.dataFreshness))
                    Divider()

                    infoRow(icon: "bolt.fill", label: loc.settingsChargingSource, value: "OpenStreetMap")
                    Divider()

                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        Text(loc.settingsPrivacy)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(loc.settingsInfo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc.close) { dismiss() }
                }
            }
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))
                .frame(width: 28)
            Text(label)
                .font(.system(size: 14, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))
        }
    }

    @ViewBuilder
    private func attributionView(for country: Country) -> some View {
        switch country {
        case .germany:
            VStack(alignment: .leading, spacing: 4) {
                Text("Spritpreis-Daten von ")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
                +
                Text("Tankerkönig")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.blue)
                +
                Text(", lizenziert unter ")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
                +
                Text("CC BY 4.0")
                    .font(.system(size: 12, weight: .semibold))
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
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
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
    @State private var hasGLP: Bool
    @State private var isElectric: Bool
    @State private var batteryCapacityKWh: Double
    @State private var preferredConnectors: Set<String>
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
        _hasGLP = State(initialValue: v.hasGLP)
        _isElectric = State(initialValue: v.isElectric)
        _batteryCapacityKWh = State(initialValue: v.batteryCapacityKWh ?? 50)
        _preferredConnectors = State(initialValue: v.preferredConnectors.isEmpty ? ["CCS", "Type 2"] : v.preferredConnectors)
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
                engineTypeSection
                if isElectric {
                    batterySection
                    connectorsSection
                } else {
                    fuelSection
                    tankSection
                    consumptionSection
                }
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
        Vehicle(name: name, brand: brand, fuelType: fuelType, hasGLP: hasGLP,
                isElectric: isElectric,
                batteryCapacityKWh: isElectric ? batteryCapacityKWh : nil,
                preferredConnectors: isElectric ? preferredConnectors : [],
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

    private var engineTypeSection: some View {
        Section(loc.vehicleEngineType) {
            Picker("", selection: $isElectric) {
                Text(loc.vehicleEngineCombustion).tag(false)
                Text(loc.vehicleEngineElectric).tag(true)
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    private var batterySection: some View {
        Section {
            HStack {
                Text(loc.vehicleBatteryCapacity)
                Spacer()
                TextField("kWh", value: $batteryCapacityKWh, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("kWh")
                    .foregroundStyle(Color(.secondaryLabel))
            }
        } header: {
            Text(loc.vehicleBatteryCapacity)
        } footer: {
            Text(loc.vehicleBatteryCapacityHint)
        }
    }

    private var connectorsSection: some View {
        Section {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                spacing: 10
            ) {
                ForEach(Self.connectorOptions, id: \.shortName) { conn in
                    let isSelected = preferredConnectors.contains(conn.shortName)
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            if isSelected {
                                preferredConnectors.remove(conn.shortName)
                            } else {
                                preferredConnectors.insert(conn.shortName)
                            }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: conn.symbol)
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(isSelected ? conn.color : Color(.secondaryLabel))
                            Text(conn.shortName)
                                .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                                .foregroundStyle(isSelected ? conn.color : Color(.label))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isSelected ? conn.color.opacity(0.12) : Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? conn.color : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)
        } header: {
            Text(loc.vehicleConnectors)
        } footer: {
            Text(loc.vehicleConnectorsHint)
        }
    }

    private struct ConnectorOption {
        let shortName: String
        let symbol: String
        let color: Color
    }

    private static let connectorOptions: [ConnectorOption] = [
        .init(shortName: "CCS", symbol: "ev.plug.dc.ccs2", color: Color(red: 0.20, green: 0.45, blue: 0.85)),
        .init(shortName: "CHAdeMO", symbol: "ev.plug.dc.chademo", color: Color(red: 0.85, green: 0.45, blue: 0.10)),
        // bolt.car.fill renders on all iOS versions; the ev.plug.ac.* symbols
        // didn't render in our tests on iOS 17.x devices.
        .init(shortName: "Type 2", symbol: "bolt.car.fill", color: Color(red: 0.10, green: 0.55, blue: 0.20)),
        .init(shortName: "Type 1", symbol: "bolt.car.fill", color: Color(red: 0.60, green: 0.30, blue: 0.70)),
        .init(shortName: "NACS", symbol: "ev.plug.dc.nacs", color: Color(red: 0.80, green: 0.20, blue: 0.20)),
        .init(shortName: "Schuko", symbol: "powerplug.fill", color: Color(.secondaryLabel)),
    ]

    private var pickablePrimaryFuels: [FuelType] {
        // GLP is handled by the separate toggle; the picker is exclusively for
        // gasoline / diesel options.
        var fuels = preferences.selectedCountry.supportedFuelTypes.filter { $0 != .glp }
        // Make sure the currently selected fuel is always visible (e.g. when
        // editing a vehicle whose primary fuel isn't normally listed in the
        // active country).
        if !fuels.contains(fuelType), fuelType != .glp {
            fuels.insert(fuelType, at: 0)
        }
        return fuels
    }

    private var fuelSection: some View {
        Section(loc.fuel) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                spacing: 10
            ) {
                ForEach(pickablePrimaryFuels) { fuel in
                    let isSelected = fuelType == fuel
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { fuelType = fuel }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: fuel.icon)
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(isSelected ? Theme.Colors.accent : Color(.secondaryLabel))
                            Text(fuel.displayName(for: preferences.selectedCountry))
                                .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                                .foregroundStyle(isSelected ? Theme.Colors.accent : Color(.label))
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            isSelected
                                ? Theme.Colors.accent.opacity(0.12)
                                : Color(.tertiarySystemFill)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? Theme.Colors.accent : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)

            Toggle(isOn: $hasGLP) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.vehicleHasGLP)
                        .font(.system(size: 15))
                    Text(loc.vehicleHasGLPHint)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .tint(Theme.Colors.accent)
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
            hasGLP: hasGLP,
            isElectric: isElectric,
            batteryCapacityKWh: isElectric ? batteryCapacityKWh : nil,
            preferredConnectors: isElectric ? preferredConnectors : [],
            tankSizeLiters: tankSize,
            consumptionL100Km: consumptionL100Km,
            vehicleType: vehicleType,
            vehicleColor: vehicleColor
        )
        onSave(vehicle)
    }
}
