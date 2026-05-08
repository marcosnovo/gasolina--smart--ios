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
        ContentUnavailableView {
            Label("Sin favoritos", systemImage: "heart.slash")
        } description: {
            Text("Guarda tus gasolineras habituales para acceder rápidamente a sus precios y compararlas.")
        }
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
                        preferences.toggleFavorite(station.id)
                    } label: {
                        Label("Quitar", systemImage: "heart.slash")
                    }
                }
            }
        }
    }
}

struct FavoriteStationRow: View {
    let station: FuelStation
    let fuelType: FuelType
    let userLocation: CLLocation?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(station.name)
                    .font(Theme.Fonts.headline)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.sm) {
                    Text(station.municipality)
                    if let userLocation {
                        Text("·")
                        Text(station.distanceKm(from: userLocation).distanceFormatted)
                    }
                }
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)

                Text("Actualizado: \(station.lastUpdated.formatted(.dateTime.day().month().hour().minute()))")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.tertiaryLabel)
            }

            Spacer()

            if let price = station.price(for: fuelType) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(price.priceFormatted)")
                        .font(Theme.Fonts.priceSmall)
                    Text("€/L")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
