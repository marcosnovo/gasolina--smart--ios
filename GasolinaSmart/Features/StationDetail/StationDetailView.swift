import SwiftUI
import CoreLocation

struct StationDetailView: View {
    let station: FuelStation
    @Environment(UserPreferences.self) private var preferences
    @Environment(LocationManager.self) private var locationManager
    @Environment(StationStore.self) private var store

    private var distance: Double? {
        guard let location = locationManager.location else { return nil }
        return station.distanceKm(from: location)
    }

    private var selectedPrice: Decimal? {
        station.price(for: preferences.selectedFuelType)
    }

    private var averagePrice: Decimal? {
        guard let location = locationManager.location else { return nil }
        return store.averagePrice(
            location: location,
            radiusKm: preferences.preferredRadiusKm,
            fuelType: preferences.selectedFuelType
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    headerSection
                    priceSection
                    comparisonSection
                    allPricesSection
                    navigationSection
                    infoSection
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle(station.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        preferences.toggleFavorite(station.id)
                    } label: {
                        Image(systemName: preferences.isFavorite(station.id) ? "heart.fill" : "heart")
                            .foregroundStyle(preferences.isFavorite(station.id) ? .pink : .secondary)
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(station.brand)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)

            Text(station.address)
                .font(Theme.Fonts.body)

            HStack(spacing: Theme.Spacing.sm) {
                Text(station.municipality)
                Text("·")
                Text(station.province)
            }
            .font(Theme.Fonts.caption)
            .foregroundStyle(Theme.Colors.secondaryLabel)

            if let distance {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text(distance.distanceFormatted)
                }
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
            }
        }
    }

    private var priceSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if let selectedPrice {
                HStack(alignment: .firstTextBaseline) {
                    Text(selectedPrice.priceFormatted)
                        .font(Theme.Fonts.price)
                    Text("€/L")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }

                Text(preferences.selectedFuelType.displayName)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            } else {
                Text("Precio no disponible para \(preferences.selectedFuelType.displayName)")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
    }

    private var comparisonSection: some View {
        Group {
            if let selectedPrice, let averagePrice {
                let saving = store.estimatedSaving(
                    stationPrice: selectedPrice,
                    averagePrice: averagePrice,
                    tankLiters: preferences.tankSizeLiters
                )
                let worthIt = store.worthItLevel(saving: saving)

                VStack(spacing: Theme.Spacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Media cercana")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.secondaryLabel)
                            Text("\(averagePrice.priceFormatted) €/L")
                                .font(Theme.Fonts.priceSmall)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Ahorro estimado")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.secondaryLabel)
                            Text(saving.savingFormatted)
                                .font(Theme.Fonts.priceSmall)
                                .foregroundStyle(saving > 0 ? Theme.Colors.saving : Theme.Colors.label)
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: worthIt.icon)
                        Text(worthIt.message)
                    }
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)

                    Text("Para un depósito de \(Int(preferences.tankSizeLiters)) L")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.tertiaryLabel)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
        }
    }

    private var allPricesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Todos los precios")
                .font(Theme.Fonts.headline)

            ForEach(FuelType.allCases) { fuel in
                if let price = station.price(for: fuel) {
                    HStack {
                        Image(systemName: fuel.icon)
                            .frame(width: 20)
                            .foregroundStyle(.secondary)
                        Text(fuel.displayName)
                            .font(Theme.Fonts.body)
                        Spacer()
                        Text("\(price.priceFormatted) €/L")
                            .font(Theme.Fonts.priceSmall)
                            .foregroundStyle(fuel == preferences.selectedFuelType ? .primary : .secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private var navigationSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("Cómo llegar")
                .font(Theme.Fonts.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Theme.Spacing.sm) {
                NavigationButton(title: "Apple Maps", icon: "map.fill") {
                    openAppleMaps()
                }
                NavigationButton(title: "Google Maps", icon: "globe") {
                    openGoogleMaps()
                }
                NavigationButton(title: "Waze", icon: "car.fill") {
                    openWaze()
                }
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text("Actualizado: \(station.lastUpdated.formatted(.dateTime.day().month().hour().minute()))")
            }
            .font(Theme.Fonts.caption)
            .foregroundStyle(Theme.Colors.tertiaryLabel)

            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                Text("Fuente: Ministerio de Industria")
            }
            .font(Theme.Fonts.caption)
            .foregroundStyle(Theme.Colors.tertiaryLabel)
        }
        .padding(.top, Theme.Spacing.sm)
    }

    private func openAppleMaps() {
        guard let url = URL(string: "http://maps.apple.com/?daddr=\(station.latitude),\(station.longitude)&dirflg=d") else { return }
        UIApplication.shared.open(url)
    }

    private func openGoogleMaps() {
        guard let url = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(station.latitude),\(station.longitude)&travelmode=driving") else { return }
        UIApplication.shared.open(url)
    }

    private func openWaze() {
        guard let url = URL(string: "https://waze.com/ul?ll=\(station.latitude),\(station.longitude)&navigate=yes") else { return }
        UIApplication.shared.open(url)
    }
}

struct NavigationButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
    }
}
