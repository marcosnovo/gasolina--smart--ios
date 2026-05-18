import SwiftUI
import CoreLocation

struct ChargingStationDetailView: View {
    let station: ChargingStation
    @Environment(LocationManager.self) private var locationManager
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    private var distance: Double? {
        guard let location = locationManager.location else { return nil }
        return station.distanceKm(from: location)
    }

    private var loc: Loc { preferences.loc }
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    heroSection
                    priceCard
                    connectorsCard
                    infoCard
                    navigateButton
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.charging)
                        .frame(width: 48, height: 48)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(station.operatorName.isEmpty ? station.name : station.operatorName)
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.3)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(speedColor)
                            .frame(width: 7, height: 7)
                        Text(loc.chargingSpeedLabel(station.speedCategory))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(speedColor)
                        if !station.isOperational {
                            Text("·")
                                .foregroundStyle(Color(.quaternaryLabel))
                            Text("Fuera de servicio")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.red)
                        }
                    }
                }
            }

            if !station.name.isEmpty && station.name != station.operatorName {
                Text(station.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.top, 4)
            }

            if !station.address.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.charging)
                    Text(station.address)
                        .foregroundStyle(Color(.secondaryLabel))
                    if let distance {
                        Text("·")
                            .foregroundStyle(Color(.quaternaryLabel))
                        Text(distance.distanceFormatted)
                            .foregroundStyle(Theme.Colors.charging)
                            .fontWeight(.semibold)
                    }
                }
                .font(.system(size: 13, weight: .medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    // MARK: - Price + power highlight

    @ViewBuilder
    private var priceCard: some View {
        HStack(spacing: 12) {
            priceTile
            powerTile
        }
        .padding(.horizontal, 16)
    }

    private var priceTile: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Precio")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(.tertiaryLabel))
                .tracking(0.8)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if station.isFree {
                    Text("Gratis")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.10, green: 0.55, blue: 0.20))
                } else if let price = station.pricePerKWh {
                    Text(price.priceFormatted)
                        .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color(.label))
                    Text("€/kWh")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(.secondaryLabel))
                } else {
                    Text("—")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(.tertiaryLabel))
                    Text("sin datos")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
            if let cost = station.usageCost, !station.isFree, station.pricePerKWh == nil {
                Text(cost)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var powerTile: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Potencia máx.")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(.tertiaryLabel))
                .tracking(0.8)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let maxPower = station.maxPowerKW {
                    Text("\(Int(maxPower.rounded()))")
                        .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.Colors.charging)
                    Text("kW")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(.secondaryLabel))
                } else {
                    Text("—")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
            Text(loc.chargingPointCount(station.numberOfPoints))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Connectors

    private var connectorsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(loc.chargingConnectors)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(.tertiaryLabel))
                .tracking(1)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                spacing: 10
            ) {
                ForEach(Array(station.connections.enumerated()), id: \.offset) { _, conn in
                    connectorTile(conn)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func connectorTile(_ conn: ChargingConnection) -> some View {
        let visual = ConnectorVisual.from(typeName: conn.typeName)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(visual.color.opacity(isDark ? 0.25 : 0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: visual.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(visual.color)
                }
                Spacer()
                if let power = conn.powerKW {
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("\(Int(power)) kW")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(visual.color)
                    .clipShape(Capsule())
                }
            }

            Text(visual.shortName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(.label))
                .lineLimit(1)

            if let qty = conn.quantity, qty > 1 {
                Text(loc.chargingPointCount(qty))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Info

    private var infoCard: some View {
        VStack(spacing: 0) {
            if !station.town.isEmpty {
                infoRow(
                    icon: "building.2.fill",
                    label: loc.chargingMunicipality,
                    value: station.town,
                    valueColor: nil,
                    isLast: distance == nil
                )
            }

            if let distance {
                infoRow(
                    icon: "location.fill",
                    label: loc.detailDistance,
                    value: distance.distanceFormatted,
                    valueColor: Theme.Colors.charging,
                    isLast: true
                )
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func infoRow(icon: String, label: String, value: String, valueColor: Color?, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.Colors.charging.opacity(isDark ? 0.15 : 0.08))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Colors.charging)
                }

                Text(label)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))

                Spacer()

                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(valueColor ?? Color(.label))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if !isLast {
                Divider()
                    .padding(.leading, 54)
            }
        }
    }

    // MARK: - Helpers

    private var speedColor: Color {
        switch station.speedCategory {
        case .fast: Color(red: 0.10, green: 0.55, blue: 0.20)
        case .semiFast: Color(red: 0.85, green: 0.55, blue: 0.10)
        case .slow: Color(red: 0.55, green: 0.55, blue: 0.55)
        case .unknown: Color(.secondaryLabel)
        }
    }

    private var navigateButton: some View {
        Button {
            let coordinate = station.coordinate
            let app = preferences.preferredNavigationApp
            let url = NavigationHelper.navigationURL(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                app: app
            )
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 15, weight: .bold))
                Text(loc.navigate)
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.Colors.charging)
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}

/// Maps an OpenChargeMap connector typeName to an SF Symbol and brand colour
/// so the connector grid is glanceable. Falls back to a neutral plug when the
/// type isn't recognised — better than showing the same generic icon for all.
private struct ConnectorVisual {
    let symbol: String
    let color: Color
    let shortName: String

    static func from(typeName raw: String) -> ConnectorVisual {
        let name = raw.lowercased()
        if name.contains("ccs") {
            return .init(symbol: "ev.plug.dc.ccs2", color: Color(red: 0.20, green: 0.45, blue: 0.85), shortName: "CCS")
        }
        if name.contains("chademo") {
            return .init(symbol: "ev.plug.dc.chademo", color: Color(red: 0.85, green: 0.45, blue: 0.10), shortName: "CHAdeMO")
        }
        if name.contains("nacs") || name.contains("j3400") {
            return .init(symbol: "ev.plug.dc.nacs", color: Color(red: 0.80, green: 0.20, blue: 0.20), shortName: "NACS")
        }
        if name.contains("tesla") {
            return .init(symbol: "ev.plug.dc.nacs", color: Color(red: 0.80, green: 0.20, blue: 0.20), shortName: "Tesla")
        }
        if name.contains("type 2") || name.contains("mennekes") || name.contains("iec 62196-2") {
            return .init(symbol: "ev.plug.ac.type2", color: Color(red: 0.10, green: 0.55, blue: 0.20), shortName: "Type 2")
        }
        if name.contains("type 1") || name.contains("j1772") {
            return .init(symbol: "ev.plug.ac.gb.t", color: Color(red: 0.60, green: 0.30, blue: 0.70), shortName: "Type 1")
        }
        if name.contains("schuko") || name.contains("domestic") {
            return .init(symbol: "powerplug.fill", color: Color(red: 0.40, green: 0.40, blue: 0.40), shortName: "Schuko")
        }
        if name.contains("cee") {
            return .init(symbol: "powerplug.fill", color: Color(red: 0.85, green: 0.55, blue: 0.10), shortName: "CEE")
        }
        return .init(symbol: "powerplug.fill", color: Color(.secondaryLabel), shortName: raw)
    }
}
