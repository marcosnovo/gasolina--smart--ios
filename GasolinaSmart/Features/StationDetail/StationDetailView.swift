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
                VStack(spacing: Theme.Spacing.lg) {
                    priceHeroSection
                    headerSection
                    comparisonSection
                    allPricesSection
                    navigationSection
                    infoSection
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(station.brand)
                        .font(Theme.Fonts.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        preferences.toggleFavorite(station.id)
                    } label: {
                        Image(systemName: preferences.isFavorite(station.id) ? "heart.fill" : "heart")
                            .symbolEffect(.bounce, value: preferences.isFavorite(station.id))
                            .foregroundStyle(preferences.isFavorite(station.id) ? .pink : .secondary)
                    }
                }
            }
        }
    }

    // MARK: - Price Hero

    private var priceHeroSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if let selectedPrice {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(selectedPrice.priceFormatted)
                        .font(Theme.Fonts.priceLarge)
                        .contentTransition(.numericText())
                    Text("€/L")
                        .font(Theme.Fonts.title3)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }

                Text(preferences.selectedFuelType.displayName)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.8))
                    .clipShape(Capsule())
            } else {
                Text("Sin precio para \(preferences.selectedFuelType.displayName)")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
        .background(Theme.Colors.priceCardGradient)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(station.name)
                .font(Theme.Fonts.title)

            Text(station.address)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.secondaryLabel)

            HStack(spacing: Theme.Spacing.md) {
                Label(station.municipality, systemImage: "mappin")
                if let distance {
                    Label(distance.distanceFormatted, systemImage: "location.fill")
                }
            }
            .font(Theme.Fonts.caption)
            .foregroundStyle(Theme.Colors.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Comparison

    private var comparisonSection: some View {
        Group {
            if let selectedPrice, let averagePrice {
                let saving = store.estimatedSaving(
                    stationPrice: selectedPrice,
                    averagePrice: averagePrice,
                    tankLiters: preferences.tankSizeLiters
                )
                let worthIt = store.worthItLevel(saving: saving)

                VStack(spacing: Theme.Spacing.md) {
                    HStack(spacing: 0) {
                        ComparisonMetric(
                            label: "Media zona",
                            value: "\(averagePrice.priceFormatted) €/L",
                            color: Theme.Colors.label
                        )

                        Divider()
                            .frame(height: 36)

                        ComparisonMetric(
                            label: "Ahorro depósito",
                            value: saving > 0 ? "-\(saving.savingFormatted)" : saving.savingFormatted,
                            color: saving > 0 ? Theme.Colors.saving : Theme.Colors.label
                        )
                    }

                    HStack(spacing: 6) {
                        Image(systemName: worthIt.icon)
                            .font(.system(size: 12))
                        Text(worthIt.message)
                            .font(.system(size: 13, weight: .medium))
                        Text("(\(Int(preferences.tankSizeLiters)) L)")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Colors.tertiaryLabel)
                    }
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                }
                .sectionCard()
            }
        }
    }

    // MARK: - All Prices

    private var allPricesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Todos los precios")
                .font(Theme.Fonts.headline)

            VStack(spacing: 0) {
                ForEach(FuelType.allCases) { fuel in
                    if let price = station.price(for: fuel) {
                        let isSelected = fuel == preferences.selectedFuelType
                        HStack {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: fuel.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                                    .frame(width: 20)
                                Text(fuel.displayName)
                                    .font(isSelected ? Theme.Fonts.headline : Theme.Fonts.body)
                            }
                            Spacer()
                            Text("\(price.priceFormatted) €/L")
                                .font(Theme.Fonts.priceSmall)
                                .foregroundStyle(isSelected ? Color.accentColor : Theme.Colors.secondaryLabel)
                        }
                        .padding(.vertical, 10)

                        if fuel != FuelType.allCases.last(where: { station.price(for: $0) != nil }) {
                            Divider()
                        }
                    }
                }
            }
        }
        .sectionCard()
    }

    // MARK: - Navigation

    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Cómo llegar")
                .font(Theme.Fonts.headline)

            HStack(spacing: Theme.Spacing.sm) {
                NavButton(title: "Apple Maps", icon: "apple.logo", color: .primary) {
                    openAppleMaps()
                }
                NavButton(title: "Google", icon: "globe", color: .blue) {
                    openGoogleMaps()
                }
                NavButton(title: "Waze", icon: "car.fill", color: .cyan) {
                    openWaze()
                }
            }
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Label(
                station.lastUpdated.formatted(.dateTime.day().month().hour().minute()),
                systemImage: "clock"
            )
            Label("Ministerio", systemImage: "building.columns")
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.Colors.tertiaryLabel)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

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

// MARK: - Supporting Views

private struct ComparisonMetric: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .textCase(.uppercase)
                .tracking(0.3)
            Text(value)
                .font(Theme.Fonts.priceSmall)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct NavButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Colors.label)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
