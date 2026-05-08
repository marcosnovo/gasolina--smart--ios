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
            Group {
                if searchText.isEmpty {
                    searchPrompt
                } else if results.isEmpty {
                    noResults
                } else {
                    resultsList
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

    private var searchPrompt: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.tint.opacity(0.6))
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("Busca por ciudad o provincia")
                    .font(Theme.Fonts.headline)
                Text("Encuentra gasolineras en cualquier\npunto de España.")
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
    }

    private var noResults: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "fuelpump.slash")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.orange.opacity(0.6))
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("Sin resultados")
                    .font(Theme.Fonts.headline)
                Text("No se encontraron gasolineras\nen \"\(searchText)\".")
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
    }

    private var resultsList: some View {
        List {
            Section {
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
            } header: {
                Text("\(results.count) resultados · ordenados por precio")
                    .font(.system(size: 11))
                    .textCase(.none)
            }
        }
        .listStyle(.plain)
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
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(Theme.Fonts.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Label(station.municipality, systemImage: "mappin")
                    Text(station.province)
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .lineLimit(1)
            }

            Spacer()

            if let price = station.price(for: fuelType) {
                Text("\(price.priceFormatted)")
                    .font(Theme.Fonts.priceSmall)
                    .foregroundStyle(Theme.Colors.cheapPrice)
            }
        }
        .padding(.vertical, 4)
    }
}
