import WidgetKit
import SwiftUI

// MARK: - Entry

struct CheapestStationEntry: TimelineEntry {
    let date: Date
    let data: WidgetStationData?
    let isDark: Bool
}

// MARK: - Provider

struct CheapestStationProvider: TimelineProvider {
    let isDark: Bool

    func placeholder(in context: Context) -> CheapestStationEntry {
        CheapestStationEntry(date: .now, data: .placeholder, isDark: isDark)
    }

    func getSnapshot(in context: Context, completion: @escaping (CheapestStationEntry) -> Void) {
        let data = readWidgetData()
        completion(CheapestStationEntry(date: .now, data: data ?? .placeholder, isDark: isDark))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CheapestStationEntry>) -> Void) {
        let data = readWidgetData()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let entry = CheapestStationEntry(date: .now, data: data, isDark: isDark)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func readWidgetData() -> WidgetStationData? {
        guard let defaults = UserDefaults(suiteName: WidgetConstants.appGroupId),
              let data = defaults.data(forKey: WidgetConstants.widgetDataKey),
              let decoded = try? JSONDecoder().decode(WidgetStationData.self, from: data) else {
            return nil
        }
        return decoded
    }
}

// MARK: - Dark Widget

struct CheapestStationDarkWidget: Widget {
    let kind = "CheapestStationDarkWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CheapestStationProvider(isDark: true)) { entry in
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
        StaticConfiguration(kind: kind, provider: CheapestStationProvider(isDark: false)) { entry in
            CheapestStationWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(WidgetLoc.lightWidgetName)
        .description(WidgetLoc.lightWidgetDesc)
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
