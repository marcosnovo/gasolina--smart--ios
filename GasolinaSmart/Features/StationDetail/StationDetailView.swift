import SwiftUI
import CoreLocation

struct StationDetailView: View {
    let station: FuelStation
    @Environment(UserPreferences.self) private var preferences
    @Environment(LocationManager.self) private var locationManager
    @Environment(StationStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var priceHistory: [DailyPriceRecord] = []
    @State private var showNavigationPicker = false

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

    private var opportunity: PriceOpportunity {
        store.priceOpportunity(
            stationPrice: selectedPrice,
            averagePrice: averagePrice,
            tankLiters: preferences.tankSizeLiters
        )
    }

    private var saving: Decimal? {
        guard let selectedPrice, let averagePrice else { return nil }
        let s = store.estimatedSaving(
            stationPrice: selectedPrice,
            averagePrice: averagePrice,
            tankLiters: preferences.tankSizeLiters
        )
        return s > 0 ? s : nil
    }

    private var loc: Loc { preferences.loc }
    private var country: Country { station.country }
    private var currencyUnit: String { preferences.selectedFuelType.unit(for: country) }
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    priceCard
                    if !priceHistory.isEmpty {
                        sparklineSection
                    }
                    infoRows
                    allPricesSection
                    actionSection
                    footerSection
                }
                .padding(.bottom, 32)
            }
            .task {
                priceHistory = await PriceHistoryStore.shared.history(
                    for: preferences.selectedFuelType,
                    country: preferences.selectedCountry,
                    radiusKm: preferences.preferredRadiusKm
                )
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        preferences.toggleFavorite(station.id)
                    } label: {
                        Image(systemName: preferences.isFavorite(station.id) ? "star.fill" : "star")
                            .font(.system(size: 17, weight: .medium))
                            .symbolEffect(.bounce, value: preferences.isFavorite(station.id))
                            .foregroundStyle(preferences.isFavorite(station.id) ? .yellow : Color(.tertiaryLabel))
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(station.brand)
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Color(.label))

            Text(station.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))

            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.accent)
                Text(station.address)
                    .foregroundStyle(Color(.secondaryLabel))
                if let distance {
                    Text("·")
                        .foregroundStyle(Color(.quaternaryLabel))
                    Text(distance.distanceFormatted)
                        .foregroundStyle(Theme.Colors.accent)
                        .fontWeight(.semibold)
                }
            }
            .font(.system(size: 13, weight: .medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Price Card

    private var priceCard: some View {
        VStack(spacing: 14) {
            if let selectedPrice {
                HStack(alignment: .center) {
                    // Left: fuel circle + fuel type
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.accent)
                                .frame(width: 44, height: 44)
                            Image(systemName: "fuelpump.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        Text(preferences.selectedFuelType.shortLabel(for: country))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Colors.accent)
                    }
                    .padding(.trailing, 14)

                    // Center: price
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(selectedPrice.priceFormatted)
                                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(Color(.label))
                            Text(currencyUnit)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }

                        HStack(spacing: 6) {
                            Circle()
                                .fill(opportunity.color)
                                .frame(width: 7, height: 7)
                            Text(loc.opportunityLabel(opportunity))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(opportunity.color)
                        }
                    }

                    Spacer()
                }

                if let saving {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 13))
                        Text(loc.detailSaving(saving.savingFormatted))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.accent.opacity(isDark ? 0.15 : 0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(18)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Theme.Colors.accent.opacity(0),
                            Theme.Colors.accent.opacity(isDark ? 0.15 : 0.07)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 70)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Sparkline

    private var sparklineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(loc.detailTrend)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .tracking(1)
                Spacer()
                Text(loc.detailDays(priceHistory.count))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
            }

            Text(loc.detailTrendCaption(preferences.preferredRadiusKm))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))

            SparklineView(
                values: priceHistory.map(\.averagePrice),
                color: Theme.Colors.accent,
                height: 56
            )

            HStack {
                let prices = priceHistory.map(\.averagePrice)
                if let minP = prices.min(), let maxP = prices.max() {
                    Text(String(format: "%.3f", minP))
                        .foregroundStyle(Theme.Colors.goodPrice)
                    Spacer()
                    Text(String(format: "%.3f", maxP))
                        .foregroundStyle(Theme.Colors.expensivePrice)
                }
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Info Rows

    private var infoRows: some View {
        VStack(spacing: 0) {
            if let averagePrice {
                infoRow(
                    icon: "chart.bar.fill",
                    label: loc.detailZoneAvg,
                    value: "\(averagePrice.priceFormatted) \(currencyUnit)",
                    valueColor: nil
                )
            }

            if let selectedPrice {
                let costPer100 = selectedPrice * Decimal(preferences.consumptionL100Km)
                infoRow(
                    icon: "gauge.with.dots.needle.67percent",
                    label: loc.detailCost100km,
                    value: costPer100.savingFormatted,
                    valueColor: Theme.Colors.accent
                )
            }

            infoRow(
                icon: "fuelpump.fill",
                label: loc.tank,
                value: "\(Int(preferences.tankSizeLiters)) L · \(String(format: "%.1f", preferences.consumptionL100Km)) L/100km",
                valueColor: nil
            )

            if let selectedPrice {
                let total = selectedPrice * Decimal(preferences.tankSizeLiters)
                infoRow(
                    icon: "creditcard.fill",
                    label: loc.detailFillTank,
                    value: total.savingFormatted,
                    valueColor: nil
                )
            }

            if let distance {
                infoRow(
                    icon: "location.fill",
                    label: loc.detailDistance,
                    value: distance.distanceFormatted,
                    valueColor: Theme.Colors.accent,
                    isLast: true
                )
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func infoRow(icon: String, label: String, value: String, valueColor: Color?, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.Colors.accent.opacity(isDark ? 0.15 : 0.08))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Colors.accent)
                }

                Text(label)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))

                Spacer()

                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(valueColor ?? Color(.label))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if !isLast {
                Divider()
                    .padding(.leading, 54)
            }
        }
    }

    // MARK: - All Prices

    private var allPricesSection: some View {
        let visibleFuels = country.supportedFuelTypes.compactMap { fuel -> (FuelType, Decimal)? in
            guard let price = station.price(for: fuel) else { return nil }
            return (fuel, price)
        }

        return VStack(alignment: .leading, spacing: 0) {
            Text(loc.detailPrices)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(.tertiaryLabel))
                .tracking(1)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ForEach(Array(visibleFuels.enumerated()), id: \.element.0.id) { index, item in
                let (fuel, price) = item
                let isSelected = fuel == preferences.selectedFuelType
                let isLast = index == visibleFuels.count - 1

                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isSelected ? Theme.Colors.accent : Theme.Colors.accent.opacity(isDark ? 0.1 : 0.05))
                                .frame(width: 28, height: 28)
                            Image(systemName: fuel.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(isSelected ? .white : Color(.tertiaryLabel))
                        }

                        Text(fuel.displayName(for: country))
                            .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(Color(.label))

                        Spacer()

                        Text("\(price.priceFormatted) \(fuel.unit(for: country))")
                            .font(.system(size: 15, weight: isSelected ? .bold : .regular, design: .rounded).monospacedDigit())
                            .foregroundStyle(isSelected ? Theme.Colors.accent : Color(.secondaryLabel))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(isSelected ? Theme.Colors.accent.opacity(isDark ? 0.1 : 0.05) : .clear)

                    if !isLast {
                        Divider()
                            .padding(.leading, 54)
                    }
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Action

    private var actionSection: some View {
        Button {
            if preferences.enabledNavigationApps.count == 1,
               let app = preferences.enabledNavigationApps.first {
                NavigationHelper.openPreferred(station: station, app: app)
            } else {
                showNavigationPicker = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 15, weight: .bold))
                Text(loc.navigate)
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.Colors.accent)
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .sheet(isPresented: $showNavigationPicker) {
            let apps = preferences.enabledNavigationApps.isEmpty
                ? Set(PreferredNavigationApp.allCases)
                : preferences.enabledNavigationApps
            NavigationPickerSheet(station: station, availableApps: apps)
                .presentationDetents([.height(180)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 5) {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
            Text("\(station.municipality) · \(station.lastUpdated.formatted(.dateTime.day().month().hour().minute())) · \(country.flag)")
                .font(.system(size: 10))
        }
        .foregroundStyle(Color(.quaternaryLabel))
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
