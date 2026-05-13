import SwiftUI
import CoreLocation

struct FavoritesView: View {
    @Environment(StationStore.self) private var store
    @Environment(UserPreferences.self) private var preferences
    @Environment(LocationManager.self) private var locationManager
    @Environment(AppState.self) private var appState

    private var loc: Loc { preferences.loc }

    @State private var showNavigationPicker = false
    @State private var navigationTarget: FuelStation?

    private var favoriteStations: [FuelStation] {
        store.allStations.filter { preferences.isFavorite($0.id) }
    }

    private var isEmpty: Bool {
        favoriteStations.isEmpty && preferences.favoriteAddresses.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if !preferences.favoriteAddresses.isEmpty {
                                sectionHeader(loc.favAddresses)
                                ForEach(preferences.favoriteAddresses) { address in
                                    AddressFavoriteCard(
                                        address: address,
                                        onNavigate: { station in navigateTo(station) },
                                        onSearch: {
                                            appState.pendingSearchQuery = address.name
                                            appState.selectedTab = .search
                                        },
                                        onRemove: {
                                            withAnimation { preferences.removeFavoriteAddress(address) }
                                        }
                                    )
                                }
                            }

                            if !favoriteStations.isEmpty {
                                sectionHeader(loc.favStations)
                                ForEach(favoriteStations) { station in
                                    StationFavoriteCard(
                                        station: station,
                                        onTap: {
                                            appState.selectedStation = station
                                            appState.showStationDetail = true
                                        },
                                        onNavigate: { navigateTo(station) },
                                        onRemove: {
                                            withAnimation { preferences.toggleFavorite(station.id) }
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle(loc.favTitle)
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
        .sheet(isPresented: $showNavigationPicker) {
            if let station = navigationTarget {
                let apps = preferences.enabledNavigationApps.isEmpty
                    ? Set(PreferredNavigationApp.allCases)
                    : preferences.enabledNavigationApps
                NavigationPickerSheet(station: station, availableApps: apps)
                    .presentationDetents([.height(180)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color(.tertiaryLabel))
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    private func navigateTo(_ station: FuelStation) {
        if preferences.enabledNavigationApps.count == 1,
           let app = preferences.enabledNavigationApps.first {
            NavigationHelper.openPreferred(station: station, app: app)
        } else {
            navigationTarget = station
            showNavigationPicker = true
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()
            Text(loc.favEmpty)
                .font(.title2.weight(.semibold))
                .lineSpacing(2)
            Text(loc.favEmptyBody)
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Station Favorite Card

private struct StationFavoriteCard: View {
    let station: FuelStation
    let onTap: () -> Void
    let onNavigate: () -> Void
    let onRemove: () -> Void

    @Environment(UserPreferences.self) private var preferences
    @Environment(LocationManager.self) private var locationManager
    @Environment(\.colorScheme) private var colorScheme

    private var loc: Loc { preferences.loc }
    private var price: Decimal? { station.price(for: preferences.selectedFuelType) }
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onTap) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.accent)
                            .frame(width: 44, height: 44)
                        VStack(spacing: 1) {
                            Image(systemName: "fuelpump.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text(preferences.selectedFuelType.shortLabel)
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.white)
                    }

                    if let price {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text(price.priceFormatted)
                                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                            Text(preferences.selectedFuelType.unit(for: station.country))
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(isDark ? .black.opacity(0.4) : .white.opacity(0.5))
                        }
                        .foregroundStyle(isDark ? .black : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(isDark ? .white : Color(white: 0.12))
                        .clipShape(Capsule())
                        .padding(.top, -6)
                    }
                }
                .frame(width: 80)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(station.brand)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                HStack(spacing: 0) {
                    Text(station.name)
                        .lineLimit(1)
                    if let loc = locationManager.location {
                        Text(" · \(station.distanceKm(from: loc).distanceFormatted)")
                            .foregroundStyle(Color(.secondaryLabel))
                            .layoutPriority(1)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(.label))
                .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 8)

            VStack(spacing: 6) {
                Button(action: onNavigate) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(loc.navigate)
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onRemove) {
                    Image(systemName: "star.slash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                HStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Theme.Colors.accent.opacity(0),
                            Theme.Colors.accent.opacity(isDark ? 0.20 : 0.08)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 120)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Address Favorite Card

private struct AddressFavoriteCard: View {
    let address: FavoriteAddress
    let onNavigate: (FuelStation) -> Void
    let onSearch: () -> Void
    let onRemove: () -> Void

    @Environment(StationStore.self) private var store
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    private var loc: Loc { preferences.loc }
    private var isDark: Bool { colorScheme == .dark }

    private var cheapestNearby: FuelStation? {
        let location = CLLocation(latitude: address.latitude, longitude: address.longitude)
        return store.cheapestStation(
            location: location,
            radiusKm: 10,
            fuelType: preferences.selectedFuelType
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSearch) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.accent.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Theme.Colors.accent)
                    }

                    if let station = cheapestNearby, let price = station.price(for: preferences.selectedFuelType) {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text(price.priceFormatted)
                                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                            Text(preferences.selectedFuelType.unit(for: station.country))
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(isDark ? .black.opacity(0.4) : .white.opacity(0.5))
                        }
                        .foregroundStyle(isDark ? .black : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(isDark ? .white : Color(white: 0.12))
                        .clipShape(Capsule())
                        .padding(.top, -6)
                    }
                }
                .frame(width: 80)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(address.name)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                if let station = cheapestNearby {
                    HStack(spacing: 0) {
                        Text(station.brand)
                            .fontWeight(.semibold)
                        Text(" · \(station.name)")
                            .lineLimit(1)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
                    .minimumScaleFactor(0.85)
                } else {
                    Text(loc.favNoNearby)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }

            Spacer(minLength: 8)

            VStack(spacing: 6) {
                if let station = cheapestNearby {
                    Button { onNavigate(station) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text(loc.navigate)
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.accent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onSearch) {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 10, weight: .bold))
                            Text(loc.searchTitle)
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.accent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onRemove) {
                    Image(systemName: "star.slash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                HStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Theme.Colors.accent.opacity(0),
                            Theme.Colors.accent.opacity(isDark ? 0.20 : 0.08)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 120)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
