import SwiftUI
import MapLibre
import CoreLocation

class StationPointAnnotation: MLNPointAnnotation {
    var station: FuelStation?
    var isCheapest = false
    var isFavorite = false
}

struct MapLibreMapView: UIViewRepresentable {
    let stations: [FuelStation]
    let cheapestId: String?
    let favoriteIds: Set<String>
    let onStationTapped: (FuelStation) -> Void
    var centerOnUserCounter: Int
    var zoomRadiusKm: Double?
    var zoomRadiusCounter: Int
    var isDarkMode: Bool = false

    static let lightStyleURL = URL(string: "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json")!
    static let darkStyleURL = URL(string: "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json")!

    func makeUIView(context: Context) -> MLNMapView {
        let styleURL = isDarkMode ? Self.darkStyleURL : Self.lightStyleURL
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.compassViewPosition = .topRight
        mapView.logoView.isHidden = true
        mapView.attributionButton.alpha = 0
        mapView.setCenter(
            CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038),
            zoomLevel: 11,
            animated: false
        )
        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        let expectedURL = isDarkMode ? Self.darkStyleURL : Self.lightStyleURL
        if mapView.styleURL != expectedURL {
            mapView.styleURL = expectedURL
        }

        coordinator.syncAnnotations(on: mapView)

        if centerOnUserCounter != coordinator.lastCenterCounter {
            coordinator.lastCenterCounter = centerOnUserCounter
            if let coord = mapView.userLocation?.coordinate,
               CLLocationCoordinate2DIsValid(coord) {
                mapView.setCenter(coord, zoomLevel: 13, animated: true)
            }
        }

        if zoomRadiusCounter != coordinator.lastZoomCounter, let radiusKm = zoomRadiusKm {
            coordinator.lastZoomCounter = zoomRadiusCounter
            if let coord = mapView.userLocation?.coordinate,
               CLLocationCoordinate2DIsValid(coord) {
                let meters = radiusKm * 1000
                let latDelta = meters * 2.2 / 111_000
                let lonDelta = meters * 2.2 / (111_000 * cos(coord.latitude * .pi / 180))
                let bounds = MLNCoordinateBounds(
                    sw: CLLocationCoordinate2D(
                        latitude: coord.latitude - latDelta / 2,
                        longitude: coord.longitude - lonDelta / 2
                    ),
                    ne: CLLocationCoordinate2D(
                        latitude: coord.latitude + latDelta / 2,
                        longitude: coord.longitude + lonDelta / 2
                    )
                )
                mapView.setVisibleCoordinateBounds(bounds, animated: true)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: MapLibreMapView
        weak var mapView: MLNMapView?
        var lastCenterCounter = 0
        var lastZoomCounter = 0
        private var annotationMap: [String: StationPointAnnotation] = [:]
        private var hasFittedInitialBounds = false

        init(parent: MapLibreMapView) {
            self.parent = parent
        }

        func syncAnnotations(on mapView: MLNMapView) {
            let currentIds = Set(annotationMap.keys)
            let newIds = Set(parent.stations.map(\.id))

            let toRemove = currentIds.subtracting(newIds)
            for id in toRemove {
                if let ann = annotationMap.removeValue(forKey: id) {
                    mapView.removeAnnotation(ann)
                }
            }

            var cheapestAnnotation: StationPointAnnotation?

            for station in parent.stations {
                let isCheapest = station.id == parent.cheapestId
                let isFavorite = parent.favoriteIds.contains(station.id)

                if let existing = annotationMap[station.id] {
                    if existing.isCheapest != isCheapest || existing.isFavorite != isFavorite {
                        existing.isCheapest = isCheapest
                        existing.isFavorite = isFavorite
                        if let view = mapView.view(for: existing) as? StationAnnotationView {
                            view.configure(isCheapest: isCheapest, isFavorite: isFavorite)
                        }
                    }
                    if isCheapest { cheapestAnnotation = existing }
                } else {
                    let ann = StationPointAnnotation()
                    ann.coordinate = station.coordinate
                    ann.station = station
                    ann.isCheapest = isCheapest
                    ann.isFavorite = isFavorite
                    mapView.addAnnotation(ann)
                    annotationMap[station.id] = ann
                    if isCheapest { cheapestAnnotation = ann }
                }
            }

            // Bring cheapest annotation view to front
            if let cheapestAnn = cheapestAnnotation,
               let view = mapView.view(for: cheapestAnn) {
                view.layer.zPosition = 1000
                view.superview?.bringSubviewToFront(view)
            }

            // Fit user + cheapest station on first load
            if !hasFittedInitialBounds,
               let cheapestAnn = cheapestAnnotation,
               let userCoord = mapView.userLocation?.coordinate,
               CLLocationCoordinate2DIsValid(userCoord) {
                hasFittedInitialBounds = true
                let stationCoord = cheapestAnn.coordinate
                fitBounds(on: mapView, coordinates: [userCoord, stationCoord])
            }
        }

        private func fitBounds(on mapView: MLNMapView, coordinates: [CLLocationCoordinate2D]) {
            guard coordinates.count >= 2 else { return }
            var minLat = Double.infinity, maxLat = -Double.infinity
            var minLon = Double.infinity, maxLon = -Double.infinity
            for coord in coordinates {
                minLat = min(minLat, coord.latitude)
                maxLat = max(maxLat, coord.latitude)
                minLon = min(minLon, coord.longitude)
                maxLon = max(maxLon, coord.longitude)
            }

            let bounds = MLNCoordinateBounds(
                sw: CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
                ne: CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon)
            )
            let insets = UIEdgeInsets(top: 120, left: 60, bottom: 320, right: 60)
            mapView.setVisibleCoordinateBounds(bounds, edgePadding: insets, animated: true, completionHandler: nil)
        }

        // MARK: - MLNMapViewDelegate

        func mapView(_ mapView: MLNMapView, viewFor annotation: any MLNAnnotation) -> MLNAnnotationView? {
            guard let stationAnn = annotation as? StationPointAnnotation else { return nil }
            let reuseId = stationAnn.isCheapest ? "cheapest" : "station"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? StationAnnotationView
                ?? StationAnnotationView(reuseIdentifier: reuseId)
            view.configure(isCheapest: stationAnn.isCheapest, isFavorite: stationAnn.isFavorite)
            if stationAnn.isCheapest {
                view.layer.zPosition = 1000
            }
            return view
        }

        func mapView(_ mapView: MLNMapView, didSelect annotation: any MLNAnnotation) {
            guard let stationAnn = annotation as? StationPointAnnotation,
                  let station = stationAnn.station else { return }
            mapView.deselectAnnotation(annotation, animated: false)
            parent.onStationTapped(station)
        }

        func mapView(_ mapView: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
            guard let coord = userLocation?.coordinate,
                  CLLocationCoordinate2DIsValid(coord) else { return }

            // If we have a cheapest station, fit both; otherwise center on user
            if !hasFittedInitialBounds {
                if let cheapestId = parent.cheapestId,
                   let cheapestAnn = annotationMap[cheapestId] {
                    hasFittedInitialBounds = true
                    fitBounds(on: mapView, coordinates: [coord, cheapestAnn.coordinate])
                } else {
                    mapView.setCenter(coord, zoomLevel: 13, animated: true)
                }
            }
        }
    }
}

// MARK: - UIKit Pin Annotation View

class StationAnnotationView: MLNAnnotationView {
    private let pulseRing = UIView()
    private let pinBody = UIView()
    private let pinTail = UIView()
    private let iconView = UIImageView()
    private var isPulsing = false

    private static let pinSize: CGFloat = 32
    private static let tailSize: CGFloat = 8
    private static let totalHeight: CGFloat = pinSize + tailSize - 2
    private static let frameSize: CGFloat = 48
    private static let accentTeal = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.121, green: 0.639, blue: 0.620, alpha: 1)
            : UIColor(red: 0.054, green: 0.486, blue: 0.482, alpha: 1)
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        let fs = Self.frameSize
        frame = CGRect(x: 0, y: 0, width: fs, height: fs)
        centerOffset = CGVector(dx: 0, dy: -fs / 2)
        isOpaque = false
        backgroundColor = .clear

        let ps = Self.pinSize
        let ts = Self.tailSize

        // Pulse ring (behind everything, for cheapest only)
        let ringSize: CGFloat = 44
        pulseRing.frame = CGRect(
            x: (fs - ringSize) / 2,
            y: (fs - Self.totalHeight) / 2 + (ps - ringSize) / 2,
            width: ringSize,
            height: ringSize
        )
        pulseRing.layer.cornerRadius = ringSize / 2
        pulseRing.backgroundColor = Self.accentTeal.withAlphaComponent(0.25)
        pulseRing.isHidden = true
        addSubview(pulseRing)

        pinBody.frame = CGRect(
            x: (fs - ps) / 2,
            y: (fs - Self.totalHeight) / 2,
            width: ps,
            height: ps
        )
        pinBody.layer.cornerRadius = ps / 2
        pinBody.backgroundColor = .white
        pinBody.layer.shadowColor = UIColor.black.cgColor
        pinBody.layer.shadowOpacity = 0.15
        pinBody.layer.shadowOffset = CGSize(width: 0, height: 2)
        pinBody.layer.shadowRadius = 3
        addSubview(pinBody)

        pinTail.frame = CGRect(
            x: (fs - ts) / 2,
            y: pinBody.frame.maxY - 4,
            width: ts,
            height: ts
        )
        pinTail.backgroundColor = .white
        pinTail.transform = CGAffineTransform(rotationAngle: .pi / 4)
        addSubview(pinTail)

        bringSubviewToFront(pinBody)

        let iconSize: CGFloat = 16
        iconView.frame = CGRect(
            x: pinBody.frame.midX - iconSize / 2,
            y: pinBody.frame.midY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        iconView.image = UIImage(systemName: "fuelpump.fill")
        addSubview(iconView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(isCheapest: Bool, isFavorite: Bool) {
        if isCheapest {
            pinBody.backgroundColor = Self.accentTeal
            pinTail.backgroundColor = Self.accentTeal
            iconView.image = UIImage(systemName: "fuelpump.fill")
            iconView.tintColor = .white
            pinBody.transform = .init(scaleX: 1.15, y: 1.15)
            layer.zPosition = 1000
            pulseRing.isHidden = false
            startPulse()
        } else {
            pulseRing.isHidden = true
            stopPulse()
            layer.zPosition = 0
            pinBody.transform = .identity

            if isFavorite {
                pinBody.backgroundColor = .white
                pinTail.backgroundColor = .white
                iconView.tintColor = UIColor(red: 0.85, green: 0.18, blue: 0.15, alpha: 1)
                iconView.image = UIImage(systemName: "heart.fill")
            } else {
                pinBody.backgroundColor = .white
                pinTail.backgroundColor = .white
                iconView.tintColor = UIColor(white: 0.25, alpha: 1)
                iconView.image = UIImage(systemName: "fuelpump.fill")
            }
        }
    }

    private func startPulse() {
        guard !isPulsing else { return }
        isPulsing = true
        pulseRing.transform = .identity
        pulseRing.alpha = 0.4

        UIView.animate(
            withDuration: 1.4,
            delay: 0,
            options: [.repeat, .autoreverse, .allowUserInteraction, .curveEaseInOut]
        ) {
            self.pulseRing.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            self.pulseRing.alpha = 0
        }
    }

    private func stopPulse() {
        guard isPulsing else { return }
        isPulsing = false
        pulseRing.layer.removeAllAnimations()
        pulseRing.transform = .identity
        pulseRing.alpha = 0
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopPulse()
        pulseRing.isHidden = true
        layer.zPosition = 0
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        let t: CGAffineTransform = selected ? .init(scaleX: 1.2, y: 1.2) : .identity
        if animated {
            UIView.animate(withDuration: 0.15) { self.transform = t }
        } else {
            transform = t
        }
    }
}
