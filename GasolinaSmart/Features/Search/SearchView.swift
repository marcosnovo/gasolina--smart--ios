import SwiftUI
import CoreLocation

struct SearchView: View {
    @Environment(StationStore.self) private var store
    @Environment(UserPreferences.self) private var preferences
    @Environment(LocationManager.self) private var locationManager
    @Environment(AppState.self) private var appState

    private var loc: Loc { preferences.loc }

    @State private var searchText = ""
    @State private var results: [FuelStation] = []
    @State private var geocodedLocation: CLLocation?
    @State private var geocodedName: String?
    @State private var isGeocoding = false
    @State private var searchTask: Task<Void, Never>?
    @State private var sortByPrice = true
    @State private var didConsumePendingQuery = false

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    searchPrompt
                } else if isGeocoding {
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView()
                        Text(loc.searchingLocation)
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabel))
                        Spacer()
                        Spacer()
                    }
                } else if results.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundStyle(Color(.tertiaryLabel))
                        Text(loc.searchNoResults)
                            .font(.headline)
                        Text(loc.searchTryOther)
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabel))
                        Spacer()
                        Spacer()
                    }
                } else {
                    resultsList
                }
            }
            .searchable(text: $searchText, prompt: loc.searchPlaceholder)
            .navigationTitle(loc.searchTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                guard trimmed.count >= 3 else {
                    results = []
                    geocodedLocation = nil
                    geocodedName = nil
                    isGeocoding = false
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    await performSearch(trimmed)
                }
            }
        }
        .onAppear {
            if let query = appState.pendingSearchQuery, !didConsumePendingQuery {
                didConsumePendingQuery = true
                appState.pendingSearchQuery = nil
                searchText = query
            }
        }
        .onChange(of: appState.pendingSearchQuery) { _, newQuery in
            if let query = newQuery {
                appState.pendingSearchQuery = nil
                searchText = query
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
    }

    private var searchPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer()
            Text(loc.searchPromptTitle)
                .font(.title2.weight(.semibold))
                .lineSpacing(2)
            Text(loc.searchPromptBody)
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sortedResults: [FuelStation] {
        let ref = geocodedLocation ?? locationManager.location
        let fuelType = preferences.selectedFuelType
        if sortByPrice {
            return results.sorted {
                ($0.price(for: fuelType) ?? .greatestFiniteMagnitude) <
                ($1.price(for: fuelType) ?? .greatestFiniteMagnitude)
            }
        } else if let ref {
            return results.sorted { $0.distanceKm(from: ref) < $1.distanceKm(from: ref) }
        }
        return results
    }

    private var resultsList: some View {
        List {
            Section {
                Picker(loc.searchSort, selection: $sortByPrice) {
                    Text(loc.searchByPrice).tag(true)
                    Text(loc.searchByDistance).tag(false)
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))

                ForEach(sortedResults) { station in
                    Button {
                        appState.selectedStation = station
                        appState.showStationDetail = true
                    } label: {
                        StationSearchRow(
                            station: station,
                            fuelType: preferences.selectedFuelType,
                            referenceLocation: geocodedLocation ?? locationManager.location
                        )
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                if let name = geocodedName {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(Theme.Colors.accent)
                        Text(loc.searchStationsNear(results.count, name))
                        Spacer()
                        Button {
                            toggleAddressFavorite(name: name)
                        } label: {
                            Image(systemName: isAddressFavorite(name: name) ? "star.fill" : "star")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(isAddressFavorite(name: name) ? .yellow : Color(.tertiaryLabel))
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.caption)
                    .textCase(.none)
                } else {
                    Text(loc.searchResults(results.count))
                        .font(.caption)
                        .textCase(.none)
                }
            }
        }
        .listStyle(.plain)
    }

    @MainActor
    private func performSearch(_ query: String) async {
        isGeocoding = true

        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            guard !Task.isCancelled else { return }

            if let placemark = placemarks.first, let location = placemark.location {
                geocodedLocation = location
                geocodedName = placemark.locality ?? placemark.name ?? query

                let fuelType = preferences.selectedFuelType
                let withPrice = store.allStations.filter { $0.price(for: fuelType) != nil }
                let withDistance: [(FuelStation, Double)] = withPrice.map { ($0, $0.distanceKm(from: location)) }
                let nearbyPairs = withDistance.filter { $0.1 <= 20 }.sorted { $0.1 < $1.1 }
                let closest = Array(nearbyPairs.prefix(30))
                let byPrice = closest.sorted {
                    ($0.0.price(for: fuelType) ?? .greatestFiniteMagnitude) <
                    ($1.0.price(for: fuelType) ?? .greatestFiniteMagnitude)
                }
                results = byPrice.map { $0.0 }
            } else {
                geocodedLocation = nil
                geocodedName = nil
                results = fallbackTextSearch(query)
            }
        } catch {
            guard !Task.isCancelled else { return }
            geocodedLocation = nil
            geocodedName = nil
            results = fallbackTextSearch(query)
        }

        isGeocoding = false
    }

    private static let stripChars = CharacterSet.alphanumerics.inverted

    private func isAddressFavorite(name: String) -> Bool {
        preferences.favoriteAddresses.contains { $0.name == name }
    }

    private func toggleAddressFavorite(name: String) {
        if let existing = preferences.favoriteAddresses.first(where: { $0.name == name }) {
            preferences.removeFavoriteAddress(existing)
        } else if let location = geocodedLocation {
            let address = FavoriteAddress(
                name: name,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            preferences.addFavoriteAddress(address)
        }
    }

    private func fallbackTextSearch(_ query: String) -> [FuelStation] {
        let words = query.lowercased()
            .components(separatedBy: Self.stripChars)
            .joined(separator: " ")
            .components(separatedBy: .whitespaces)
            .filter { $0.count >= 2 }
        guard !words.isEmpty else { return [] }

        let fuelType = preferences.selectedFuelType
        let location = locationManager.location

        return Array(
            store.allStations
                .filter { station in
                    guard station.price(for: fuelType) != nil else { return false }
                    let text = "\(station.municipality) \(station.province) \(station.address) \(station.name) \(station.brand)".lowercased()
                    return words.allSatisfy { text.contains($0) }
                }
                .sorted {
                    if let location {
                        return $0.distanceKm(from: location) < $1.distanceKm(from: location)
                    }
                    return ($0.price(for: fuelType) ?? .greatestFiniteMagnitude) <
                           ($1.price(for: fuelType) ?? .greatestFiniteMagnitude)
                }
                .prefix(30)
        )
    }
}

struct StationSearchRow: View {
    let station: FuelStation
    let fuelType: FuelType
    let referenceLocation: CLLocation?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(station.address)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(station.municipality)
                    if let referenceLocation {
                        Text("·")
                        Text(station.distanceKm(from: referenceLocation).distanceFormatted)
                            .foregroundStyle(Theme.Colors.accent)
                    }
                }
                .font(.caption)
                .foregroundStyle(Color(.tertiaryLabel))
            }

            Spacer()

            if let price = station.price(for: fuelType) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price.priceFormatted)
                        .font(Theme.Fonts.priceSmall)
                    Text(fuelType.unit(for: station.country))
                        .font(.caption2)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
