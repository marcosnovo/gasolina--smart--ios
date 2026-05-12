import SwiftUI
import CoreLocation

struct MapView: View {
    @Environment(StationStore.self) private var store
    @Environment(UserPreferences.self) private var preferences
    @Environment(LocationManager.self) private var locationManager
    @Environment(AppState.self) private var appState

    @State private var showFuelPicker = false
    @State private var showRadiusPicker = false

    @State private var visibleStations: [FuelStation] = []
    @State private var cachedCheapest: FuelStation?
    @State private var cachedAveragePrice: Decimal?

    @State private var centerOnUserCounter = 0
    @State private var zoomRadiusCounter = 0
    @State private var showNavigationPicker = false

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
                centerOnUserCounter: centerOnUserCounter,
                zoomRadiusKm: preferences.preferredRadiusKm,
                zoomRadiusCounter: zoomRadiusCounter,
                isDarkMode: preferences.appearance == .dark
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, Theme.Spacing.xs)

                if store.isLoading && store.allStations.isEmpty {
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
        }
        .onChange(of: locationManager.location) { _, newLocation in
            updateVisibleStations()
            if let newLocation {
                Task {
                    await store.loadStations(
                        near: newLocation,
                        radiusKm: preferences.preferredRadiusKm
                    )
                }
            }
        }
        .onChange(of: store.allStations) { _, _ in
            updateVisibleStations()
        }
        .onChange(of: preferences.preferredRadiusKm) { _, _ in
            updateVisibleStations()
            zoomRadiusCounter += 1
            Task {
                await store.reloadIfNeeded(
                    location: locationManager.location,
                    radiusKm: preferences.preferredRadiusKm
                )
            }
        }
        .onChange(of: preferences.selectedFuelType) { _, _ in
            updateVisibleStations()
        }
        .onChange(of: preferences.preferredNavigationApp) { _, _ in
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
                NavigationPickerSheet(station: cheapest)
                    .presentationDetents([.height(180)])
                    .presentationDragIndicator(.visible)
            }
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
                        showNavigationPicker = true
                    }
                )
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                .padding(.horizontal, Theme.Spacing.md)
            } else if locationManager.isAuthorized && locationManager.location != nil
                        && !store.allStations.isEmpty && visibleStations.isEmpty {
                VStack(spacing: 4) {
                    Text("Sin gasolineras en \(Int(preferences.preferredRadiusKm)) km")
                        .font(Theme.Fonts.subheadline)
                        .fontWeight(.medium)
                    Text("Amplía el radio de búsqueda")
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
            Text("Cargando gasolineras...")
                .font(Theme.Fonts.pillLabel)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(Capsule())
    }

    private var freshnessLabel: some View {
        HStack(spacing: 4) {
            if store.isUsingCache {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 9))
            }
            Text(store.dataFreshnessText)
                .font(Theme.Fonts.caption)
            if !visibleStations.isEmpty {
                Text("· \(visibleStations.count) estaciones")
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
            Text("Error al cargar")
                .font(Theme.Fonts.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Reintentar") {
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
            Text("Ubicación no disponible")
                .font(Theme.Fonts.headline)
            Text("Activa la ubicación en Ajustes o busca por ciudad.")
                .font(Theme.Fonts.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { appState.selectedTab = .search } label: {
                Text("Buscar por ciudad")
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
            limit: 150
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

    @State private var sliderValue: Double = 5

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack {
                Text("Radio de búsqueda")
                    .font(Theme.Fonts.headline)
                Spacer()
                Button("Aplicar") {
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
                Text("Radio")
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
