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
                VStack(spacing: 0) {
                    heroSection
                    connectionsCard
                    infoRows
                    navigateButton
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.charging)
                        .frame(width: 44, height: 44)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(station.operatorName)
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.3)
                    Text(loc.chargingSpeedLabel(station.speedCategory))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.charging)
                }
            }

            Text(station.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))
                .padding(.top, 4)

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var connectionsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(loc.chargingConnectors)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(.tertiaryLabel))
                .tracking(1)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ForEach(Array(station.connections.enumerated()), id: \.offset) { index, conn in
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Theme.Colors.charging.opacity(isDark ? 0.15 : 0.08))
                                .frame(width: 28, height: 28)
                            Image(systemName: "ev.plug.dc.ccs1")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.Colors.charging)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(conn.typeName)
                                .font(.system(size: 14, weight: .semibold))
                            if let qty = conn.quantity, qty > 1 {
                                Text(loc.chargingPointCount(qty))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color(.tertiaryLabel))
                            }
                        }

                        Spacer()

                        if let power = conn.powerKW {
                            Text("\(Int(power)) kW")
                                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(Theme.Colors.charging)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)

                    if index < station.connections.count - 1 {
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

    private var infoRows: some View {
        VStack(spacing: 0) {
            infoRow(
                icon: "number",
                label: loc.chargingPoints,
                value: "\(station.numberOfPoints)",
                valueColor: Theme.Colors.charging
            )

            if let maxPower = station.maxPowerKW {
                infoRow(
                    icon: "bolt.fill",
                    label: loc.chargingMaxPower,
                    value: "\(Int(maxPower)) kW",
                    valueColor: Theme.Colors.charging
                )
            }

            if let cost = station.usageCost, !cost.isEmpty {
                infoRow(
                    icon: "eurosign.circle.fill",
                    label: loc.chargingCost,
                    value: cost,
                    valueColor: nil
                )
            }

            if !station.town.isEmpty {
                infoRow(
                    icon: "building.2.fill",
                    label: loc.chargingMunicipality,
                    value: station.town,
                    valueColor: nil
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
        .padding(.bottom, 12)
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
