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
    @State private var cheapestPriceByFuel: [FuelType: Decimal] = [:]
    @State private var displayedFuelByStation: [String: FuelType] = [:]

    @State private var centerOnUserCounter = 0
    @State private var zoomRadiusCounter = 0
    @State private var showNavigationPicker = false
    @State private var initialLoadComplete = false
    @State private var selectedChargingStation: ChargingStation?
    @State private var showStationList = false
    @State private var pendingArea: VisibleMapArea?
    @State private var isAreaMode = false
    @State private var cachedChargingSummary: ChargingStationStore.ChargingSummary?

    // Last location for which we ran `updateVisibleStations`. Used to skip
    // redundant filter passes — CoreLocation can deliver several updates a
    // few metres apart while the GPS settles, and re-running the full 11k+
    // station summary for sub-50m moves is pure churn.
    @State private var lastSummarizedLocation: CLLocation?

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
                cheapestPriceByFuel: cheapestPriceByFuel,
                displayedFuelByStation: displayedFuelByStation,
                onUserMovedMap: { area in
                    pendingArea = area
                },
                suppressCameraFit: isAreaMode
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

                if let pendingArea, initialLoadComplete {
                    searchInAreaButton(area: pendingArea)
                        .padding(.top, Theme.Spacing.sm)
                        .transition(.opacity.combined(with: .move(edge: .top)))
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
            // Full-country snapshot — covers the whole map, so panning
            // anywhere has data without needing more fetches.
            await store.loadAllCountryStations()
            if preferences.effectiveShowChargingStations {
                await chargingStore.loadAllCountryStations(country: preferences.selectedCountry)
                updateChargingStations()
                updateChargingSummary()
            }
        }
        .onChange(of: locationManager.location) { _, newLocation in
            markReadyIfNeeded()
            guard let newLocation else { return }

            // Skip the heavy summary recomputation when the user hasn't really
            // moved — CoreLocation can deliver several updates a few metres
            // apart while the GPS settles. 50 m gives the radar enough
            // resolution without thrashing.
            let movedFarEnough = lastSummarizedLocation
                .map { $0.distance(from: newLocation) > 50 } ?? true
            if movedFarEnough {
                lastSummarizedLocation = newLocation
                updateVisibleStations()
                updateChargingSummary()
            }

            if preferences.autoDetectCountry,
               let detected = Country.detect(from: newLocation.coordinate),
               detected != preferences.selectedCountry {
                preferences.selectedCountry = detected
            }
            if preferences.effectiveShowChargingStations {
                Task {
                    await chargingStore.loadAllCountryStations(country: preferences.selectedCountry)
                    updateChargingStations()
                }
            }
        }
        .onChange(of: store.allStations) { _, _ in
            updateVisibleStations()
            markReadyIfNeeded()
        }
        .onChange(of: preferences.preferredRadiusKm) { _, _ in
            exitAreaMode()
            updateVisibleStations()
            updateChargingStations()
            updateChargingSummary()
            zoomRadiusCounter += 1
        }
        .onChange(of: preferences.selectedFuelType) { _, _ in
            exitAreaMode()
            updateVisibleStations()
        }
        .onChange(of: preferences.selectedVehicleId) { _, _ in
            handleVehicleSwitch()
        }
        .onChange(of: preferences.selectedVehicle.isElectric) { _, _ in
            // Switching engine type changes which dataset drives the map
            // (fuel stations vs charging points). Refresh both layers and
            // the radar cache.
            handleVehicleSwitch()
        }
        .onChange(of: preferences.selectedVehicle.preferredConnectors) { _, _ in
            // Connector preferences feed the charging-station filter.
            updateChargingStations()
            updateChargingSummary()
        }
        .onChange(of: chargingStore.stations) { _, _ in
            updateChargingStations()
            updateChargingSummary()
        }
        .onChange(of: preferences.effectiveShowChargingStations) { _, showCharging in
            if showCharging {
                Task {
                    await chargingStore.loadAllCountryStations(country: preferences.selectedCountry)
                    updateChargingStations()
                }
            } else {
                visibleChargingStations = []
            }
        }
        .onChange(of: preferences.selectedCountry) { _, newCountry in
            isAreaMode = false
            pendingArea = nil
            store.switchCountry(newCountry)
            visibleStations = []
            cachedCheapest = nil
            cachedAveragePrice = nil
            visibleChargingStations = []
            cachedChargingSummary = nil
            Task {
                await store.loadAllCountryStations()
                if preferences.effectiveShowChargingStations {
                    // Charging snapshot is country-scoped too; reload for the
                    // new country and refresh the EV radar.
                    await chargingStore.loadAllCountryStations(country: newCountry, force: true)
                    updateChargingStations()
                    updateChargingSummary()
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
            if preferences.selectedVehicle.isElectric {
                ChargingListSheet(
                    stations: chargingNearbyForList,
                    userLocation: locationManager.location,
                    radiusKm: preferences.preferredRadiusKm,
                    onStationTapped: { station in
                        showStationList = false
                        selectedChargingStation = station
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            } else {
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

    // MARK: - List sheet helpers

    private var chargingNearbyForList: [ChargingStation] {
        guard let location = locationManager.location else { return visibleChargingStations }
        // When in area mode we already filtered chargingStore to the visible
        // rectangle; otherwise pull a fresh nearby slice up to 200 stations.
        if isAreaMode { return visibleChargingStations }
        return chargingStore.nearbyStations(
            location: location,
            radiusKm: preferences.preferredRadiusKm,
            limit: 200,
            connectorFilter: preferences.selectedVehicle.preferredConnectors
        )
    }

    // MARK: - Vehicle Pill

    private var isDualFuelVehicle: Bool {
        preferences.vehicleSupportedFuels.count > 1
    }

    private var vehiclePill: some View {
        HStack(spacing: 0) {
            // Left zone — vehicle picker.
            Button { showVehicleMenu = true } label: {
                HStack(spacing: 8) {
                    VehicleAvatar(vehicle: preferences.selectedVehicle, size: 28)
                    Text(preferences.selectedVehicle.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(Color(.label))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(.secondaryLabel))
                        .fixedSize()
                }
                .padding(.leading, 10)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Right zone — fuel chip / EV badge.
            // - Combustion mono-fuel: shows the fuel code, no action.
            // - Combustion dual-fuel: shows the active fuel + swap icon;
            //   tapping cycles GLP ↔ Gasoline.
            // - Electric: shows a bolt + "EV" label; no fuel selection.
            if preferences.selectedVehicle.isElectric {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("EV")
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.Colors.charging)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.Colors.charging.opacity(0.14))
                .clipShape(Capsule())
                .padding(.trailing, 6)
            } else {
                Button {
                    guard isDualFuelVehicle else { return }
                    cycleVisibleFuel()
                } label: {
                    HStack(spacing: 4) {
                        Text(preferences.selectedFuelType.shortLabel(for: preferences.selectedCountry))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Colors.accent)
                            .lineLimit(1)
                        if isDualFuelVehicle {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.Colors.accent)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.accent.opacity(isDualFuelVehicle ? 0.14 : 0.08))
                    .clipShape(Capsule())
                    .padding(.trailing, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isDualFuelVehicle)
            }
        }
        .background(topBarCapsuleBackground)
        .overlay(topBarOutline)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
    }

    private func cycleVisibleFuel() {
        let fuels = preferences.vehicleSupportedFuels
        guard fuels.count > 1,
              let currentIndex = fuels.firstIndex(of: preferences.selectedFuelType) else {
            return
        }
        let next = fuels[(currentIndex + 1) % fuels.count]
        withAnimation(.snappy(duration: 0.2)) {
            preferences.selectedFuelType = next
        }
        updateVisibleStations()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 10) {
            vehiclePill
                .layoutPriority(1)

            Spacer(minLength: 12)

            Button { showRadiusPicker = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "dot.circle")
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
                exitAreaMode()
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

    // MARK: - Search in this area

    private func searchInAreaButton(area: VisibleMapArea) -> some View {
        Button {
            applyAreaSearch(area)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                Text(loc.mapSearchThisArea)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Theme.Colors.accent)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func applyAreaSearch(_ area: VisibleMapArea) {
        // The store holds the full country, so this is an in-memory filter.
        // No network call, no spinner — feels instant.
        if preferences.selectedVehicle.isElectric {
            let summary = chargingStore.areaSummary(
                minLatitude: area.minLatitude,
                maxLatitude: area.maxLatitude,
                minLongitude: area.minLongitude,
                maxLongitude: area.maxLongitude,
                limit: 30,
                connectorFilter: preferences.selectedVehicle.preferredConnectors
            )
            visibleStations = []
            cachedCheapest = nil
            cachedAveragePrice = nil
            cheapestPriceByFuel = [:]
            displayedFuelByStation = [:]
            visibleChargingStations = summary.visibleStations
        } else {
            let summary = store.areaSummary(
                minLatitude: area.minLatitude,
                maxLatitude: area.maxLatitude,
                minLongitude: area.minLongitude,
                maxLongitude: area.maxLongitude,
                fuelTypes: Set(preferences.vehicleSupportedFuels),
                primaryFuel: preferences.selectedFuelType,
                limit: 30
            )
            visibleStations = summary.visibleStations
            cachedCheapest = summary.cheapestStation
            cachedAveragePrice = summary.averagePrice
            cheapestPriceByFuel = summary.cheapestPriceByFuel
            displayedFuelByStation = summary.displayedFuelByStation
        }
        isAreaMode = true
        withAnimation(.easeInOut(duration: 0.2)) {
            pendingArea = nil
        }
    }

    private func exitAreaMode() {
        guard isAreaMode else { return }
        isAreaMode = false
        pendingArea = nil
        updateVisibleStations()
    }

    // MARK: - Bottom

    private var bottomContent: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if preferences.selectedVehicle.isElectric {
                electricBottomContent
            } else {
                combustionBottomContent
            }

            freshnessLabel
                .padding(.bottom, Theme.Spacing.sm)
        }
    }

    @ViewBuilder
    private var combustionBottomContent: some View {
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
    }

    @ViewBuilder
    private var electricBottomContent: some View {
        // Reads pre-computed summary — keeps the body cheap. The summary is
        // refreshed in updateChargingSummary() whenever its inputs change
        // (location, radius, charging-store contents, vehicle connectors).
        if let location = locationManager.location,
           let summary = cachedChargingSummary,
           let cheapest = summary.cheapestStation {
            ChargingRadarPanel(
                station: cheapest,
                averagePricePerKWh: summary.averagePricePerKWh,
                distance: cheapest.distanceKm(from: location),
                onTap: { selectedChargingStation = cheapest },
                onNavigate: {
                    if preferences.enabledNavigationApps.count == 1,
                       let app = preferences.enabledNavigationApps.first {
                        NavigationHelper.openCharging(station: cheapest, app: app)
                    } else {
                        NavigationHelper.openCharging(station: cheapest, app: .appleMaps)
                    }
                }
            )
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .padding(.horizontal, Theme.Spacing.md)
        }
    }

    /// Re-syncs every layer after the active vehicle changes (different
    /// vehicle picked, or current vehicle's engine type edited). Fixes the
    /// stale-map bug where switching between two cars that happen to share
    /// the same `fuelType` (e.g. an EV with default gasolina95 + a real G95
    /// car) wouldn't trigger selectedFuelType.didChange.
    private func handleVehicleSwitch() {
        exitAreaMode()
        updateVisibleStations()
        if preferences.effectiveShowChargingStations {
            // Make sure the snapshot for this country is loaded; the store
            // will short-circuit if we already have fresh data.
            Task {
                await chargingStore.loadAllCountryStations(country: preferences.selectedCountry)
                updateChargingStations()
                updateChargingSummary()
            }
        } else {
            // Combustion vehicle: drop any stale charging overlays.
            visibleChargingStations = []
            cachedChargingSummary = nil
        }
    }

    private func updateChargingSummary() {
        guard preferences.selectedVehicle.isElectric,
              let location = locationManager.location else {
            cachedChargingSummary = nil
            return
        }
        cachedChargingSummary = chargingStore.nearbySummary(
            location: location,
            radiusKm: preferences.preferredRadiusKm,
            limit: 200,
            connectorFilter: preferences.selectedVehicle.preferredConnectors
        )
        // Keep the home-screen widget in sync with the EV radar card.
        updateWidgetData(location: location)
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
        store.isLoading || (preferences.effectiveShowChargingStations && chargingStore.isLoading)
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
        // While the user is exploring a custom area via "Search this area",
        // ignore the auto-refresh that re-centers around the user's location.
        guard !isAreaMode else { return }

        guard let location = locationManager.location else {
            visibleStations = []
            cachedCheapest = nil
            cachedAveragePrice = nil
            cheapestPriceByFuel = [:]
            displayedFuelByStation = [:]
            return
        }
        let summary = store.nearbySummary(
            location: location,
            radiusKm: preferences.preferredRadiusKm,
            fuelTypes: Set(preferences.vehicleSupportedFuels),
            primaryFuel: preferences.selectedFuelType,
            limit: 100
        )
        visibleStations = summary.visibleStations
        cachedCheapest = summary.cheapestStation
        cachedAveragePrice = summary.averagePrice
        cheapestPriceByFuel = summary.cheapestPriceByFuel
        displayedFuelByStation = summary.displayedFuelByStation

        updateWidgetData(location: location)
        recordPriceHistory()
        resolvePendingDeepLink()
    }

    private func updateWidgetData(location: CLLocation) {
        if preferences.selectedVehicle.isElectric {
            // EV path: push the cheapest charging point into the same widget
            // slot so users get a consistent "tap to navigate" experience
            // regardless of vehicle type.
            guard let cheapest = cachedChargingSummary?.cheapestStation else { return }
            let navURL = NavigationHelper.navigationURL(
                latitude: cheapest.latitude,
                longitude: cheapest.longitude,
                app: preferences.preferredNavigationApp
            )
            WidgetDataProvider.updateForCharging(
                cheapest: cheapest,
                averagePricePerKWh: cachedChargingSummary?.averagePricePerKWh,
                batteryCapacityKWh: preferences.selectedVehicle.batteryCapacityKWh,
                userLocation: location,
                vehicle: preferences.selectedVehicle,
                radiusKm: preferences.preferredRadiusKm,
                stationCount: visibleChargingStations.count,
                isDarkMode: preferences.appearance == .dark,
                navigationURLString: navURL.absoluteString
            )
            return
        }

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
        // When the user is exploring via "Search this area" on an EV, their
        // chosen rectangle is authoritative — don't snap back to the radius.
        if isAreaMode, preferences.selectedVehicle.isElectric { return }

        guard preferences.effectiveShowChargingStations, let location = locationManager.location else {
            visibleChargingStations = []
            return
        }
        // For EVs we filter by the connector types the vehicle accepts so the
        // map doesn't clutter with incompatible plugs. Charging-stations with
        // no connector info are still shown — better to over-include than
        // hide a possibly-compatible station.
        let connectorFilter = preferences.selectedVehicle.isElectric
            ? preferences.selectedVehicle.preferredConnectors
            : []
        visibleChargingStations = chargingStore.nearbyStations(
            location: location,
            radiusKm: preferences.preferredRadiusKm,
            connectorFilter: connectorFilter
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
    // Cached sorted list + rank-by-id dictionary. Previously `sortedStations`
    // was a computed property recomputed multiple times per body render and
    // `rank(of:)` did an O(n) `firstIndex` lookup *per row* — O(n²) total.
    @State private var sortedStations: [FuelStation] = []
    @State private var rankById: [String: Int] = [:]

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
                                        rank: rankById[station.id] ?? 0,
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
        .onAppear { recomputeSortedStations() }
        .onChange(of: selectedTab) { _, _ in recomputeSortedStations() }
        .onChange(of: stations) { _, _ in recomputeSortedStations() }
    }

    private func recomputeSortedStations() {
        let withPrice = stations.filter { $0.price(for: fuelType) != nil }
        let sorted: [FuelStation]
        switch selectedTab {
        case .price:
            sorted = withPrice.sorted { a, b in
                let pa = a.price(for: fuelType) ?? .greatestFiniteMagnitude
                let pb = b.price(for: fuelType) ?? .greatestFiniteMagnitude
                return pa < pb
            }
        case .distance:
            if let location = userLocation {
                sorted = withPrice.sorted { a, b in
                    a.distance(from: location) < b.distance(from: location)
                }
            } else {
                sorted = withPrice
            }
        case .recommended:
            if let location = userLocation {
                // Pre-snap tank & consumption so the comparator doesn't go
                // through `preferences` (which is an @Observable and triggers
                // tracking) on every comparison.
                let tankLiters = preferences.tankSizeLiters
                let consumption = preferences.consumptionL100Km
                sorted = withPrice.sorted { a, b in
                    totalCost(for: a, location: location, tankLiters: tankLiters, consumption: consumption)
                        < totalCost(for: b, location: location, tankLiters: tankLiters, consumption: consumption)
                }
            } else {
                sorted = withPrice.sorted { a, b in
                    let pa = a.price(for: fuelType) ?? .greatestFiniteMagnitude
                    let pb = b.price(for: fuelType) ?? .greatestFiniteMagnitude
                    return pa < pb
                }
            }
        }
        sortedStations = sorted
        var ranks: [String: Int] = [:]
        ranks.reserveCapacity(sorted.count)
        for (idx, station) in sorted.enumerated() {
            ranks[station.id] = idx + 1
        }
        rankById = ranks
    }

    private func totalCost(
        for station: FuelStation,
        location: CLLocation,
        tankLiters: Double,
        consumption: Double
    ) -> Double {
        guard let price = station.price(for: fuelType), price > 0 else { return .greatestFiniteMagnitude }
        let priceDouble = NSDecimalNumber(decimal: price).doubleValue
        let distanceKm = station.distanceKm(from: location)
        let fillCost = priceDouble * tankLiters
        let detourCost = distanceKm * 2 * (consumption / 100) * priceDouble
        return fillCost + detourCost
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

// MARK: - Charging List Sheet (EV)

private struct ChargingListSheet: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss

    let stations: [ChargingStation]
    let userLocation: CLLocation?
    let radiusKm: Double
    let onStationTapped: (ChargingStation) -> Void

    @State private var selectedTab: SortTab = .recommended

    private var loc: Loc { preferences.loc }

    enum SortTab: String, CaseIterable, Hashable {
        case recommended
        case price
        case speed
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
                    Text(loc.listSpeed).tag(SortTab.speed)
                    Text(loc.listDistance).tag(SortTab.distance)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                if sortedStations.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bolt.slash")
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
                            ForEach(Array(sortedStations.enumerated()), id: \.element.id) { idx, station in
                                Button {
                                    onStationTapped(station)
                                } label: {
                                    ChargingListRow(
                                        station: station,
                                        rank: idx + 1,
                                        distance: distance(for: station)
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
            .navigationTitle(loc.listChargingTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc.close) { dismiss() }
                }
            }
        }
    }

    private var sortedStations: [ChargingStation] {
        let withCoords = stations.filter(\.isOperational)
        switch selectedTab {
        case .price:
            return withCoords.sorted { a, b in
                switch (a.pricePerKWh, b.pricePerKWh) {
                case (let pa?, let pb?): return pa < pb
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return (a.maxPowerKW ?? 0) > (b.maxPowerKW ?? 0)
                }
            }
        case .speed:
            return withCoords.sorted { ($0.maxPowerKW ?? 0) > ($1.maxPowerKW ?? 0) }
        case .distance:
            guard let location = userLocation else { return withCoords }
            return withCoords.sorted {
                $0.distanceKm(from: location) < $1.distanceKm(from: location)
            }
        case .recommended:
            // Compound score:
            //   priceScore  = cheapestPrice / stationPrice           (higher = cheaper)
            //   speedScore  = min(maxKW, 150) / 150                  (higher = faster, capped)
            //   distScore   = 1 - distance / radius                  (higher = closer)
            //   total = 0.5 * price + 0.25 * speed + 0.25 * distance
            // Stations without a price still rank reasonably via speed + distance.
            guard let location = userLocation else { return withCoords }
            let prices = withCoords.compactMap(\.pricePerKWh)
            let cheapest = prices.min() ?? 1
            let maxDistKm = max(radiusKm, 1)
            return withCoords.sorted {
                score(for: $0, cheapestPrice: cheapest, location: location, maxDistKm: maxDistKm)
                    > score(for: $1, cheapestPrice: cheapest, location: location, maxDistKm: maxDistKm)
            }
        }
    }

    private func score(
        for station: ChargingStation,
        cheapestPrice: Decimal,
        location: CLLocation,
        maxDistKm: Double
    ) -> Double {
        let priceScore: Double
        if let price = station.pricePerKWh, price > 0 {
            priceScore = NSDecimalNumber(decimal: cheapestPrice / price).doubleValue
        } else {
            priceScore = 0.6 // unknown — middling
        }
        let speedScore = min(station.maxPowerKW ?? 0, 150) / 150.0
        let distKm = station.distanceKm(from: location)
        let distScore = max(0, 1 - distKm / maxDistKm)
        return priceScore * 0.5 + speedScore * 0.25 + distScore * 0.25
    }

    private func distance(for station: ChargingStation) -> Double? {
        guard let location = userLocation else { return nil }
        return station.distanceKm(from: location)
    }
}

private struct ChargingListRow: View {
    let station: ChargingStation
    let rank: Int
    let distance: Double?

    @Environment(UserPreferences.self) private var preferences
    private var loc: Loc { preferences.loc }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(rank == 1 ? Theme.Colors.charging : Color(.tertiarySystemFill))
                    .frame(width: 28, height: 28)
                Text("\(rank)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(rank == 1 ? .white : Color(.label))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(station.operatorName.isEmpty ? station.name : station.operatorName)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(Color(.label))
                    if station.speedCategory == .fast {
                        HStack(spacing: 2) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 8, weight: .bold))
                            Text(loc.chargingFastBadge)
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.10, green: 0.55, blue: 0.20))
                        .clipShape(Capsule())
                    }
                }

                HStack(spacing: 6) {
                    if let distance {
                        Text(distance.distanceFormatted)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(.secondaryLabel))
                        Text("·")
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    Text(loc.chargingSpeedLabel(station.speedCategory))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(speedColor)
                }

                if !station.connections.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(uniqueConnectors, id: \.self) { typeName in
                                connectorChip(typeName)
                            }
                        }
                    }
                } else {
                    Text(loc.chargingNoInfo)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                if station.isFree {
                    Text("Gratis")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.10, green: 0.55, blue: 0.20))
                } else if let price = station.pricePerKWh {
                    Text(price.priceFormatted)
                        .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color(.label))
                    Text("€/kWh")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                } else if let maxKW = station.maxPowerKW {
                    Text("\(Int(maxKW.rounded()))")
                        .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.Colors.charging)
                    Text("kW")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                } else {
                    Text("—")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.Colors.charging.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var uniqueConnectors: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for c in station.connections {
            let visual = ChargingConnectorBadge.shortName(for: c.typeName)
            if seen.insert(visual).inserted {
                ordered.append(c.typeName)
            }
        }
        return ordered
    }

    private func connectorChip(_ typeName: String) -> some View {
        let visual = ChargingConnectorBadge.visual(for: typeName)
        return HStack(spacing: 3) {
            Image(systemName: visual.symbol)
                .font(.system(size: 8, weight: .bold))
            Text(visual.shortName)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(visual.color)
        .clipShape(Capsule())
    }

    private var speedColor: Color {
        switch station.speedCategory {
        case .fast: Color(red: 0.10, green: 0.55, blue: 0.20)
        case .semiFast: Color(red: 0.85, green: 0.55, blue: 0.10)
        case .slow: Color(red: 0.55, green: 0.55, blue: 0.55)
        case .unknown: Color(.secondaryLabel)
        }
    }
}

/// Shared connector → (symbol, colour, shortName) mapping used in detail
/// view, list and radar. Centralised so all surfaces agree on, e.g.,
/// "blue for CCS, orange for CHAdeMO".
enum ChargingConnectorBadge {
    struct Visual { let symbol: String; let color: Color; let shortName: String }

    static func visual(for raw: String) -> Visual {
        // Canonicalise once via the shared helper so all surfaces agree.
        let canonical = ChargingStation.normalizeConnectorShortName(raw)
        switch canonical {
        case "CCS":
            return .init(symbol: "ev.plug.dc.ccs2", color: Color(red: 0.20, green: 0.45, blue: 0.85), shortName: "CCS")
        case "CHAdeMO":
            return .init(symbol: "ev.plug.dc.chademo", color: Color(red: 0.85, green: 0.45, blue: 0.10), shortName: "CHAdeMO")
        case "NACS":
            return .init(symbol: "ev.plug.dc.nacs", color: Color(red: 0.80, green: 0.20, blue: 0.20), shortName: "NACS")
        case "Type 2":
            // ev.plug.ac.type2 doesn't render reliably across iOS versions;
            // bolt.car.fill is a guaranteed-available EV-flavoured fallback.
            return .init(symbol: "bolt.car.fill", color: Color(red: 0.10, green: 0.55, blue: 0.20), shortName: "Type 2")
        case "Type 1":
            return .init(symbol: "bolt.car.fill", color: Color(red: 0.60, green: 0.30, blue: 0.70), shortName: "Type 1")
        case "Schuko":
            return .init(symbol: "powerplug.fill", color: Color(red: 0.40, green: 0.40, blue: 0.40), shortName: "Schuko")
        case "CEE":
            return .init(symbol: "powerplug.fill", color: Color(red: 0.85, green: 0.55, blue: 0.10), shortName: "CEE")
        default:
            return .init(symbol: "powerplug.fill", color: Color(.secondaryLabel), shortName: canonical)
        }
    }

    static func shortName(for raw: String) -> String {
        ChargingStation.normalizeConnectorShortName(raw)
    }
}
