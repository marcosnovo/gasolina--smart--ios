import SwiftUI
import CoreLocation

enum SearchSortOrder: String, CaseIterable {
    case relevance
    case price
    case distance

    var label: String {
        switch self {
        case .relevance: "Relevancia"
        case .price: "Precio"
        case .distance: "Distancia"
        }
    }
}

struct SearchView: View {
    @Environment(StationStore.self) private var store
    @Environment(UserPreferences.self) private var preferences
    @Environment(LocationManager.self) private var locationManager
    @Environment(AppState.self) private var appState

    @State private var searchText = ""
    @State private var results: [FuelStation] = []
    @State private var sortOrder: SearchSortOrder = .relevance
    @State private var isShowingNearby = false

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    searchPrompt
                } else {
                    resultsList
                }
            }
            .searchable(text: $searchText, prompt: "Ciudad, calle o gasolinera")
            .navigationTitle("Buscar")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: searchText) { _, newValue in
                performSearch(newValue)
            }
            .onChange(of: sortOrder) { _, _ in
                performSearch(searchText)
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
            Text("Busca gasolineras\npor nombre o ubicación")
                .font(.title2.weight(.semibold))
                .lineSpacing(2)
            Text("Busca por ciudad, provincia, calle o nombre de gasolinera.")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resultsList: some View {
        List {
            if isShowingNearby {
                Section {
                    ForEach(results) { station in
                        Button {
                            appState.selectedStation = station
                            appState.showStationDetail = true
                        } label: {
                            StationSearchRow(
                                station: station,
                                fuelType: preferences.selectedFuelType,
                                userLocation: locationManager.location
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Sin resultados para \"\(searchText)\" · Cercanas a ti")
                        .font(.caption)
                        .textCase(.none)
                }
            } else {
                Section {
                    sortPicker
                    ForEach(results) { station in
                        Button {
                            appState.selectedStation = station
                            appState.showStationDetail = true
                        } label: {
                            StationSearchRow(
                                station: station,
                                fuelType: preferences.selectedFuelType,
                                userLocation: locationManager.location
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("\(results.count) resultados")
                        .font(.caption)
                        .textCase(.none)
                }
            }
        }
        .listStyle(.plain)
    }

    private var sortPicker: some View {
        Picker("Ordenar", selection: $sortOrder) {
            ForEach(SearchSortOrder.allCases, id: \.self) { order in
                if order == .distance && locationManager.location == nil {
                    EmptyView()
                } else {
                    Text(order.label).tag(order)
                }
            }
        }
        .pickerStyle(.segmented)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
    }

    private static let stripChars = CharacterSet.alphanumerics.inverted

    private func performSearch(_ query: String) {
        let cleaned = query.lowercased()
            .components(separatedBy: Self.stripChars)
            .joined(separator: " ")
        let words = cleaned.components(separatedBy: .whitespaces)
            .filter { $0.count >= 2 }
        guard !words.isEmpty else {
            results = []
            return
        }

        let fuelType = preferences.selectedFuelType
        let userLocation = locationManager.location

        let withPrice = store.allStations.filter { $0.price(for: fuelType) != nil }

        let filtered = withPrice.filter { station in
            let searchableText = "\(station.municipality) \(station.province) \(station.address) \(station.name) \(station.brand)"
                .lowercased()
                .components(separatedBy: Self.stripChars)
                .joined(separator: " ")
            return words.allSatisfy { searchableText.contains($0) }
        }

        if filtered.isEmpty, let location = userLocation {
            isShowingNearby = true
            results = Array(
                withPrice
                    .sorted { relevanceScore($0, fuelType: fuelType, location: location) < relevanceScore($1, fuelType: fuelType, location: location) }
                    .prefix(10)
            )
            return
        }

        isShowingNearby = false

        let sorted: [FuelStation]
        switch sortOrder {
        case .price:
            sorted = filtered.sorted {
                ($0.price(for: fuelType) ?? .greatestFiniteMagnitude) <
                ($1.price(for: fuelType) ?? .greatestFiniteMagnitude)
            }
        case .distance:
            guard let location = userLocation else {
                sorted = filtered
                break
            }
            sorted = filtered.sorted {
                $0.distanceKm(from: location) < $1.distanceKm(from: location)
            }
        case .relevance:
            if let location = userLocation {
                sorted = filtered.sorted {
                    relevanceScore($0, fuelType: fuelType, location: location) <
                    relevanceScore($1, fuelType: fuelType, location: location)
                }
            } else {
                sorted = filtered.sorted {
                    ($0.price(for: fuelType) ?? .greatestFiniteMagnitude) <
                    ($1.price(for: fuelType) ?? .greatestFiniteMagnitude)
                }
            }
        }

        results = Array(sorted.prefix(50))
    }

    private func relevanceScore(_ station: FuelStation, fuelType: FuelType, location: CLLocation) -> Double {
        let price = (station.price(for: fuelType) ?? Decimal(99)) as NSDecimalNumber
        let priceNormalized = price.doubleValue
        let distanceKm = station.distanceKm(from: location)
        return priceNormalized * 0.6 + (distanceKm / 100.0) * 0.4
    }
}

struct StationSearchRow: View {
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
                    Text(station.address)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
                HStack(spacing: 4) {
                    Text(station.municipality)
                    if let userLocation {
                        Text("·")
                        Text(station.distanceKm(from: userLocation).distanceFormatted)
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
                    Text("€/L")
                        .font(.caption2)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
