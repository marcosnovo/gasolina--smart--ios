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
    @State private var visibleStations: [FuelStation] = []

    var body: some View {
        ZStack {
            mapContent

            VStack {
                topControls
                Spacer()
                bottomContent
            }

            if store.isLoading && store.allStations.isEmpty {
                loadingOverlay
            }

            if let error = store.error {
                errorOverlay(error)
            }

            if !store.isLoading && store.allStations.isEmpty && store.error == nil {
                noDataOverlay
            }

            if !locationManager.isAuthorized && !store.isLoading {
                noLocationOverlay
            }
        }
        .task {
            locationManager.requestLocation()
            await store.loadStations()
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
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                    Text("Buscar ciudad...")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            Button { showFuelPicker = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: preferences.selectedFuelType.icon)
                    Text(preferences.selectedFuelType.shortLabel)
                        .font(Theme.Fonts.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
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
        Menu {
            ForEach(UserPreferences.availableRadii, id: \.self) { radius in
                Button {
                    preferences.preferredRadiusKm = radius
                } label: {
                    HStack {
                        Text("\(Int(radius)) km")
                        if preferences.preferredRadiusKm == radius {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "circle.dashed")
                Text("\(Int(preferences.preferredRadiusKm)) km")
                    .font(Theme.Fonts.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
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
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var freshnessLabel: some View {
        HStack(spacing: 4) {
            if store.isUsingCache {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption2)
            }
            Text(store.dataFreshnessText)
                .font(Theme.Fonts.caption)
            if !visibleStations.isEmpty {
                Text("·")
                Text("\(visibleStations.count) estaciones")
                    .font(Theme.Fonts.caption)
            }
            if !store.allStations.isEmpty && visibleStations.isEmpty && locationManager.location != nil {
                Text("·")
                Text("\(store.allStations.count) total")
                    .font(Theme.Fonts.caption)
            }
        }
        .foregroundStyle(Theme.Colors.tertiaryLabel)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private var loadingOverlay: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: Theme.Spacing.xs) {
                Text("Buscando gasolineras")
                    .font(Theme.Fonts.headline)
                Text("Conectando con datos del Ministerio...")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.tertiaryLabel)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.lg)
        .frame(maxWidth: 260)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Error al cargar datos")
                .font(Theme.Fonts.headline)
            Text(message)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .multilineTextAlignment(.center)
            Button("Reintentar") {
                Task { await store.loadStations() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(Theme.Spacing.xl)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
    }

    private var noDataOverlay: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 28))
                    .foregroundStyle(.tint)
                    .symbolEffect(.variableColor, options: .repeating)
            }

            VStack(spacing: Theme.Spacing.xs) {
                Text("Conectando con el servidor")
                    .font(Theme.Fonts.headline)
                Text("Obteniendo precios actualizados...")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.tertiaryLabel)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.lg)
        .frame(maxWidth: 260)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }

    private var noLocationOverlay: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "location.slash")
                .font(.largeTitle)
                .foregroundStyle(Theme.Colors.secondaryLabel)
            Text("Ubicación no disponible")
                .font(Theme.Fonts.headline)
            Text("Activa la ubicación en Ajustes o usa la búsqueda para encontrar gasolineras.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .multilineTextAlignment(.center)
            Button("Buscar por ciudad") {
                showSearch = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(Theme.Spacing.xl)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
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
