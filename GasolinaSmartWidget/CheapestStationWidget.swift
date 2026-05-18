import AppIntents
import WidgetKit
import SwiftUI

// MARK: - Entry

struct CheapestStationEntry: TimelineEntry {
    let date: Date
    let data: WidgetStationData?
    let isDark: Bool
}

// MARK: - Provider (configurable via App Intents)

struct ConfigurableCheapestProvider: AppIntentTimelineProvider {
    typealias Intent = CheapestStationConfigurationIntent
    typealias Entry = CheapestStationEntry

    let isDark: Bool

    func placeholder(in context: Context) -> CheapestStationEntry {
        CheapestStationEntry(date: .now, data: .placeholder, isDark: isDark)
    }

    func snapshot(for configuration: CheapestStationConfigurationIntent, in context: Context) async -> CheapestStationEntry {
        let data = readWidgetData(for: configuration) ?? .placeholder
        return CheapestStationEntry(date: .now, data: data, isDark: isDark)
    }

    func timeline(for configuration: CheapestStationConfigurationIntent, in context: Context) async -> Timeline<CheapestStationEntry> {
        let data = readWidgetData(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let entry = CheapestStationEntry(date: .now, data: data, isDark: isDark)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    /// Resolves which snapshot key to read for the given configuration.
    /// Vehicle wins over fuel (a vehicle already implies a fuel); both
    /// blank falls back to the default key — same behaviour as the old
    /// static widget.
    private func readWidgetData(for configuration: CheapestStationConfigurationIntent) -> WidgetStationData? {
        guard let defaults = UserDefaults(suiteName: WidgetConstants.appGroupId) else { return nil }

        let key: String
        if let vehicle = configuration.vehicle {
            key = WidgetConstants.vehicleSnapshotKey(vehicle.id)
        } else if let fuel = configuration.fuel {
            key = WidgetConstants.fuelSnapshotKey(fuel.id)
        } else {
            key = WidgetConstants.widgetDataKey
        }

        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(WidgetStationData.self, from: data) {
            return decoded
        }
        // Fall back to the default snapshot when the configured-for snapshot
        // hasn't been computed yet (e.g. brand-new vehicle, app hasn't run
        // since adding it).
        if let data = defaults.data(forKey: WidgetConstants.widgetDataKey),
           let decoded = try? JSONDecoder().decode(WidgetStationData.self, from: data) {
            return decoded
        }
        return nil
    }
}

// MARK: - Dark Widget

struct CheapestStationDarkWidget: Widget {
    let kind = "CheapestStationDarkWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: CheapestStationConfigurationIntent.self,
            provider: ConfigurableCheapestProvider(isDark: true)
        ) { entry in
            CheapestStationWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(WidgetLoc.darkWidgetName)
        .description(WidgetLoc.darkWidgetDesc)
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Light Widget

struct CheapestStationLightWidget: Widget {
    let kind = "CheapestStationLightWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: CheapestStationConfigurationIntent.self,
            provider: ConfigurableCheapestProvider(isDark: false)
        ) { entry in
            CheapestStationWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(WidgetLoc.lightWidgetName)
        .description(WidgetLoc.lightWidgetDesc)
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
