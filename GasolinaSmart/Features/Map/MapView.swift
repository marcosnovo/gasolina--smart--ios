import SwiftUI
import MapKit

struct MapView: View {
    @Environment(StationStore.self) private var store
    @Environment(UserPreferences.self) private var preferences
    @Environment(LocationManager.self) private var locationManager
    @Environment(AppState.self) private var appState

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedStationId: String?
    @State private var showFuelPicker = false
    @State private var showSearch = false
    @State private var showRadiusPicker = false
    @State private var visibleStations: [FuelStation] = []

    var body: some View {
        ZStack {
            mapContent

            VStack {
                topControls

                if store.isLoading && store.allStations.isEmpty {
                    loadingPill
                        .padding(.top, Theme.Spacing.sm)
                }

                Spacer()

                if let error = store.error, store.allStations.isEmpty {
                    errorBanner(error)
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
            locationManager.requestLocation()
            await store.loadStations(near: locationManager.location)
        }
        .onChange(of: locationManager.location) { _, _ in
            updateVisibleStations()
        }
        .onChange(of: store.allStations) { _, _ in
            updateVisibleStations()
        }
        .onChange(of: preferences.preferredRadiusKm) { _, _ in
            updateVisibleStations()
        }
        .onChange(of: preferences.selectedFuelType) { _, _ in
            updateVisibleStations()
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
        .sheet(isPresented: $showSearch) {
            SearchView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRadiusPicker) {
            RadiusPickerSheet()
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
    }

    private var mapContent: some View {
        Map(position: $cameraPosition, selection: $selectedStationId) {
            UserAnnotation()

            ForEach(visibleStations) { station in
                let isCheapest = cheapestStation?.id == station.id
                let price = station.price(for: preferences.selectedFuelType)

                Annotation(
                    price.map { "\($0.priceFormatted) €" } ?? "",
                    coordinate: station.coordinate,
                    anchor: .bottom
                ) {
                    StationMarker(
                        price: price,
                        isCheapest: isCheapest,
                        isFavorite: preferences.isFavorite(station.id)
                    )
                    .onTapGesture {
                        appState.selectedStation = station
                        appState.showStationDetail = true
                    }
                }
                .tag(station.id)
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
    }

    private var topControls: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                showSearch = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                    Text("Buscar ciudad...")
                        .font(Theme.Fonts.subheadline)
                        .foregroundStyle(Theme.Colors.tertiaryLabel)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: Theme.Shadows.soft, radius: 8, y: 4)
            }
            .buttonStyle(.plain)

            Spacer()

            Button { showFuelPicker = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: preferences.selectedFuelType.icon)
                        .font(.system(size: 12))
                    Text(preferences.selectedFuelType.shortLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: Theme.Shadows.soft, radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
    }

    private var bottomContent: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                radiusSelector
                Spacer()
                locationButton
            }
            .padding(.horizontal, Theme.Spacing.md)

            if let cheapest = cheapestStation,
               let location = locationManager.location {
                CheapestStationCard(
                    station: cheapest,
                    fuelType: preferences.selectedFuelType,
                    averagePrice: store.averagePrice(
                        location: location,
                        radiusKm: preferences.preferredRadiusKm,
                        fuelType: preferences.selectedFuelType
                    ),
                    tankLiters: preferences.tankSizeLiters,
                    distance: cheapest.distanceKm(from: location),
                    onTap: {
                        appState.selectedStation = cheapest
                        appState.showStationDetail = true
                    }
                )
                .padding(.horizontal, Theme.Spacing.md)
            } else if locationManager.isAuthorized && locationManager.location != nil
                        && !store.allStations.isEmpty && visibleStations.isEmpty {
                noNearbyCard
            }

            freshnessLabel
                .padding(.bottom, Theme.Spacing.sm)
        }
    }

    private var noNearbyCard: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "fuelpump.slash")
                .font(.title2)
                .foregroundStyle(Theme.Colors.secondaryLabel)
            Text("No hay gasolineras en \(Int(preferences.preferredRadiusKm)) km")
                .font(Theme.Fonts.headline)
            Text("Prueba a ampliar el radio de búsqueda")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .padding(.horizontal, Theme.Spacing.md)
    }

    private var radiusSelector: some View {
        Button { showRadiusPicker = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 12))
                Text("\(Int(preferences.preferredRadiusKm)) km")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: Theme.Shadows.soft, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var locationButton: some View {
        Button {
            withAnimation {
                cameraPosition = .userLocation(fallback: .automatic)
            }
            locationManager.requestLocation()
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 14, weight: .medium))
                .padding(11)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: Theme.Shadows.soft, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var freshnessLabel: some View {
        HStack(spacing: 4) {
            if store.isUsingCache {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 9))
            }
            Text(store.dataFreshnessText)
                .font(.system(size: 11))
            if !visibleStations.isEmpty {
                Text("·")
                Text("\(visibleStations.count) estaciones")
                    .font(.system(size: 11))
            }
            if !store.allStations.isEmpty && visibleStations.isEmpty && locationManager.location != nil {
                Text("·")
                Text("\(store.allStations.count) total")
                    .font(.system(size: 11))
            }
        }
        .foregroundStyle(Theme.Colors.tertiaryLabel)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private var loadingPill: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Cargando gasolineras cercanas...")
                .font(.system(size: 13, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: Theme.Shadows.soft, radius: 8, y: 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.orange)
            Text("Error al cargar")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Button {
                Task { await store.loadStations(near: locationManager.location) }
            } label: {
                Text("Reintentar")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .shadow(color: Theme.Shadows.soft, radius: 8, y: 4)
    }

    private var noLocationOverlay: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }

            VStack(spacing: Theme.Spacing.xs) {
                Text("Ubicación no disponible")
                    .font(Theme.Fonts.headline)
                Text("Activa la ubicación en Ajustes o\nbusca por ciudad.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }

            Button {
                showSearch = true
            } label: {
                Text("Buscar por ciudad")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, 10)
                    .background(Theme.Colors.accentGradient)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.lg)
        .frame(maxWidth: 280)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }

    private var cheapestStation: FuelStation? {
        guard let location = locationManager.location else { return nil }
        return store.cheapestStation(
            location: location,
            radiusKm: preferences.preferredRadiusKm,
            fuelType: preferences.selectedFuelType
        )
    }

    private func updateVisibleStations() {
        guard let location = locationManager.location else {
            visibleStations = []
            return
        }
        visibleStations = store.nearbyStations(
            location: location,
            radiusKm: preferences.preferredRadiusKm,
            fuelType: preferences.selectedFuelType
        )
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
                Button {
                    preferences.preferredRadiusKm = sliderValue
                    dismiss()
                } label: {
                    Text("Aplicar")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Text("\(Int(sliderValue)) km")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .contentTransition(.numericText(value: sliderValue))
                .animation(.snappy(duration: 0.2), value: sliderValue)

            Slider(value: $sliderValue, in: 1...50, step: 1) {
                Text("Radio")
            } minimumValueLabel: {
                Text("1")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.tertiaryLabel)
            } maximumValueLabel: {
                Text("50")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.tertiaryLabel)
            }

            HStack(spacing: Theme.Spacing.sm) {
                ForEach(UserPreferences.availableRadii, id: \.self) { radius in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            sliderValue = radius
                        }
                    } label: {
                        Text("\(Int(radius))")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                Int(sliderValue) == Int(radius)
                                    ? AnyShapeStyle(Color.accentColor)
                                    : AnyShapeStyle(Theme.Colors.secondaryBackground)
                            )
                            .foregroundStyle(
                                Int(sliderValue) == Int(radius)
                                    ? .white
                                    : Theme.Colors.label
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
