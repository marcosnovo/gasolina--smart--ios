import SwiftUI
import CoreLocation

struct StationDetailView: View {
    let station: FuelStation
    @Environment(UserPreferences.self) private var preferences
    @Environment(LocationManager.self) private var locationManager
    @Environment(StationStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
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

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    priceCard
                    infoRows
                    allPricesSection
                    actionSection
                    footerSection
                }
                .padding(.bottom, 32)
            }
            .background(isDark ? Color.black : Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        preferences.toggleFavorite(station.id)
                    } label: {
                        Image(systemName: preferences.isFavorite(station.id) ? "heart.fill" : "heart")
                            .font(.system(size: 17, weight: .medium))
                            .symbolEffect(.bounce, value: preferences.isFavorite(station.id))
                            .foregroundStyle(preferences.isFavorite(station.id) ? .red : Color(.tertiaryLabel))
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(station.brand)
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(isDark ? .white : Color(.label))

            Text(station.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))

            HStack(spacing: 5) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.accent)
                Text(station.address)
                if let distance {
                    Text("·")
                        .foregroundStyle(Color(.quaternaryLabel))
                    Text(distance.distanceFormatted)
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Price Card

    private var priceCard: some View {
        VStack(spacing: 12) {
            if let selectedPrice {
                HStack(alignment: .firstTextBaseline) {
                    Text(selectedPrice.priceFormatted)
                        .font(.system(size: 52, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.Colors.accent)

                    Text("€/L")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isDark ? Color(.tertiaryLabel) : Color(.secondaryLabel))

                    Spacer()
                }

                HStack(spacing: 8) {
                    Text(preferences.selectedFuelType.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.accent.opacity(isDark ? 0.2 : 0.12))
                        .foregroundStyle(Theme.Colors.accent)
                        .clipShape(Capsule())

                    opportunityBadge

                    Spacer()
                }
            }
        }
        .padding(20)
        .background(isDark ? Color(white: 0.08) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var opportunityBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(opportunity.color)
                .frame(width: 6, height: 6)
            Text(opportunity.label)
                .font(.system(size: 11, weight: .semibold))

            if let selectedPrice, let averagePrice {
                let saving = store.estimatedSaving(
                    stationPrice: selectedPrice,
                    averagePrice: averagePrice,
                    tankLiters: preferences.tankSizeLiters
                )
                if saving > 0 {
                    Text("· -\(saving.savingFormatted)")
                        .font(.system(size: 11, weight: .medium))
                }
            }
        }
        .foregroundStyle(opportunity.color)
    }

    // MARK: - Info Rows

    private var infoRows: some View {
        VStack(spacing: 0) {
            if let averagePrice {
                infoRow(
                    icon: "chart.bar.fill",
                    label: "Media zona",
                    value: "\(averagePrice.priceFormatted) €/L",
                    valueColor: nil
                )
            }

            infoRow(
                icon: "fuelpump.fill",
                label: "Depósito",
                value: "\(Int(preferences.tankSizeLiters)) L",
                valueColor: nil
            )

            if let selectedPrice {
                let total = selectedPrice * Decimal(preferences.tankSizeLiters)
                infoRow(
                    icon: "creditcard.fill",
                    label: "Llenar depósito",
                    value: total.savingFormatted,
                    valueColor: Theme.Colors.accent
                )
            }

            if let distance {
                infoRow(
                    icon: "location.fill",
                    label: "Distancia",
                    value: distance.distanceFormatted,
                    valueColor: nil,
                    isLast: true
                )
            }
        }
        .background(isDark ? Color(white: 0.08) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func infoRow(icon: String, label: String, value: String, valueColor: Color?, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isDark ? Theme.Colors.accent : Color(.tertiaryLabel))
                    .frame(width: 20, alignment: .center)

                Text(label)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(isDark ? Color(white: 0.7) : Color(.secondaryLabel))

                Spacer()

                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(valueColor ?? (isDark ? .white : Color(.label)))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !isLast {
                Divider()
                    .padding(.leading, 48)
            }
        }
    }

    // MARK: - All Prices

    private var allPricesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PRECIOS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(.tertiaryLabel))
                .tracking(1)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ForEach(Array(FuelType.allCases.enumerated()), id: \.element.id) { index, fuel in
                if let price = station.price(for: fuel) {
                    let isSelected = fuel == preferences.selectedFuelType
                    let isLastPrice = isLastVisibleFuel(fuel)

                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: fuel.icon)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(isSelected ? Theme.Colors.accent : (isDark ? Color(white: 0.4) : Color(.tertiaryLabel)))
                                .frame(width: 20, alignment: .center)

                            Text(fuel.displayName)
                                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isDark ? .white : Color(.label))

                            Spacer()

                            Text("\(price.priceFormatted) €/L")
                                .font(.system(size: 15, weight: isSelected ? .bold : .regular, design: .rounded).monospacedDigit())
                                .foregroundStyle(isSelected ? Theme.Colors.accent : (isDark ? Color(white: 0.5) : Color(.secondaryLabel)))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(isSelected ? Theme.Colors.accent.opacity(isDark ? 0.12 : 0.06) : .clear)

                        if !isLastPrice {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                }
            }
        }
        .background(isDark ? Color(white: 0.08) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func isLastVisibleFuel(_ fuel: FuelType) -> Bool {
        let visibleFuels = FuelType.allCases.filter { station.price(for: $0) != nil }
        return visibleFuels.last == fuel
    }

    // MARK: - Action

    private var actionSection: some View {
        Button { showNavigationPicker = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("Cómo llegar")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.Colors.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .sheet(isPresented: $showNavigationPicker) {
            NavigationPickerSheet(station: station)
                .presentationDetents([.height(180)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 5) {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
            Text("\(station.municipality) · \(station.lastUpdated.formatted(.dateTime.day().month().hour().minute())) · Ministerio de Industria")
                .font(.system(size: 10))
        }
        .foregroundStyle(Color(.quaternaryLabel))
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
