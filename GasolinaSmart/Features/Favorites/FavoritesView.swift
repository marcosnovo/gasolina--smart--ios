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
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.pink.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "heart")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.pink.opacity(0.6))
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("Sin favoritos")
                    .font(Theme.Fonts.title)
                Text("Guarda tus gasolineras habituales\npara acceder rápidamente a sus precios.")
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .padding(Theme.Spacing.xl)
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
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
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
            }

            Spacer()

            if let price = station.price(for: fuelType) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price.priceFormatted)
                        .font(Theme.Fonts.priceSmall)
                    Text("€/L")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.Colors.tertiaryLabel)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
