import SwiftUI

struct RadarPanel: View {
    let station: FuelStation
    let fuelType: FuelType
    let averagePrice: Decimal?
    let tankLiters: Double
    let distance: Double
    let onTap: () -> Void
    let onNavigate: () -> Void

    @Environment(StationStore.self) private var store
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    private var loc: Loc { preferences.loc }

    private var price: Decimal? {
        station.price(for: fuelType)
    }

    private var opportunity: PriceOpportunity {
        store.priceOpportunity(
            stationPrice: price,
            averagePrice: averagePrice,
            tankLiters: tankLiters
        )
    }

    private var saving: Decimal? {
        guard let price, let averagePrice else { return nil }
        let s = (averagePrice - price) * Decimal(tankLiters)
        return s > 0 ? s : nil
    }

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        HStack(spacing: 0) {
            // Left: saving badge + fuel circle + price pill
            VStack(spacing: 0) {
                if let saving {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 9))
                        Text(saving.savingFormatted)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Theme.Colors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isDark ? Color.black.opacity(0.4) : Color.white.opacity(0.85))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(isDark ? .white.opacity(0.1) : .black.opacity(0.06), lineWidth: 0.5))
                    .padding(.bottom, 6)
                }

                if let price {
                    Button(action: onTap) {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.accent)
                                    .frame(width: 56, height: 56)
                                VStack(spacing: 1) {
                                    Image(systemName: "fuelpump.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text(fuelType.shortLabel(for: station.country))
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundStyle(.white)
                            }

                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(price.priceFormatted)
                                    .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                                Text(fuelType.unit(for: station.country))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(isDark ? .black.opacity(0.4) : .white.opacity(0.5))
                            }
                            .foregroundStyle(isDark ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(isDark ? .white : Color(white: 0.12))
                            .clipShape(Capsule())
                            .padding(.top, -10)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 120)

            // Right: station info + opportunity + navigate
            VStack(alignment: .trailing, spacing: 0) {
                Text(station.brand)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                HStack(spacing: 0) {
                    Text(station.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text("  \(distance.distanceFormatted)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(.secondaryLabel))
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                .foregroundStyle(Color(.label))
                .minimumScaleFactor(0.8)
                .padding(.top, 2)

                HStack(spacing: 5) {
                    Circle()
                        .fill(opportunity.color)
                        .frame(width: 6, height: 6)
                    Text(loc.opportunityLabel(opportunity))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(opportunity.color)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 3)
                .padding(.bottom, 12)

                Button(action: onNavigate) {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(loc.navigate)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Theme.Colors.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 16)
        }
        .padding(.leading, 10)
        .padding(.vertical, 14)
        .background(
            ZStack {
                Color.clear
                HStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Theme.Colors.accent.opacity(0),
                            Theme.Colors.accent.opacity(isDark ? 0.30 : 0.10),
                            Theme.Colors.accent.opacity(isDark ? 0.50 : 0.20),
                            Theme.Colors.accent.opacity(isDark ? 0.70 : 0.32)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 200)
                }
            }
        )
    }
}

typealias CheapestStationCard = RadarPanel

/// EV version of RadarPanel: shows the cheapest (or fastest) charging station
/// nearby, with €/kWh prominent and max kW alongside. Mirrors RadarPanel's
/// visual structure so an EV user gets the same kind of glanceable info.
struct ChargingRadarPanel: View {
    let station: ChargingStation
    let averagePricePerKWh: Decimal?
    let distance: Double
    let onTap: () -> Void
    let onNavigate: () -> Void

    @Environment(UserPreferences.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    private var loc: Loc { preferences.loc }
    private var isDark: Bool { colorScheme == .dark }

    private var pricePerKWh: Decimal? { station.pricePerKWh }

    /// Saving vs the zone average for a full charge of this vehicle's battery.
    /// Falls back to per-kWh saving if the user hasn't set a battery capacity.
    private var savingForFullCharge: Decimal? {
        guard let price = pricePerKWh, let avg = averagePricePerKWh else { return nil }
        let diff = avg - price
        guard diff > 0 else { return nil }
        let kWh = preferences.selectedVehicle.batteryCapacityKWh ?? 50
        return diff * Decimal(kWh)
    }

    private var fullChargeCost: Decimal? {
        guard let price = pricePerKWh else { return nil }
        let kWh = preferences.selectedVehicle.batteryCapacityKWh ?? 50
        return price * Decimal(kWh)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                if let savingForFullCharge {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 9))
                        Text(savingForFullCharge.savingFormatted)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Theme.Colors.charging)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isDark ? Color.black.opacity(0.4) : Color.white.opacity(0.85))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(isDark ? .white.opacity(0.1) : .black.opacity(0.06), lineWidth: 0.5))
                    .padding(.bottom, 6)
                }

                Button(action: onTap) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.charging)
                                .frame(width: 56, height: 56)
                            VStack(spacing: 1) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                if let maxKW = station.maxPowerKW {
                                    Text("\(Int(maxKW.rounded())) kW")
                                        .font(.system(size: 10, weight: .bold))
                                } else {
                                    Text("EV")
                                        .font(.system(size: 11, weight: .bold))
                                }
                            }
                            .foregroundStyle(.white)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            if let price = pricePerKWh {
                                Text(price.priceFormatted)
                                    .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                                Text("€/kWh")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(isDark ? .black.opacity(0.4) : .white.opacity(0.5))
                            } else if station.isFree {
                                Text("Gratis")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            } else {
                                Text("—")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Text("€/kWh")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(isDark ? .black.opacity(0.4) : .white.opacity(0.5))
                            }
                        }
                        .foregroundStyle(isDark ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(isDark ? .white : Color(white: 0.12))
                        .clipShape(Capsule())
                        .padding(.top, -10)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(width: 120)

            VStack(alignment: .trailing, spacing: 0) {
                Text(station.operatorName.isEmpty ? station.name : station.operatorName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                HStack(spacing: 0) {
                    Text(station.town.isEmpty ? station.name : station.town)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text("  \(distance.distanceFormatted)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(.secondaryLabel))
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                .foregroundStyle(Color(.label))
                .minimumScaleFactor(0.8)
                .padding(.top, 2)

                HStack(spacing: 5) {
                    Circle()
                        .fill(speedColor)
                        .frame(width: 6, height: 6)
                    Text(loc.chargingSpeedLabel(station.speedCategory))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(speedColor)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 3)

                connectorChips
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 6)
                    .padding(.bottom, 12)

                Button(action: onNavigate) {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(loc.navigate)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Theme.Colors.charging)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 16)
        }
        .padding(.leading, 10)
        .padding(.vertical, 14)
        .background(
            ZStack {
                Color.clear
                HStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Theme.Colors.charging.opacity(0),
                            Theme.Colors.charging.opacity(isDark ? 0.30 : 0.10),
                            Theme.Colors.charging.opacity(isDark ? 0.50 : 0.20),
                            Theme.Colors.charging.opacity(isDark ? 0.70 : 0.32)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 200)
                }
            }
        )
    }

    private var speedColor: Color {
        switch station.speedCategory {
        case .fast: Color(red: 0.10, green: 0.55, blue: 0.20)
        case .semiFast: Color(red: 0.85, green: 0.55, blue: 0.10)
        case .slow: Color(red: 0.55, green: 0.55, blue: 0.55)
        case .unknown: Color(.secondaryLabel)
        }
    }

    @ViewBuilder
    private var connectorChips: some View {
        let unique = uniqueConnectorNames
        if unique.isEmpty {
            Text(loc.chargingNoInfo)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
        } else {
            HStack(spacing: 4) {
                ForEach(unique.prefix(3), id: \.self) { name in
                    let v = ChargingConnectorBadge.visual(for: name)
                    HStack(spacing: 3) {
                        Image(systemName: v.symbol)
                            .font(.system(size: 7, weight: .bold))
                        Text(v.shortName)
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(v.color)
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var uniqueConnectorNames: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for c in station.connections {
            let short = ChargingConnectorBadge.shortName(for: c.typeName)
            if seen.insert(short).inserted {
                ordered.append(c.typeName)
            }
        }
        return ordered
    }
}
