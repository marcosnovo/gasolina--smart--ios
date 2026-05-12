import WidgetKit
import SwiftUI

struct CheapestStationEntry: TimelineEntry {
    let date: Date
    let data: WidgetStationData?
}

struct CheapestStationProvider: TimelineProvider {
    func placeholder(in context: Context) -> CheapestStationEntry {
        CheapestStationEntry(date: .now, data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CheapestStationEntry) -> Void) {
        let data = readWidgetData()
        completion(CheapestStationEntry(date: .now, data: data ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CheapestStationEntry>) -> Void) {
        let data = readWidgetData()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let entry = CheapestStationEntry(date: .now, data: data)
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

struct CheapestStationWidget: Widget {
    let kind = "CheapestStationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CheapestStationProvider()) { entry in
            CheapestStationWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("Gasolinera barata")
        .description("Precio y navegación a la gasolinera más barata cerca de ti.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
