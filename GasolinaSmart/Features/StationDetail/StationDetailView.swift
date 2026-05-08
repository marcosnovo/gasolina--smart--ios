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
                VStack(spacing: Theme.Spacing.md) {
                    priceAndInfoSection
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
                ToolbarItem(placement: .topBarLeading) {
                    Text(station.brand)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Colors.secondaryLabel)
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

    // MARK: - Price + Info combined

    private var priceAndInfoSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(station.name)
                        .font(Theme.Fonts.title)
                        .lineLimit(2)

                    Text(station.address)
                        .font(Theme.Fonts.subheadline)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .lineLimit(2)

                    HStack(spacing: Theme.Spacing.md) {
                        Label(station.municipality, systemImage: "mappin")
                        if let distance {
                            Label(distance.distanceFormatted, systemImage: "location.fill")
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.tertiaryLabel)
                }

                Spacer(minLength: Theme.Spacing.sm)

                if let selectedPrice {
                    VStack(spacing: 2) {
                        Text(selectedPrice.priceFormatted)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("€/L")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                        Text(preferences.selectedFuelType.shortLabel)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                            .padding(.top, 2)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
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

                HStack(spacing: 0) {
                    ComparisonMetric(
                        label: "Media zona",
                        value: "\(averagePrice.priceFormatted)",
                        unit: "€/L",
                        color: Theme.Colors.label
                    )

                    Divider().frame(height: 40)

                    ComparisonMetric(
                        label: "Ahorro depósito",
                        value: saving > 0 ? "-\(saving.savingFormatted)" : saving.savingFormatted,
                        unit: nil,
                        color: saving > 0 ? Theme.Colors.saving : Theme.Colors.label
                    )

                    Divider().frame(height: 40)

                    VStack(spacing: 4) {
                        Image(systemName: worthIt.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(saving > 0 ? Theme.Colors.saving : Theme.Colors.secondaryLabel)
                        Text(worthIt.shortMessage)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, Theme.Spacing.md)
                .padding(.horizontal, Theme.Spacing.sm)
                .background(Theme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            }
        }
    }

    // MARK: - All Prices

    private var allPricesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Todos los precios")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .textCase(.uppercase)
                .tracking(0.3)

            VStack(spacing: 0) {
                ForEach(FuelType.allCases) { fuel in
                    if let price = station.price(for: fuel) {
                        let isSelected = fuel == preferences.selectedFuelType
                        HStack {
                            HStack(spacing: 10) {
                                Image(systemName: fuel.icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                                    .frame(width: 18)
                                Text(fuel.displayName)
                                    .font(isSelected ? .system(size: 15, weight: .semibold) : .system(size: 15))
                            }
                            Spacer()
                            Text("\(price.priceFormatted) €/L")
                                .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded))
                                .foregroundStyle(isSelected ? Color.accentColor : Theme.Colors.secondaryLabel)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, Theme.Spacing.md)
                        .background(isSelected ? Color.accentColor.opacity(0.06) : .clear)

                        if fuel != FuelType.allCases.last(where: { station.price(for: $0) != nil }) {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
            .background(Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        }
    }

    // MARK: - Navigation

    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Cómo llegar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .textCase(.uppercase)
                .tracking(0.3)

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
        .padding(.top, Theme.Spacing.xs)
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
    let unit: String?
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.Colors.tertiaryLabel)
                .textCase(.uppercase)
                .tracking(0.3)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                if let unit {
                    Text(unit)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.tertiaryLabel)
                }
            }
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
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Colors.label)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
