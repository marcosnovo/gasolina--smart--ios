import SwiftUI

struct SearchView: View {
    @Environment(StationStore.self) private var store
    @Environment(UserPreferences.self) private var preferences
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var results: [FuelStation] = []

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "Busca una ciudad o provincia",
                        systemImage: "magnifyingglass",
                        description: Text("Escribe el nombre de un municipio o provincia para ver gasolineras.")
                    )
                } else if results.isEmpty {
                    ContentUnavailableView(
                        "Sin resultados",
                        systemImage: "fuelpump.slash",
                        description: Text("No se encontraron gasolineras en \"\(searchText)\".")
                    )
                } else {
                    ForEach(results) { station in
                        Button {
                            appState.selectedStation = station
                            appState.showStationDetail = true
                            dismiss()
                        } label: {
                            StationSearchRow(station: station, fuelType: preferences.selectedFuelType)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Municipio o provincia")
            .navigationTitle("Buscar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .onChange(of: searchText) { _, newValue in
                performSearch(newValue)
            }
        }
    }

    private func performSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.count >= 2 else {
            results = []
            return
        }

        results = Array(
            store.allStations
                .filter { station in
                    station.municipality.lowercased().contains(trimmed) ||
                    station.province.lowercased().contains(trimmed)
                }
                .filter { $0.price(for: preferences.selectedFuelType) != nil }
                .sorted {
                    let p1 = $0.price(for: preferences.selectedFuelType) ?? Decimal.greatestFiniteMagnitude
                    let p2 = $1.price(for: preferences.selectedFuelType) ?? Decimal.greatestFiniteMagnitude
                    return p1 < p2
                }
                .prefix(50)
        )
    }
}

struct StationSearchRow: View {
    let station: FuelStation
    let fuelType: FuelType

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(station.name)
                .font(Theme.Fonts.headline)
                .lineLimit(1)

            HStack(spacing: Theme.Spacing.sm) {
                if let price = station.price(for: fuelType) {
                    Text("\(price.priceFormatted) €/L")
                        .font(Theme.Fonts.priceSmall)
                        .foregroundStyle(Theme.Colors.cheapPrice)
                }

                Text(station.municipality)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)

                Text("·")
                    .foregroundStyle(Theme.Colors.tertiaryLabel)

                Text(station.province)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.tertiaryLabel)
            }

            Text(station.address)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.tertiaryLabel)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}
