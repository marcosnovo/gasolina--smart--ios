import SwiftUI
import CoreLocation

struct MapView: View {
    @Environment(StationStore.self) private var store
    @Environment(UserPreferences.self) private var preferences
    @Environment(LocationManager.self) private var locationManager
    @Environment(AppState.self) private var appState
    @Environment(ChargingStationStore.self) private var chargingStore

    private var loc: Loc { preferences.loc }

    @State private var showFuelPicker = false
    @State private var showRadiusPicker = false

    @State private var visibleStations: [FuelStation] = []
    @State private var visibleChargingStations: [ChargingStation] = []
    @State private var cachedCheapest: FuelStation?
    @State private var cachedAveragePrice: Decimal?

    @State private var centerOnUserCounter = 0
    @State private var zoomRadiusCounter = 0
    @State private var showNavigationPicker = false
    @State private var initialLoadComplete = false
    @State private var selectedChargingStation: ChargingStation?

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
                isDarkMode: preferences.appearance == .dark
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
        .sheet(isPresented: $showFuelPicker) {
            FuelTypePickerSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRadiusPicker) {
            RadiusPickerSheet()
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
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
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { showFuelPicker = true } label: {
                HStack(spacing: 8) {
                    VehicleAvatar(vehicle: preferences.selectedVehicle, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(preferences.selectedVehicle.name)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text(preferences.selectedFuelType.shortLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                .padding(.trailing, 12)
                .padding(.leading, 5)
                .padding(.vertical, 5)
                .background(.regularMaterial)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button { showRadiusPicker = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                        .font(.system(size: 13, weight: .medium))
                    Text("\(Int(preferences.preferredRadiusKm)) km")
                        .font(Theme.Fonts.pillLabel)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.regularMaterial)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                centerOnUserCounter += 1
                locationManager.requestLocation()
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.md)
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
            Button { appState.selectedTab = .search } label: {
                Text(loc.mapSearchByCity)
                    .font(Theme.Fonts.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.accent)
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
        let nearby = store.nearbyStations(
            location: location,
            radiusKm: preferences.preferredRadiusKm,
            fuelType: preferences.selectedFuelType,
            limit: 100
        )
        visibleStations = nearby

        let fuelType = preferences.selectedFuelType
        cachedCheapest = nearby
            .min { ($0.price(for: fuelType) ?? .greatestFiniteMagnitude) < ($1.price(for: fuelType) ?? .greatestFiniteMagnitude) }

        let prices = nearby.compactMap { $0.price(for: fuelType) }
        if prices.isEmpty {
            cachedAveragePrice = store.cachedAveragePrice
        } else {
            cachedAveragePrice = prices.reduce(Decimal.zero, +) / Decimal(prices.count)
        }

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
                fuelType: preferences.selectedFuelType,
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
