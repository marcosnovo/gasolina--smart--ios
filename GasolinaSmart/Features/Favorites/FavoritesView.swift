import SwiftUI
import CoreLocation

struct FavoritesView: View {
    @Environment(StationStore.self) private var store
    @Environment(UserPreferences.self) private var preferences
    @Environment(LocationManager.self) private var locationManager
    @Environment(AppState.self) private var appState

    private var favoriteStations: [FuelStation] {
        store.allStations.filter { preferences.isFavorite($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if favoriteStations.isEmpty {
                    emptyState
                } else {
                    stationsList
                }
            }
            .navigationTitle("Favoritos")
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
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()
            Text("Aún no sigues\nninguna estación")
                .font(.title2.weight(.semibold))
                .lineSpacing(2)
            Text("Añade estaciones desde el mapa para seguir sus precios.")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stationsList: some View {
        List {
            ForEach(favoriteStations) { station in
                Button {
                    appState.selectedStation = station
                    appState.showStationDetail = true
                } label: {
                    FavoriteStationRow(
                        station: station,
                        fuelType: preferences.selectedFuelType,
                        userLocation: locationManager.location
                    )
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        withAnimation {
                            preferences.toggleFavorite(station.id)
                        }
                    } label: {
                        Label("Quitar", systemImage: "heart.slash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

struct FavoriteStationRow: View {
    let station: FuelStation
    let fuelType: FuelType
    let userLocation: CLLocation?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 0) {
                    Text(station.municipality)
                    if let userLocation {
                        Text(" · \(station.distanceKm(from: userLocation).distanceFormatted)")
                    }
                }
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            if let price = station.price(for: fuelType) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price.priceFormatted)
                        .font(Theme.Fonts.priceSmall)
                    Text("€/L")
                        .font(.caption2)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
