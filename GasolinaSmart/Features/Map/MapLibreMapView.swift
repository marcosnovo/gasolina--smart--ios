import SwiftUI
import MapLibre
import CoreLocation

class StationPointAnnotation: MLNPointAnnotation {
    var station: FuelStation?
    var isCheapest = false
    var isFavorite = false
}

class ChargingPointAnnotation: MLNPointAnnotation {
    var chargingStation: ChargingStation?
}

struct MapLibreMapView: UIViewRepresentable {
    let stations: [FuelStation]
    let cheapestId: String?
    let favoriteIds: Set<String>
    let onStationTapped: (FuelStation) -> Void
    var chargingStations: [ChargingStation] = []
    var onChargingStationTapped: ((ChargingStation) -> Void)?
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
        let previousCheapestId = coordinator.parent.cheapestId
        coordinator.parent = self

        let expectedURL = isDarkMode ? Self.darkStyleURL : Self.lightStyleURL
        if mapView.styleURL != expectedURL {
            coordinator.needsFullReconfigure = true
            mapView.styleURL = expectedURL
        }

        coordinator.syncAnnotations(on: mapView)
        coordinator.syncChargingAnnotations(on: mapView)

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

        if cheapestId != previousCheapestId, let cheapestId,
           let cheapestAnn = coordinator.annotationMap[cheapestId],
           let userCoord = mapView.userLocation?.coordinate,
           CLLocationCoordinate2DIsValid(userCoord) {
            coordinator.fitBounds(on: mapView, coordinates: [userCoord, cheapestAnn.coordinate])
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
        var annotationMap: [String: StationPointAnnotation] = [:]
        var chargingAnnotationMap: [String: ChargingPointAnnotation] = [:]
        var needsFullReconfigure = false
        private var hasFittedInitialBounds = false
        private var currentCheapestViewId: String?

        init(parent: MapLibreMapView) {
            self.parent = parent
        }

        func syncAnnotations(on mapView: MLNMapView) {
            let currentIds = Set(annotationMap.keys)
            let newIds = Set(parent.stations.map(\.id))

            let idsToRemove = currentIds.subtracting(newIds)
            if !idsToRemove.isEmpty {
                let annsToRemove = idsToRemove.compactMap { annotationMap.removeValue(forKey: $0) }
                mapView.removeAnnotations(annsToRemove)
                if idsToRemove.contains(currentCheapestViewId ?? "") {
                    currentCheapestViewId = nil
                }
            }

            let idsToAdd = newIds.subtracting(currentIds)
            if !idsToAdd.isEmpty {
                let stationById = Dictionary(uniqueKeysWithValues: parent.stations.map { ($0.id, $0) })
                var annsToAdd: [StationPointAnnotation] = []
                for id in idsToAdd {
                    guard let station = stationById[id] else { continue }
                    let ann = StationPointAnnotation()
                    ann.coordinate = station.coordinate
                    ann.station = station
                    ann.isCheapest = station.id == parent.cheapestId
                    ann.isFavorite = parent.favoriteIds.contains(station.id)
                    annotationMap[station.id] = ann
                    annsToAdd.append(ann)
                }
                mapView.addAnnotations(annsToAdd)
            }

            for station in parent.stations {
                guard let existing = annotationMap[station.id] else { continue }
                let isCheapest = station.id == parent.cheapestId
                let isFavorite = parent.favoriteIds.contains(station.id)
                let changed = existing.isCheapest != isCheapest || existing.isFavorite != isFavorite
                existing.isCheapest = isCheapest
                existing.isFavorite = isFavorite
                if (changed || needsFullReconfigure) && !isCheapest {
                    if let view = mapView.view(for: existing) as? LightPinView {
                        view.configure(image: isFavorite ? LightPinView.favoriteImage : LightPinView.regularImage)
                    }
                }
            }

            let newCheapestId = parent.cheapestId
            if newCheapestId != currentCheapestViewId {
                if let oldId = currentCheapestViewId, let oldAnn = annotationMap[oldId] {
                    oldAnn.isCheapest = false
                    mapView.removeAnnotation(oldAnn)
                    mapView.addAnnotation(oldAnn)
                }

                if let newId = newCheapestId, let newAnn = annotationMap[newId] {
                    newAnn.isCheapest = true
                    mapView.removeAnnotation(newAnn)
                    mapView.addAnnotation(newAnn)
                }

                currentCheapestViewId = newCheapestId
            }

            if let cheapestId = currentCheapestViewId,
               let cheapestAnn = annotationMap[cheapestId],
               let view = mapView.view(for: cheapestAnn) {
                view.layer.zPosition = 1000
                view.superview?.bringSubviewToFront(view)
            }

            if !hasFittedInitialBounds,
               let cheapestId = currentCheapestViewId,
               let cheapestAnn = annotationMap[cheapestId],
               let userCoord = mapView.userLocation?.coordinate,
               CLLocationCoordinate2DIsValid(userCoord) {
                hasFittedInitialBounds = true
                fitBounds(on: mapView, coordinates: [userCoord, cheapestAnn.coordinate], animated: false)
            }

            needsFullReconfigure = false
        }

        func syncChargingAnnotations(on mapView: MLNMapView) {
            let currentIds = Set(chargingAnnotationMap.keys)
            let newIds = Set(parent.chargingStations.map(\.id))

            let idsToRemove = currentIds.subtracting(newIds)
            if !idsToRemove.isEmpty {
                let annsToRemove = idsToRemove.compactMap { chargingAnnotationMap.removeValue(forKey: $0) }
                mapView.removeAnnotations(annsToRemove)
            }

            let idsToAdd = newIds.subtracting(currentIds)
            if !idsToAdd.isEmpty {
                let stationById = Dictionary(uniqueKeysWithValues: parent.chargingStations.map { ($0.id, $0) })
                var annsToAdd: [ChargingPointAnnotation] = []
                for id in idsToAdd {
                    guard let station = stationById[id] else { continue }
                    let ann = ChargingPointAnnotation()
                    ann.coordinate = station.coordinate
                    ann.chargingStation = station
                    chargingAnnotationMap[station.id] = ann
                    annsToAdd.append(ann)
                }
                mapView.addAnnotations(annsToAdd)
            }
        }

        func fitBounds(on mapView: MLNMapView, coordinates: [CLLocationCoordinate2D], animated: Bool = true) {
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
            let insets = UIEdgeInsets(top: 100, left: 60, bottom: 380, right: 60)
            mapView.setVisibleCoordinateBounds(bounds, edgePadding: insets, animated: animated, completionHandler: nil)
        }

        // MARK: - MLNMapViewDelegate

        func mapView(_ mapView: MLNMapView, viewFor annotation: any MLNAnnotation) -> MLNAnnotationView? {
            if annotation is MLNUserLocation {
                return UserLocationDotView()
            }

            if annotation is ChargingPointAnnotation {
                let reuseId = "charging_pin"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? LightPinView
                    ?? LightPinView(reuseIdentifier: reuseId)
                view.configure(image: LightPinView.chargingImage)
                return view
            }

            guard let stationAnn = annotation as? StationPointAnnotation else { return nil }

            if stationAnn.isCheapest {
                let reuseId = "cheapest"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? CheapestPinView
                    ?? CheapestPinView(reuseIdentifier: reuseId)
                view.activate()
                return view
            }

            let reuseId = "light_pin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? LightPinView
                ?? LightPinView(reuseIdentifier: reuseId)
            let image = stationAnn.isFavorite ? LightPinView.favoriteImage : LightPinView.regularImage
            view.configure(image: image)
            return view
        }

        func mapView(_ mapView: MLNMapView, didSelect annotation: any MLNAnnotation) {
            mapView.deselectAnnotation(annotation, animated: false)

            if let chargingAnn = annotation as? ChargingPointAnnotation,
               let station = chargingAnn.chargingStation {
                parent.onChargingStationTapped?(station)
                return
            }

            if let stationAnn = annotation as? StationPointAnnotation,
               let station = stationAnn.station {
                parent.onStationTapped(station)
            }
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            for (_, ann) in annotationMap {
                if let view = mapView.view(for: ann) as? LightPinView {
                    let image = ann.isFavorite ? LightPinView.favoriteImage : LightPinView.regularImage
                    view.configure(image: image)
                }
            }
        }

        func mapView(_ mapView: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
            guard let coord = userLocation?.coordinate,
                  CLLocationCoordinate2DIsValid(coord) else { return }

            if !hasFittedInitialBounds {
                if let cheapestId = parent.cheapestId,
                   let cheapestAnn = annotationMap[cheapestId] {
                    hasFittedInitialBounds = true
                    fitBounds(on: mapView, coordinates: [coord, cheapestAnn.coordinate], animated: false)
                } else {
                    hasFittedInitialBounds = true
                    mapView.setCenter(coord, zoomLevel: 13, animated: false)
                }
            }
        }
    }
}

// MARK: - User Location Dot

class UserLocationDotView: MLNUserLocationAnnotationView {
    private static let dotSize: CGFloat = 14
    private static let borderSize: CGFloat = 18
    private var didSetup = false

    override func update() {
        guard !didSetup else { return }
        didSetup = true

        let size = Self.borderSize
        frame = CGRect(x: 0, y: 0, width: size, height: size)
        isOpaque = false
        backgroundColor = .clear

        let border = UIView(frame: bounds)
        border.backgroundColor = .white
        border.layer.cornerRadius = size / 2
        border.layer.shadowColor = UIColor.black.cgColor
        border.layer.shadowOpacity = 0.2
        border.layer.shadowOffset = CGSize(width: 0, height: 1)
        border.layer.shadowRadius = 3
        border.layer.shadowPath = UIBezierPath(roundedRect: border.bounds, cornerRadius: size / 2).cgPath
        addSubview(border)

        let dotSize = Self.dotSize
        let dot = UIView(frame: CGRect(
            x: (size - dotSize) / 2,
            y: (size - dotSize) / 2,
            width: dotSize,
            height: dotSize
        ))
        dot.backgroundColor = UIColor.systemBlue
        dot.layer.cornerRadius = dotSize / 2
        addSubview(dot)
    }
}

// MARK: - Lightweight Pin (pre-rendered image, single UIImageView)

class LightPinView: MLNAnnotationView {
    private let imageView = UIImageView()

    private static let viewSize: CGFloat = 48

    static let regularImage = renderPinImage(
        bodyColor: .white,
        iconName: "fuelpump.fill",
        iconTint: UIColor(white: 0.25, alpha: 1)
    )
    static let favoriteImage = renderPinImage(
        bodyColor: .white,
        iconName: "star.fill",
        iconTint: UIColor(red: 0.90, green: 0.72, blue: 0.0, alpha: 1)
    )
    static let chargingImage = renderPinImage(
        bodyColor: .white,
        iconName: "bolt.fill",
        iconTint: UIColor(red: 0.20, green: 0.45, blue: 0.85, alpha: 1)
    )

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        let s = Self.viewSize
        frame = CGRect(x: 0, y: 0, width: s, height: s)
        centerOffset = CGVector(dx: 0, dy: -s / 2)
        isOpaque = false
        backgroundColor = .clear

        imageView.frame = bounds
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)

        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(image: UIImage) {
        imageView.image = image
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        layer.zPosition = 0
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        let t: CGAffineTransform = selected ? .init(scaleX: 1.15, y: 1.15) : .identity
        if animated {
            UIView.animate(withDuration: 0.12) { self.transform = t }
        } else {
            transform = t
        }
    }

    // MARK: - Image Rendering

    private static func renderPinImage(
        bodyColor: UIColor,
        iconName: String,
        iconTint: UIColor
    ) -> UIImage {
        let diameter: CGFloat = 28
        let tailH: CGFloat = 7
        let shadowPad: CGFloat = 4
        let imgW = diameter + shadowPad * 2
        let imgH = diameter + tailH + shadowPad * 2

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imgW, height: imgH))
        return renderer.image { ctx in
            let gc = ctx.cgContext
            let cx = imgW / 2
            let circleTop = shadowPad

            gc.saveGState()
            gc.setShadow(
                offset: CGSize(width: 0, height: 1.5),
                blur: 3,
                color: UIColor.black.withAlphaComponent(0.22).cgColor
            )

            gc.setFillColor(bodyColor.cgColor)
            let circleRect = CGRect(x: cx - diameter / 2, y: circleTop, width: diameter, height: diameter)
            gc.fillEllipse(in: circleRect)

            let tailTop = circleTop + diameter - 2
            let tailW: CGFloat = 7
            gc.move(to: CGPoint(x: cx - tailW / 2, y: tailTop))
            gc.addLine(to: CGPoint(x: cx, y: tailTop + tailH))
            gc.addLine(to: CGPoint(x: cx + tailW / 2, y: tailTop))
            gc.closePath()
            gc.fillPath()

            gc.restoreGState()

            let iconSize: CGFloat = 14
            let iconRect = CGRect(
                x: cx - iconSize / 2,
                y: circleTop + (diameter - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)
            if let icon = UIImage(systemName: iconName, withConfiguration: config)?
                .withTintColor(iconTint, renderingMode: .alwaysOriginal) {
                icon.draw(in: iconRect)
            }
        }
    }
}

// MARK: - Cheapest Station Pin (with pulse animation — only 1 on screen)

class CheapestPinView: MLNAnnotationView {
    private let pulseRing1 = UIView()
    private let pulseRing2 = UIView()
    private let imageView = UIImageView()
    private var isPulsing = false

    private static let frameSize: CGFloat = 70
    private static let accentGreen = UIColor(red: 0.16, green: 0.67, blue: 0.33, alpha: 1)

    private static let cheapestImage = renderCheapestImage()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        let fs = Self.frameSize
        frame = CGRect(x: 0, y: 0, width: fs, height: fs)
        centerOffset = CGVector(dx: 0, dy: -fs / 2)
        isOpaque = false
        backgroundColor = .clear

        let ringSize: CGFloat = 56
        let ringY = (fs - 38) / 2 + (32 - ringSize) / 2
        for ring in [pulseRing1, pulseRing2] {
            ring.frame = CGRect(x: (fs - ringSize) / 2, y: ringY, width: ringSize, height: ringSize)
            ring.layer.cornerRadius = ringSize / 2
            ring.backgroundColor = Self.accentGreen.withAlphaComponent(0.3)
            ring.isHidden = true
            addSubview(ring)
        }

        let imgSize: CGFloat = 50
        imageView.frame = CGRect(
            x: (fs - imgSize) / 2,
            y: (fs - imgSize) / 2 - 4,
            width: imgSize,
            height: imgSize
        )
        imageView.contentMode = .scaleAspectFit
        imageView.image = Self.cheapestImage
        addSubview(imageView)

        layer.zPosition = 1000
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func activate() {
        pulseRing1.isHidden = false
        pulseRing2.isHidden = false
        layer.zPosition = 1000
        startPulse()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil && !pulseRing1.isHidden {
            DispatchQueue.main.async { [weak self] in self?.startPulse() }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !isPulsing && window != nil && !pulseRing1.isHidden {
            DispatchQueue.main.async { [weak self] in self?.startPulse() }
        }
    }

    private func startPulse() {
        guard window != nil, !pulseRing1.isHidden else { return }
        stopPulseAnimations()
        isPulsing = true
        addPulseAnimation(to: pulseRing1.layer, delay: 0)
        addPulseAnimation(to: pulseRing2.layer, delay: 0.8)
    }

    private func addPulseAnimation(to layer: CALayer, delay: CFTimeInterval) {
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = 2.2

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.5
        opacity.toValue = 0.0

        let group = CAAnimationGroup()
        group.animations = [scale, opacity]
        group.duration = 1.6
        group.beginTime = CACurrentMediaTime() + delay
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards

        layer.add(group, forKey: "pulse")
    }

    private func stopPulseAnimations() {
        pulseRing1.layer.removeAllAnimations()
        pulseRing2.layer.removeAllAnimations()
        pulseRing1.transform = .identity
        pulseRing2.transform = .identity
        pulseRing1.alpha = 0
        pulseRing2.alpha = 0
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isPulsing = false
        stopPulseAnimations()
        pulseRing1.isHidden = true
        pulseRing2.isHidden = true
        layer.zPosition = 0
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        let t: CGAffineTransform = selected ? .init(scaleX: 1.15, y: 1.15) : .identity
        if animated {
            UIView.animate(withDuration: 0.12) { self.transform = t }
        } else {
            transform = t
        }
    }

    private static func renderCheapestImage() -> UIImage {
        let diameter: CGFloat = 34
        let tailH: CGFloat = 8
        let pad: CGFloat = 5
        let imgW = diameter + pad * 2
        let imgH = diameter + tailH + pad * 2

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imgW, height: imgH))
        return renderer.image { ctx in
            let gc = ctx.cgContext
            let cx = imgW / 2
            let circleTop = pad

            gc.saveGState()
            gc.setShadow(
                offset: CGSize(width: 0, height: 2),
                blur: 4,
                color: UIColor.black.withAlphaComponent(0.25).cgColor
            )

            gc.setFillColor(accentGreen.cgColor)
            gc.fillEllipse(in: CGRect(x: cx - diameter / 2, y: circleTop, width: diameter, height: diameter))

            let tailTop = circleTop + diameter - 2
            let tailW: CGFloat = 8
            gc.move(to: CGPoint(x: cx - tailW / 2, y: tailTop))
            gc.addLine(to: CGPoint(x: cx, y: tailTop + tailH))
            gc.addLine(to: CGPoint(x: cx + tailW / 2, y: tailTop))
            gc.closePath()
            gc.fillPath()

            gc.restoreGState()

            let iconSize: CGFloat = 17
            let iconRect = CGRect(
                x: cx - iconSize / 2,
                y: circleTop + (diameter - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .bold)
            if let icon = UIImage(systemName: "fuelpump.fill", withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                icon.draw(in: iconRect)
            }
        }
    }
}
