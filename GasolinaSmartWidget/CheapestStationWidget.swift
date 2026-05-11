import WidgetKit
import SwiftUI
import MapKit

struct CheapestStationEntry: TimelineEntry {
    let date: Date
    let data: WidgetStationData?
    let mapSnapshot: Data?
}

struct CheapestStationProvider: TimelineProvider {
    func placeholder(in context: Context) -> CheapestStationEntry {
        CheapestStationEntry(date: .now, data: .placeholder, mapSnapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CheapestStationEntry) -> Void) {
        let data = readWidgetData()
        if let data {
            generateSnapshot(for: data, size: context.displaySize) { imageData in
                completion(CheapestStationEntry(date: .now, data: data, mapSnapshot: imageData))
            }
        } else {
            completion(CheapestStationEntry(date: .now, data: .placeholder, mapSnapshot: nil))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CheapestStationEntry>) -> Void) {
        let data = readWidgetData()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!

        if let data {
            generateSnapshot(for: data, size: context.displaySize) { imageData in
                let entry = CheapestStationEntry(date: .now, data: data, mapSnapshot: imageData)
                completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
            }
        } else {
            let entry = CheapestStationEntry(date: .now, data: nil, mapSnapshot: nil)
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func readWidgetData() -> WidgetStationData? {
        guard let defaults = UserDefaults(suiteName: WidgetConstants.appGroupId),
              let data = defaults.data(forKey: WidgetConstants.widgetDataKey),
              let decoded = try? JSONDecoder().decode(WidgetStationData.self, from: data) else {
            return nil
        }
        return decoded
    }

    private func generateSnapshot(for data: WidgetStationData, size: CGSize, completion: @escaping (Data?) -> Void) {
        let stationCoord = CLLocationCoordinate2D(latitude: data.stationLatitude, longitude: data.stationLongitude)
        let userCoord = CLLocationCoordinate2D(latitude: data.userLatitude, longitude: data.userLongitude)

        let centerLat = (stationCoord.latitude + userCoord.latitude) / 2
        let centerLon = (stationCoord.longitude + userCoord.longitude) / 2
        let latDelta = max(abs(stationCoord.latitude - userCoord.latitude) * 2.5, 0.005)
        let lonDelta = max(abs(stationCoord.longitude - userCoord.longitude) * 2.5, 0.005)

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.traitCollection = UITraitCollection(traitsFrom: [
            UITraitCollection(displayScale: 2.0),
            UITraitCollection(userInterfaceStyle: data.isDarkMode ? .dark : .light)
        ])
        options.mapType = data.isDarkMode ? .mutedStandard : .standard
        options.pointOfInterestFilter = .excludingAll
        options.showsBuildings = true

        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { snapshot, error in
            guard let snapshot, error == nil else {
                completion(nil)
                return
            }

            let snapshotImage = snapshot.image
            let finalSize = snapshotImage.size
            let renderer = UIGraphicsImageRenderer(size: finalSize)
            let image = renderer.image { ctx in
                snapshotImage.draw(at: .zero)

                // User location dot
                let userPoint = snapshot.point(for: userCoord)
                ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 3, color: UIColor.black.withAlphaComponent(0.3).cgColor)
                ctx.cgContext.setFillColor(UIColor.white.cgColor)
                ctx.cgContext.fillEllipse(in: CGRect(
                    x: userPoint.x - 10, y: userPoint.y - 10, width: 20, height: 20
                ))
                ctx.cgContext.setShadow(offset: .zero, blur: 0)
                ctx.cgContext.setFillColor(UIColor.systemBlue.cgColor)
                ctx.cgContext.fillEllipse(in: CGRect(
                    x: userPoint.x - 6, y: userPoint.y - 6, width: 12, height: 12
                ))

                // Station pin
                let stationPoint = snapshot.point(for: stationCoord)
                let pinColor = UIColor(red: 0.13, green: 0.61, blue: 0.35, alpha: 1)
                ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: pinColor.withAlphaComponent(0.4).cgColor)
                ctx.cgContext.setFillColor(pinColor.cgColor)
                ctx.cgContext.fillEllipse(in: CGRect(
                    x: stationPoint.x - 16, y: stationPoint.y - 16, width: 32, height: 32
                ))
                ctx.cgContext.setShadow(offset: .zero, blur: 0)

                let iconConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
                if let icon = UIImage(systemName: "fuelpump.fill", withConfiguration: iconConfig) {
                    let tinted = icon.withTintColor(.white, renderingMode: .alwaysOriginal)
                    tinted.draw(at: CGPoint(
                        x: stationPoint.x - tinted.size.width / 2,
                        y: stationPoint.y - tinted.size.height / 2
                    ))
                }
            }

            completion(image.jpegData(compressionQuality: 0.8))
        }
    }
}

struct CheapestStationWidget: Widget {
    let kind = "CheapestStationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CheapestStationProvider()) { entry in
            CheapestStationWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Gasolinera barata")
        .description("Precio de la gasolinera más barata cerca de ti.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
