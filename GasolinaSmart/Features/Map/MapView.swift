import SwiftUI
import CoreLocation

struct MapView: View {
    @Environment(StationStore.self) private var store
    @Environment(UserPreferences.self) private var preferences
    @Environment(LocationManager.self) private var locationManager
    @Environment(AppState.self) private var appState
    @Environment(ChargingStationStore.self) private var chargingStore

    private var loc: Loc { preferences.loc }

    @State private var showRadiusPicker = false
    @State private var showVehicleMenu = false
    @State private var showAddVehicle = false
    @State private var editingVehicle: Vehicle?

    @State private var visibleStations: [FuelStation] = []
    @State private var visibleChargingStations: [ChargingStation] = []
    @State private var cachedCheapest: FuelStation?
    @State private var cachedAveragePrice: Decimal?

    @State private var centerOnUserCounter = 0
    @State private var zoomRadiusCounter = 0
    @State private var showNavigationPicker = false
    @State private var initialLoadComplete = false
    @State private var selectedChargingStation: ChargingStation?
    @State private var showStationList = false

    var body: some View {
        ZStack {
            MapLibreMapView(
                stations: visibleStations,
                cheapestId: cachedCheapest?.id,
                favoriteIds: preferences.favoriteStationIds,
                onStationTapped: { station in
                    appState.selectedStation = station
                    appState.showStationDetail = true
                },
                chargingStations: visibleChargingStations,
                onChargingStationTapped: { station in
                    selectedChargingStation = station
                },
                centerOnUserCounter: centerOnUserCounter,
                zoomRadiusKm: preferences.preferredRadiusKm,
                zoomRadiusCounter: zoomRadiusCounter,
                isDarkMode: preferences.appearance == .dark,
                selectedFuelType: preferences.selectedFuelType,
                cheapestPrice: cachedCheapest?.price(for: preferences.selectedFuelType)
            )
            .ignoresSafeArea()
            .opacity(initialLoadComplete ? 1 : 0)

            if !initialLoadComplete {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text(loc.mapLoading)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }

            VStack(spacing: 0) {
                topBar
                    .padding(.top, Theme.Spacing.xs)

                if isLoadingAnyStations && initialLoadComplete {
                    loadingPill
                        .padding(.top, Theme.Spacing.sm)
                }

                Spacer()

                if let error = store.error, store.allStations.isEmpty {
                    errorBar(error)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.bottom, Theme.Spacing.sm)
                }

                bottomContent
            }

            VStack {
                HStack {
                    Spacer()
                    mapActionButtons
                        .padding(.trailing, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.sm)
                }
                Spacer()
            }
            .padding(.top, 58)
            .allowsHitTesting(true)

            if !locationManager.isAuthorized && !store.isLoading && store.allStations.isEmpty {
                noLocationOverlay
            }
        }
        .task {
            await store.loadCacheImmediately()
            updateVisibleStations()
            locationManager.requestLocation()
            await store.loadStations(
                near: locationManager.location,
                radiusKm: preferences.preferredRadiusKm
            )
            if preferences.showChargingStations, let location = locationManager.location {
                await chargingStore.loadStations(near: location, radiusKm: preferences.preferredRadiusKm)
                updateChargingStations()
            }
        }
        .onChange(of: locationManager.location) { _, newLocation in
            updateVisibleStations()
            markReadyIfNeeded()
            if let newLocation {
                if preferences.autoDetectCountry,
                   let detected = Country.detect(from: newLocation.coordinate),
                   detected != preferences.selectedCountry {
                    preferences.selectedCountry = detected
                }
                Task {
                    await store.loadStations(
                        near: newLocation,
                        radiusKm: preferences.preferredRadiusKm
                    )
                    if preferences.showChargingStations {
                        await chargingStore.loadStations(near: newLocation, radiusKm: preferences.preferredRadiusKm)
                        updateChargingStations()
                    }
                }
            }
        }
        .onChange(of: store.allStations) { _, _ in
            updateVisibleStations()
            markReadyIfNeeded()
        }
        .onChange(of: preferences.preferredRadiusKm) { _, _ in
            updateVisibleStations()
            updateChargingStations()
            zoomRadiusCounter += 1
            Task {
                await store.reloadIfNeeded(
                    location: locationManager.location,
                    radiusKm: preferences.preferredRadiusKm
                )
                if preferences.showChargingStations, let location = locationManager.location {
                    await chargingStore.loadStations(near: location, radiusKm: preferences.preferredRadiusKm)
                    updateChargingStations()
                }
            }
        }
        .onChange(of: preferences.selectedFuelType) { _, _ in
            updateVisibleStations()
        }
        .onChange(of: chargingStore.stations) { _, _ in
            updateChargingStations()
        }
        .onChange(of: preferences.showChargingStations) { _, showCharging in
            if showCharging, let location = locationManager.location {
                Task {
                    await chargingStore.loadStations(near: location, radiusKm: preferences.preferredRadiusKm)
                    updateChargingStations()
                }
            } else {
                visibleChargingStations = []
            }
        }
        .onChange(of: preferences.selectedCountry) { _, newCountry in
            store.switchCountry(newCountry)
            visibleStations = []
            cachedCheapest = nil
            cachedAveragePrice = nil
            if let location = locationManager.location {
                Task {
                    await store.loadStations(
                        near: location,
                        radiusKm: preferences.preferredRadiusKm
                    )
                }
            }
        }
        .onChange(of: preferences.enabledNavigationApps) { _, _ in
            if let location = locationManager.location {
                updateWidgetData(location: location)
            }
        }
        .sheet(isPresented: Binding(
            get: { appState.showStationDetail && appState.selectedStation != nil },
            set: { if !$0 { appState.showStationDetail = false } }
        )) {
            if let station = appState.selectedStation {
                StationDetailView(station: station)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showRadiusPicker) {
            RadiusPickerSheet()
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
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
        .sheet(isPresented: $showNavigationPicker) {
            if let cheapest = cachedCheapest {
                let apps = preferences.enabledNavigationApps.isEmpty
                    ? Set(PreferredNavigationApp.allCases)
                    : preferences.enabledNavigationApps
                NavigationPickerSheet(station: cheapest, availableApps: apps)
                    .presentationDetents([.height(180)])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(item: $selectedChargingStation) { station in
            ChargingStationDetailView(station: station)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStationList) {
            StationListSheet(
                stations: visibleStations,
                userLocation: locationManager.location,
                fuelType: preferences.selectedFuelType,
                country: preferences.selectedCountry,
                cheapestPrice: cachedCheapest?.price(for: preferences.selectedFuelType),
                averagePrice: cachedAveragePrice,
                radiusKm: preferences.preferredRadiusKm,
                favoriteIds: preferences.favoriteStationIds,
                onStationTapped: { station in
                    showStationList = false
                    appState.selectedStation = station
                    appState.showStationDetail = true
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showVehicleMenu) {
            VehicleSwitcherSheet(
                onSelectVehicle: { vehicle in
                    preferences.selectedVehicleId = vehicle.id
                    showVehicleMenu = false
                },
                onEditVehicle: {
                    editingVehicle = preferences.selectedVehicle
                    showVehicleMenu = false
                },
                onAddVehicle: {
                    showAddVehicle = true
                    showVehicleMenu = false
                }
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { showVehicleMenu = true } label: {
                HStack(spacing: 8) {
                    VehicleAvatar(vehicle: preferences.selectedVehicle, size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preferences.selectedVehicle.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundStyle(Color(.label))
                        Text(preferences.selectedFuelType.shortLabel(for: preferences.selectedCountry))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(.secondaryLabel))
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(.secondaryLabel))
                        .fixedSize()
                }
                .padding(.trailing, 14)
                .padding(.leading, 10)
                .padding(.vertical, 8)
                .background(topBarCapsuleBackground)
                .overlay(topBarOutline)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .layoutPriority(1)

            Spacer(minLength: 12)

            Button { showRadiusPicker = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "scope")
                        .font(.system(size: 13, weight: .medium))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(loc.mapRadius.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(.secondaryLabel))
                        Text("\(Int(preferences.preferredRadiusKm)) km")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(.label))
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(topBarCapsuleBackground)
                .overlay(topBarOutline)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .frame(width: 126, alignment: .leading)

        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    private var mapActionButtons: some View {
        VStack(spacing: 10) {
            Button {
                centerOnUserCounter += 1
                locationManager.requestLocation()
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(width: 44, height: 44)
                    .background(topBarCircleBackground)
                    .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
            }
            .buttonStyle(.plain)

            Button {
                showStationList = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(width: 44, height: 44)
                    .background(topBarCircleBackground)
                    .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
        }
    }

    private var topBarCapsuleBackground: some ShapeStyle {
        Color(.systemBackground)
    }

    private var topBarCircleBackground: some ShapeStyle {
        Color(.systemBackground)
    }

    private var topBarOutline: some View {
        Capsule()
            .stroke(Color.black.opacity(0.08), lineWidth: 1)
    }

    // MARK: - Bottom

    private var bottomContent: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if let cheapest = cachedCheapest,
               let location = locationManager.location {
                RadarPanel(
                    station: cheapest,
                    fuelType: preferences.selectedFuelType,
                    averagePrice: cachedAveragePrice,
                    tankLiters: preferences.tankSizeLiters,
                    distance: cheapest.distanceKm(from: location),
                    onTap: {
                        appState.selectedStation = cheapest
                        appState.showStationDetail = true
                    },
                    onNavigate: {
                        if preferences.enabledNavigationApps.count == 1,
                           let app = preferences.enabledNavigationApps.first {
                            NavigationHelper.openPreferred(station: cheapest, app: app)
                        } else {
                            showNavigationPicker = true
                        }
                    }
                )
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                .padding(.horizontal, Theme.Spacing.md)
            } else if locationManager.isAuthorized && locationManager.location != nil
                        && !store.allStations.isEmpty && visibleStations.isEmpty {
                VStack(spacing: 4) {
                    Text(loc.mapNoStations(Int(preferences.preferredRadiusKm)))
                        .font(Theme.Fonts.subheadline)
                        .fontWeight(.medium)
                    Text(loc.mapExpandRadius)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
                .padding(.horizontal, Theme.Spacing.md)
            }

            freshnessLabel
                .padding(.bottom, Theme.Spacing.sm)
        }
    }

    private var loadingPill: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(loc.mapLoadingStations)
                .font(Theme.Fonts.pillLabel)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.3), value: isLoadingAnyStations)
    }

    private var freshnessLabel: some View {
        HStack(spacing: 4) {
            if store.isUsingCache {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 9))
            }
            Text(store.dataFreshnessText(loc: loc))
                .font(Theme.Fonts.caption)
            if !visibleStations.isEmpty {
                Text("· \(visibleStations.count) \(loc.stations)")
                    .font(Theme.Fonts.caption)
            }
            if !visibleChargingStations.isEmpty {
                Text("· \(visibleChargingStations.count) \(loc.chargers)")
                    .font(Theme.Fonts.caption)
            }
        }
        .foregroundStyle(Color(.tertiaryLabel))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.regularMaterial)
        .clipShape(Capsule())
    }

    private func errorBar(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.orange)
            Text(loc.mapLoadError)
                .font(Theme.Fonts.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button(loc.mapRetry) {
                Task { await store.loadStations(near: locationManager.location) }
            }
            .font(Theme.Fonts.pillLabel)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private var noLocationOverlay: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text(loc.mapNoLocation)
                .font(Theme.Fonts.headline)
            Text(loc.mapEnableLocation)
                .font(Theme.Fonts.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                if locationManager.hasBeenDenied {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } else {
                    locationManager.requestPermission()
                }
            } label: {
                Text(locationManager.hasBeenDenied ? loc.mapOpenSettings : loc.mapEnableLocationAction)
                    .font(Theme.Fonts.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.accent)

            Button { appState.selectedTab = .search } label: {
                Text(loc.mapSearchByCity)
                    .font(Theme.Fonts.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: 280)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    // MARK: - Helpers

    private var isLoadingAnyStations: Bool {
        store.isLoading || (preferences.showChargingStations && chargingStore.isLoading)
    }

    private func markReadyIfNeeded() {
        guard !initialLoadComplete else { return }
        if locationManager.location != nil, !store.allStations.isEmpty {
            withAnimation(.easeIn(duration: 0.3)) {
                initialLoadComplete = true
            }
        }
    }

    private func updateVisibleStations() {
        guard let location = locationManager.location else {
            visibleStations = []
            cachedCheapest = nil
            cachedAveragePrice = nil
            return
        }
        let summary = store.nearbySummary(
            location: location,
            radiusKm: preferences.preferredRadiusKm,
            fuelType: preferences.selectedFuelType,
            limit: 100
        )
        visibleStations = summary.visibleStations
        cachedCheapest = summary.cheapestStation
        cachedAveragePrice = summary.averagePrice

        updateWidgetData(location: location)
        recordPriceHistory()
        resolvePendingDeepLink()
    }

    private func updateWidgetData(location: CLLocation) {
        guard let cheapest = cachedCheapest else { return }
        let navURL = NavigationHelper.navigationURL(
            latitude: cheapest.latitude,
            longitude: cheapest.longitude,
            app: preferences.preferredNavigationApp
        )
        WidgetDataProvider.update(
            cheapestStation: cheapest,
            fuelType: preferences.selectedFuelType,
            country: preferences.selectedCountry,
            averagePrice: cachedAveragePrice,
            tankLiters: preferences.tankSizeLiters,
            userLocation: location,
            vehicle: preferences.selectedVehicle,
            radiusKm: preferences.preferredRadiusKm,
            stationCount: visibleStations.count,
            isDarkMode: preferences.appearance == .dark,
            navigationURLString: navURL.absoluteString
        )
    }

    private func recordPriceHistory() {
        guard let cheapest = cachedCheapest,
              let avg = cachedAveragePrice,
              let cheapestPrice = cheapest.price(for: preferences.selectedFuelType) else { return }
        Task {
            await PriceHistoryStore.shared.record(
                country: preferences.selectedCountry,
                fuelType: preferences.selectedFuelType,
                radiusKm: preferences.preferredRadiusKm,
                cheapest: cheapestPrice,
                average: avg,
                stationCount: visibleStations.count
            )
        }
    }

    private func updateChargingStations() {
        guard preferences.showChargingStations, let location = locationManager.location else {
            visibleChargingStations = []
            return
        }
        visibleChargingStations = chargingStore.nearbyStations(
            location: location,
            radiusKm: preferences.preferredRadiusKm
        )
    }

    private func resolvePendingDeepLink() {
        guard let pendingId = appState.pendingStationId else { return }
        if let station = store.allStations.first(where: { $0.id == pendingId }) {
            appState.pendingStationId = nil
            appState.selectedStation = station
            appState.showStationDetail = true
        }
    }

}

private struct VehicleSwitcherSheet: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss

    let onSelectVehicle: (Vehicle) -> Void
    let onEditVehicle: () -> Void
    let onAddVehicle: () -> Void

    private var loc: Loc { preferences.loc }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(preferences.selectedVehicle.name)
                            .font(.title2.weight(.bold))
                        Text(preferences.selectedFuelType.displayName(for: preferences.selectedCountry))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 10) {
                        ForEach(preferences.vehicles) { vehicle in
                            Button {
                                onSelectVehicle(vehicle)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    VehicleAvatar(vehicle: vehicle, size: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(vehicle.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(Color(.label))
                                        Text(vehicle.fuelType.displayName(for: preferences.selectedCountry))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color(.secondaryLabel))
                                    }
                                    Spacer()
                                    if preferences.selectedVehicleId == vehicle.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Theme.Colors.accent)
                                    }
                                }
                                .padding(14)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(spacing: 10) {
                        Button {
                            onEditVehicle()
                            dismiss()
                        } label: {
                            actionRow(icon: "pencil", title: loc.edit)
                        }
                        .buttonStyle(.plain)

                        Button {
                            onAddVehicle()
                            dismiss()
                        } label: {
                            actionRow(icon: "plus.circle", title: loc.settingsAddVehicle)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle(preferences.selectedVehicle.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc.close) { dismiss() }
                }
            }
        }
    }

    private func actionRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Colors.accent)
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Radius Picker Sheet

struct RadiusPickerSheet: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss

    private var loc: Loc { preferences.loc }

    @State private var sliderValue: Double = 5

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack {
                Text(loc.mapSearchRadius)
                    .font(Theme.Fonts.headline)
                Spacer()
                Button(loc.mapApply) {
                    preferences.preferredRadiusKm = sliderValue
                    dismiss()
                }
                .font(Theme.Fonts.pillLabel)
            }

            Text("\(Int(sliderValue)) km")
                .font(Theme.Fonts.priceLarge)
                .contentTransition(.numericText(value: sliderValue))
                .animation(.snappy(duration: 0.2), value: sliderValue)

            Slider(value: $sliderValue, in: 1...50, step: 1) {
                Text(loc.mapRadius)
            } minimumValueLabel: {
                Text("1").font(Theme.Fonts.caption).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("50").font(Theme.Fonts.caption).foregroundStyle(.secondary)
            }
            .tint(Theme.Colors.accent)

            HStack(spacing: Theme.Spacing.sm) {
                ForEach(UserPreferences.availableRadii, id: \.self) { radius in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            sliderValue = radius
                        }
                    } label: {
                        Text("\(Int(radius))")
                            .font(Theme.Fonts.pillLabel)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                Int(sliderValue) == Int(radius)
                                    ? Theme.Colors.accent
                                    : Color(.tertiarySystemFill)
                            )
                            .foregroundStyle(
                                Int(sliderValue) == Int(radius)
                                    ? .white
                                    : Color(.label)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .onAppear {
            sliderValue = preferences.preferredRadiusKm
        }
    }
}

// MARK: - Station List Sheet

private struct StationListSheet: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss

    let stations: [FuelStation]
    let userLocation: CLLocation?
    let fuelType: FuelType
    let country: Country
    let cheapestPrice: Decimal?
    let averagePrice: Decimal?
    let radiusKm: Double
    let favoriteIds: Set<String>
    let onStationTapped: (FuelStation) -> Void

    @State private var selectedTab: SortTab = .recommended

    private var loc: Loc { preferences.loc }

    enum SortTab: String, CaseIterable, Hashable {
        case recommended
        case price
        case distance
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(loc.listResultsInRadius(sortedStations.count, Int(radiusKm)))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                    .padding(.bottom, 10)

                Picker("", selection: $selectedTab) {
                    Text(loc.listRecommended).tag(SortTab.recommended)
                    Text(loc.listPrice).tag(SortTab.price)
                    Text(loc.listDistance).tag(SortTab.distance)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                if sortedStations.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "fuelpump.slash")
                            .font(.system(size: 32))
                            .foregroundStyle(Color(.tertiaryLabel))
                        Text(loc.mapNoStations(Int(radiusKm)))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(sortedStations) { station in
                                Button {
                                    onStationTapped(station)
                                } label: {
                                    StationListRow(
                                        station: station,
                                        rank: rank(of: station),
                                        distance: distance(for: station),
                                        price: station.price(for: fuelType),
                                        priceQuality: priceQuality(for: station),
                                        isFavorite: favoriteIds.contains(station.id),
                                        country: country,
                                        fuelType: fuelType
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(loc.listTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc.close) { dismiss() }
                }
            }
        }
    }

    private var sortedStations: [FuelStation] {
        let withPrice = stations.filter { $0.price(for: fuelType) != nil }
        switch selectedTab {
        case .price:
            return withPrice.sorted { a, b in
                let pa = a.price(for: fuelType) ?? .greatestFiniteMagnitude
                let pb = b.price(for: fuelType) ?? .greatestFiniteMagnitude
                return pa < pb
            }
        case .distance:
            guard let location = userLocation else { return withPrice }
            return withPrice.sorted { a, b in
                a.distance(from: location) < b.distance(from: location)
            }
        case .recommended:
            guard let location = userLocation else {
                return withPrice.sorted { a, b in
                    let pa = a.price(for: fuelType) ?? .greatestFiniteMagnitude
                    let pb = b.price(for: fuelType) ?? .greatestFiniteMagnitude
                    return pa < pb
                }
            }
            return withPrice.sorted { a, b in
                totalCost(for: a, location: location) < totalCost(for: b, location: location)
            }
        }
    }

    private func totalCost(for station: FuelStation, location: CLLocation) -> Double {
        guard let price = station.price(for: fuelType), price > 0 else { return .greatestFiniteMagnitude }
        let priceDouble = NSDecimalNumber(decimal: price).doubleValue
        let tankLiters = preferences.tankSizeLiters
        let consumption = preferences.consumptionL100Km
        let distanceKm = station.distanceKm(from: location)
        let fillCost = priceDouble * tankLiters
        let detourCost = distanceKm * 2 * (consumption / 100) * priceDouble
        return fillCost + detourCost
    }

    private func rank(of station: FuelStation) -> Int {
        sortedStations.firstIndex(where: { $0.id == station.id }).map { $0 + 1 } ?? 0
    }

    private func distance(for station: FuelStation) -> Double? {
        guard let location = userLocation else { return nil }
        return station.distanceKm(from: location)
    }

    private func priceQuality(for station: FuelStation) -> PriceQuality {
        guard let price = station.price(for: fuelType) else { return .unknown }
        if let cheapest = cheapestPrice {
            let ratio = NSDecimalNumber(decimal: price / cheapest).doubleValue
            if ratio <= 1.02 { return .good }
        }
        if let average = averagePrice {
            let ratio = NSDecimalNumber(decimal: price / average).doubleValue
            if ratio >= 1.03 { return .bad }
        }
        return .normal
    }
}

private enum PriceQuality {
    case good
    case normal
    case bad
    case unknown

    var color: Color {
        switch self {
        case .good: Color(red: 0.10, green: 0.55, blue: 0.20)
        case .normal: Color(.label)
        case .bad: Color(red: 0.85, green: 0.40, blue: 0.10)
        case .unknown: Color(.secondaryLabel)
        }
    }

    var backgroundColor: Color {
        switch self {
        case .good: Color(red: 0.86, green: 0.96, blue: 0.88)
        case .normal: Color(.tertiarySystemFill)
        case .bad: Color(red: 0.99, green: 0.92, blue: 0.85)
        case .unknown: Color(.tertiarySystemFill)
        }
    }
}

private struct StationListRow: View {
    let station: FuelStation
    let rank: Int
    let distance: Double?
    let price: Decimal?
    let priceQuality: PriceQuality
    let isFavorite: Bool
    let country: Country
    let fuelType: FuelType

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(rank == 1 ? Theme.Colors.accent : Color(.tertiarySystemFill))
                    .frame(width: 28, height: 28)
                Text("\(rank)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(rank == 1 ? .white : Color(.label))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(station.brand.isEmpty ? station.name : station.brand)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(Color(.label))
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.0))
                    }
                }
                HStack(spacing: 6) {
                    if let distance {
                        Text(distance.distanceFormatted)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    if !station.address.isEmpty {
                        Text("·")
                            .foregroundStyle(Color(.tertiaryLabel))
                        Text(station.address)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(.tertiaryLabel))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(price?.priceFormatted ?? "—")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(priceQuality.color)
                Text(fuelType.unit(for: country))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(priceQuality.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
