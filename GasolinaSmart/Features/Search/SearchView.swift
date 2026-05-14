import SwiftUI
import CoreLocation
import MapKit

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
    @State private var geocodingRequest: MKGeocodingRequest?
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
                    geocodingRequest?.cancel()
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
        geocodingRequest?.cancel()

        do {
            let mapItems = try await resolveMapItems(for: query)
            guard !Task.isCancelled else { return }

            if let mapItem = mapItems.first, let location = mapItem.placemark.location {
                geocodedLocation = location
                geocodedName = mapItem.placemark.locality ?? mapItem.name ?? query

                let fuelType = preferences.selectedFuelType
                let nearbyCountry = Country.detect(from: location.coordinate) ?? preferences.selectedCountry
                let stations = try await stationsForResolvedLocation(location, country: nearbyCountry)

                let withPrice = stations.filter { $0.price(for: fuelType) != nil }
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

    private func resolveMapItems(for query: String) async throws -> [MKMapItem] {
        let region = countryRegion(for: preferences.selectedCountry)
        let localizedQuery = "\(query), \(preferences.selectedCountry.displayName)"

        for candidate in [query, localizedQuery] {
            let regionalItems = try await searchMapItems(for: candidate, region: region)
            if !regionalItems.isEmpty {
                return regionalItems
            }
        }

        let unrestrictedItems = try await searchMapItems(for: query, region: nil)
        if !unrestrictedItems.isEmpty {
            return unrestrictedItems
        }

        for candidate in [query, localizedQuery] {
            guard let geocodingRequest = MKGeocodingRequest(addressString: candidate) else { continue }
            self.geocodingRequest = geocodingRequest
            let geocodedItems = try await geocodedMapItems(for: geocodingRequest)
            let rankedItems = rankedMapItems(from: geocodedItems, query: query)
            if !rankedItems.isEmpty {
                return rankedItems
            }
        }

        return []
    }

    private func geocodedMapItems(for request: MKGeocodingRequest) async throws -> [MKMapItem] {
        try await withCheckedThrowingContinuation { continuation in
            request.getMapItems { items, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: items ?? [])
                }
            }
        }
    }

    private func countryRegion(for country: Country) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: country.mapCenter,
            span: MKCoordinateSpan(latitudeDelta: 22, longitudeDelta: 22)
        )
    }

    private func searchMapItems(
        for query: String,
        region: MKCoordinateRegion?
    ) async throws -> [MKMapItem] {
        let request: MKLocalSearch.Request
        if let region {
            request = MKLocalSearch.Request(naturalLanguageQuery: query, region: region)
            request.regionPriority = .default
        } else {
            request = MKLocalSearch.Request(naturalLanguageQuery: query)
        }
        request.resultTypes = [.address, .pointOfInterest, .physicalFeature]

        let response = try await MKLocalSearch(request: request).start()
        return rankedMapItems(from: response.mapItems, query: query)
    }

    private func stationsForResolvedLocation(_ location: CLLocation, country: Country) async throws -> [FuelStation] {
        guard let source = await MainActor.run(body: { FuelDataSourceRegistry.shared.source(for: country) }) else {
            return []
        }

        return try await source.fetchStations(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radiusKm: max(preferences.preferredRadiusKm + 20, 40)
        )
    }

    private func rankedMapItems(from items: [MKMapItem], query: String) -> [MKMapItem] {
        let normalizedQuery = normalized(query)

        return items
            .filter { $0.placemark.location != nil }
            .sorted { lhs, rhs in
                let leftScore = mapItemScore(lhs, query: normalizedQuery)
                let rightScore = mapItemScore(rhs, query: normalizedQuery)
                if leftScore != rightScore {
                    return leftScore > rightScore
                }
                return (lhs.name ?? "") < (rhs.name ?? "")
            }
    }

    private func mapItemScore(_ item: MKMapItem, query: String) -> Int {
        let placemark = item.placemark
        let fields = [
            placemark.locality,
            placemark.subLocality,
            placemark.administrativeArea,
            placemark.title,
            item.name
        ]
        .compactMap { $0?.lowercased() }

        var score = 0
        for field in fields {
            if field == query {
                score += 40
            } else if field.contains(query) {
                score += 20
            }
        }
        if placemark.locality != nil { score += 10 }
        return score
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
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
