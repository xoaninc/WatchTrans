//
//  NativeAnimatedMapView.swift
//  WatchTrans iOS
//
//  Created by Claude on 28/1/26.
//  Native MKMapView wrapper for smooth 60fps animations without SwiftUI overhead
//
//  This solves the frustum culling and stuttering issues by:
//  1. Using displayPriority = .required to prevent marker culling
//  2. Updating camera directly via MKMapView.setCamera (bypasses SwiftUI)
//  3. Synchronizing marker and camera updates in the same render frame
//

import SwiftUI
import MapKit

struct NativeAnimatedMapView: UIViewRepresentable {
    let segments: [JourneySegment]
    @Binding var currentProgress: Double  // 0.0 to 1.0 for entire journey
    @Binding var currentSegmentIndex: Int
    @Binding var isMapReady: Bool  // True when map tiles are preloaded
    let isPlaying: Bool
    let speedMultiplier: Double

    // All coordinates flattened for easy access
    var allCoordinates: [CLLocationCoordinate2D] {
        segments.flatMap { $0.coordinates }
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        // 3D configuration (Uber/Navigation Style)
        if #available(iOS 16.0, *) {
            let config = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .default)
            config.showsTraffic = false
            config.pointOfInterestFilter = .excludingAll
            mapView.preferredConfiguration = config
        } else {
            mapView.showsBuildings = true
        }
        
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true

        // Debug: Log segment info
        DebugLog.log("🗺️ [NativeMap] makeUIView called with \(segments.count) segments")
        for (index, segment) in segments.enumerated() {
            DebugLog.log("🗺️ [NativeMap]   Segment \(index): \(segment.lineName ?? "walk") - \(segment.coordinates.count) coords")
        }
        DebugLog.log("🗺️ [NativeMap] Total coordinates: \(allCoordinates.count)")

        // Add polylines for each segment (only if they have coordinates)
        for (index, segment) in segments.enumerated() {
            guard segment.coordinates.count >= 2 else {
                DebugLog.log("🗺️ [NativeMap] ⚠️ Skipping segment \(index) - insufficient coordinates")
                continue
            }
            let polyline = SegmentPolyline(coordinates: segment.coordinates, count: segment.coordinates.count)
            polyline.segmentIndex = index
            polyline.color = segment.lineColor.flatMap { UIColor(hex: $0) } ?? (segment.type == .walking ? .orange : .systemBlue)
            mapView.addOverlay(polyline)
        }

        // Set coordinator data early
        context.coordinator.segments = segments
        context.coordinator.allCoordinates = allCoordinates

        // Add marker at start position
        if let first = allCoordinates.first {
            context.coordinator.setupAnnotation(at: first, in: mapView)
        } else {
            DebugLog.log("🗺️ [NativeMap] ⚠️ No coordinates for marker!")
        }

        // Add stop markers
        for segment in segments {
            let originAnnotation = StopAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: segment.origin.latitude, longitude: segment.origin.longitude),
                title: segment.origin.name,
                isOrigin: segment.id == segments.first?.id
            )
            mapView.addAnnotation(originAnnotation)
        }

        // Final destination
        if let lastSegment = segments.last {
            let destAnnotation = StopAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: lastSegment.destination.latitude, longitude: lastSegment.destination.longitude),
                title: lastSegment.destination.name,
                isDestination: true
            )
            mapView.addAnnotation(destAnnotation)
        }

        // Set up onMapReady callback to update binding
        let isMapReadyBinding = _isMapReady
        context.coordinator.onMapReady = {
            DispatchQueue.main.async {
                isMapReadyBinding.wrappedValue = true
            }
        }

        // Initial camera showing entire route
        if !allCoordinates.isEmpty {
            context.coordinator.showEntireRoute(in: mapView, coordinates: allCoordinates)
        } else {
            DebugLog.log("🗺️ [NativeMap] ⚠️ No coordinates for initial camera!")
        }

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Always update coordinator data
        context.coordinator.segments = segments
        context.coordinator.allCoordinates = allCoordinates
        context.coordinator.currentSegmentIndex = currentSegmentIndex
        context.coordinator.mapView = uiView

        // Reset saved progress if SwiftUI progress is 0 (restart was pressed)
        if currentProgress == 0 && !isPlaying {
            context.coordinator.resetAnimation()
        }

        // Handle animation start/stop
        if isPlaying && !context.coordinator.isAnimating {
            // Capture bindings for use in callbacks
            let progressBinding = _currentProgress
            let segmentIndexBinding = _currentSegmentIndex

            // Start animation in coordinator (bypasses SwiftUI for smooth 60fps)
            context.coordinator.onProgressUpdate = { progress in
                // Update SwiftUI state for UI elements (progress bar)
                DispatchQueue.main.async {
                    progressBinding.wrappedValue = progress
                }
            }
            context.coordinator.onSegmentIndexUpdate = { index in
                // Update SwiftUI state for segment info card
                DispatchQueue.main.async {
                    segmentIndexBinding.wrappedValue = index
                }
            }
            context.coordinator.onAnimationComplete = {
                // Animation finished - update SwiftUI state
                DispatchQueue.main.async {
                    progressBinding.wrappedValue = 1.0
                }
            }
            context.coordinator.startAnimation(speed: speedMultiplier)
        } else if !isPlaying && context.coordinator.isAnimating {
            context.coordinator.stopAnimation()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator: The animation engine

    class Coordinator: NSObject, MKMapViewDelegate {
        var segments: [JourneySegment] = []
        var allCoordinates: [CLLocationCoordinate2D] = []
        var currentSegmentIndex: Int = 0
        var currentHeading: Double = 0
        var mapView: MKMapView?

        // MKAnnotation marker
        var marker: MKPointAnnotation = MKPointAnnotation()

        // Core Animation State
        var isAnimating: Bool = false
        private var currentCoordIndex: Int = 0
        private var progressUpdateTimer: Timer?
        private var accumulatedDistance: Double = 0
        private var totalDistance: Double = 0
        private var cumulativeDistances: [Double] = []
        
        // Speed Multiplier (Global)
        var speedMultiplier: Double = 1.0

        // Callbacks
        var onProgressUpdate: ((Double) -> Void)?
        var onSegmentIndexUpdate: ((Int) -> Void)?
        var onAnimationComplete: (() -> Void)?
        var onMapReady: (() -> Void)?

        func setupAnnotation(at coord: CLLocationCoordinate2D, in map: MKMapView) {
            self.mapView = map
            marker.coordinate = coord
            map.addAnnotation(marker)
        }

        // MARK: - Animation Control (Core Animation)

        func startAnimation(speed: Double) {
            guard !allCoordinates.isEmpty, !isAnimating else { return }
            
            // Pre-compute if needed
            if cumulativeDistances.isEmpty {
                precomputeDistances()
                totalDistance = cumulativeDistances.last ?? 0
            }
            
            // Resume logic: find index closest to accumulatedDistance
            if currentCoordIndex == 0 && accumulatedDistance > 0 {
                // Determine currentCoordIndex based on saved distance
                // (Simple approximation: find first distance > accumulated)
                if let index = cumulativeDistances.firstIndex(where: { $0 >= accumulatedDistance }) {
                    currentCoordIndex = max(0, index - 1)
                }
            }
            
            self.speedMultiplier = speed
            self.isAnimating = true
            
            DebugLog.log("🎬 [Coordinator] Starting Core Animation loop. Total Coords: \(allCoordinates.count), Index: \(currentCoordIndex)")
            
            // Start Progress Timer (Independent from visual animation)
            startProgressTimer()
            
            // Kick off recursive animation
            animateToNextCoordinate()
        }

        func stopAnimation() {
            isAnimating = false
            // Stop recursion by flag
            // Stop View Animations
            if let markerView = mapView?.view(for: marker) {
                markerView.layer.removeAllAnimations()
            }
            progressUpdateTimer?.invalidate()
            progressUpdateTimer = nil
        }
        
        func resetAnimation() {
            stopAnimation()
            currentCoordIndex = 0
            accumulatedDistance = 0
            // Reset position
            if let start = allCoordinates.first {
                marker.coordinate = start
                mapView?.camera.centerCoordinate = start
            }
        }

        // MARK: - Recursive Animation Logic

        private func animateToNextCoordinate() {
            guard isAnimating,
                  currentCoordIndex < allCoordinates.count - 1,
                  let map = mapView else {
                
                if currentCoordIndex >= allCoordinates.count - 1 {
                    // Finished
                    stopAnimation()
                    onProgressUpdate?(1.0)
                    onAnimationComplete?()
                }
                return
            }

            let startCoord = allCoordinates[currentCoordIndex]
            let endCoord = allCoordinates[currentCoordIndex + 1]
            
            // 1. Calculate Distance & Duration
            let segmentDistance = haversineDistance(from: startCoord, to: endCoord)
            
            // Determine speed based on Transport Mode
            let currentSegmentIdx = segmentIndexForCoordinateIndex(currentCoordIndex)
            let mode = segments[currentSegmentIdx].transportMode
            
            // Speed logic: Base (km/s) * Mode Multiplier * User Multiplier
            // Increased to 0.3 for a much faster preview (User feedback: "lentísimo")
            let baseSpeedKmS = 0.3 
            let effectiveSpeed = baseSpeedKmS * mode.animationSpeed * self.speedMultiplier
            
            // Avoid division by zero
            let duration = effectiveSpeed > 0 ? (segmentDistance / effectiveSpeed) : 0.0
            
            // 2. Update Context (Segment Index & Heading)
            if currentSegmentIdx != currentSegmentIndex {
                currentSegmentIndex = currentSegmentIdx
                onSegmentIndexUpdate?(currentSegmentIdx)
                updateMarkerAppearance() // Direct view update for icon
            }
            
            // Calculate Heading
            let heading = calculateBearing(from: startCoord, to: endCoord)
            self.currentHeading = heading

            // 3. Execute Core Animation (UIView.animate)
            // .curveLinear is CRITICAL for smooth chaining of segments
            // Duration set to 0.0 would jump instantly, ensure minimum
            let safeDuration = max(duration, 0.01)
            
            UIView.animate(withDuration: safeDuration, delay: 0, options: [.curveLinear, .allowUserInteraction], animations: { [weak self] in
                guard let self = self else { return }
                
                // Move Marker Visuals
                self.marker.coordinate = endCoord
                
                if let markerView = map.view(for: self.marker) {
                    // Rotate
                    markerView.transform = CGAffineTransform(rotationAngle: CGFloat(heading.toRadians()))
                }
                
                // Move Camera (Smooth Follow)
                let altitude = mode.cameraAltitude
                let pitch = mode.cameraPitch
                
                let camera = MKMapCamera(lookingAtCenter: endCoord, fromDistance: altitude, pitch: pitch, heading: heading)
                map.camera = camera
                
            }) { [weak self] finished in
                guard let self = self, self.isAnimating else { return }
                
                // Even if interrupted, we generally want to proceed if we are still "playing"
                // But typically if finished=false it means we stopped or started a new one.
                if finished {
                    // Advance to next point
                    self.currentCoordIndex += 1
                    self.accumulatedDistance += segmentDistance
                    
                    // Recursive Call
                    self.animateToNextCoordinate()
                }
            }
        }
        
        private func startProgressTimer() {
            progressUpdateTimer?.invalidate()
            progressUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, self.totalDistance > 0 else { return }
                
                // Estimate smooth progress based on current index + accumulated
                let progress = self.accumulatedDistance / self.totalDistance
                self.onProgressUpdate?(min(progress, 1.0))
            }
        }

        // MARK: - Helpers & Setup

        func showEntireRoute(in map: MKMapView, coordinates: [CLLocationCoordinate2D]) {
            guard !coordinates.isEmpty else { return }

            // 1. Vista general 2D - muestra la ruta completa al usuario
            let lats = coordinates.map { $0.latitude }
            let lons = coordinates.map { $0.longitude }

            let center = CLLocationCoordinate2D(
                latitude: (lats.min()! + lats.max()!) / 2,
                longitude: (lons.min()! + lons.max()!) / 2
            )

            let latSpan = (lats.max()! - lats.min()!) * 1.5
            let lonSpan = (lons.max()! - lons.min()!) * 1.5

            let region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: max(latSpan, 0.01), longitudeDelta: max(lonSpan, 0.01))
            )
            map.setRegion(region, animated: false)

            // 2. Transición directa al punto de inicio en 3D
            DebugLog.log("🗺️ [Map] Setting up 3D start position")

            if let startCoord = coordinates.first {
                // Colocar marcador en el inicio
                self.marker.coordinate = startCoord

                // Calcular dirección inicial
                let heading: Double = coordinates.count > 1 ? calculateBearing(from: startCoord, to: coordinates[1]) : 0

                // Configurar cámara 3D en el punto de inicio
                let startCamera = MKMapCamera(
                    lookingAtCenter: startCoord,
                    fromDistance: 2000,
                    pitch: 60,
                    heading: heading
                )

                // Transición suave de vista 2D a vista 3D (1s)
                UIView.animate(withDuration: 1.0, delay: 0.5, options: .curveEaseInOut) {
                    map.camera = startCamera
                } completion: { [weak self] _ in
                    DebugLog.log("🗺️ [Map] ✅ Ready to play")
                    self?.onMapReady?()
                }
            } else {
                self.onMapReady?()
            }
        }

        /// Updates the marker image directly without removing/adding the annotation
        private func updateMarkerAppearance() {
            guard let map = mapView, let view = map.view(for: self.marker) else { return }
            let segment = segments[currentSegmentIndex]
            view.image = renderMarkerImage(for: segment)
        }
        
        /// Generates the "Premium Pill" image for a segment
        private func renderMarkerImage(for segment: JourneySegment) -> UIImage {
            let lineColor = segment.lineColor.flatMap { UIColor(hex: $0) } ?? .systemBlue
            let lineName = segment.lineName ?? ""
            
            // Determine icon (SF Symbol only, no hardcoded logo selection)
            let iconName: String
            let localLogoName: String? = nil

            switch segment.transportMode {
            case .walking:
                iconName = "figure.walk"
            case .metro:
                iconName = "tram.tunnel.fill"
            case .tren:
                iconName = "tram.fill"
            case .tranvia:
                iconName = "lightrail.fill"
            case .metroLigero:
                iconName = "lightrail.fill"
            case .bus:
                iconName = "bus.fill"
            }
            
            // RENDERER: Crear un "Pill" (Burbuja alargada con Logo + Nombre)
            let hasLineName = !lineName.isEmpty && segment.transportMode != .walking
            let pillWidth: CGFloat = hasLineName ? 70 : 44
            let size = CGSize(width: pillWidth, height: 44)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { ctx in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
                let cornerRadius = rect.height / 2
                
                // 1. Sombra
                ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.3).cgColor)
                
                // 2. Fondo Blanco (Pill)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
                UIColor.white.setFill()
                path.fill()
                
                // 3. Borde de color de línea
                lineColor.setStroke()
                path.lineWidth = 2
                path.stroke()
                
                // 4. Logo / Icono (Lado izquierdo)
                let iconRect = CGRect(x: rect.minX + 4, y: rect.minY + 4, width: rect.height - 8, height: rect.height - 8)
                
                if let logoName = localLogoName, let logoImg = UIImage(named: logoName) {
                    logoImg.draw(in: iconRect)
                } else {
                    let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
                    if let symbol = UIImage(systemName: iconName, withConfiguration: config)?.withTintColor(lineColor, renderingMode: .alwaysOriginal) {
                        let symbolRect = CGRect(
                            x: iconRect.midX - symbol.size.width / 2,
                            y: iconRect.midY - symbol.size.height / 2,
                            width: symbol.size.width,
                            height: symbol.size.height
                        )
                        symbol.draw(in: symbolRect)
                    }
                }
                
                // 5. Nombre de línea (Lado derecho, si aplica)
                if hasLineName {
                    let textRect = CGRect(x: iconRect.maxX + 2, y: rect.minY, width: rect.width - iconRect.width - 10, height: rect.height)
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = .center
                    
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 14, weight: .black),
                        .foregroundColor: lineColor,
                        .paragraphStyle: paragraphStyle
                    ]
                    
                    let string = NSAttributedString(string: lineName, attributes: attributes)
                    let textSize = string.size()
                    let textDrawRect = CGRect(
                        x: textRect.minX,
                        y: textRect.midY - textSize.height / 2,
                        width: textRect.width,
                        height: textSize.height
                    )
                    string.draw(in: textDrawRect)
                }
            }
        }

        private func precomputeDistances() {
            cumulativeDistances = [0]
            var total: Double = 0
            for i in 0..<allCoordinates.count - 1 {
                let from = allCoordinates[i]
                let to = allCoordinates[i + 1]
                let dist = haversineDistance(from: from, to: to)
                total += dist
                cumulativeDistances.append(total)
            }
        }

        private func haversineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
            let R = 6371.0 // Earth radius in km
            let lat1 = from.latitude * .pi / 180
            let lat2 = to.latitude * .pi / 180
            let dLat = (to.latitude - from.latitude) * .pi / 180
            let dLon = (to.longitude - from.longitude) * .pi / 180

            let a = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
            let c = 2 * atan2(sqrt(a), sqrt(1-a))
            return R * c
        }

        /// Determine which segment a coordinate index belongs to
        private func segmentIndexForCoordinateIndex(_ coordIndex: Int) -> Int {
            var accumulated = 0
            for (segmentIdx, segment) in segments.enumerated() {
                accumulated += segment.coordinates.count
                if coordIndex < accumulated {
                    return segmentIdx
                }
            }
            return max(0, segments.count - 1)
        }

        private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
            let fLat = from.latitude.toRadians()
            let fLon = from.longitude.toRadians()
            let tLat = to.latitude.toRadians()
            let tLon = to.longitude.toRadians()

            let deltaLon = tLon - fLon
            let y = sin(deltaLon) * cos(tLat)
            let x = cos(fLat) * sin(tLat) - sin(fLat) * cos(tLat) * cos(deltaLon)
            let bearing = atan2(y, x).toDegrees()

            return (bearing + 360).truncatingRemainder(dividingBy: 360)
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Moving marker (Premium Pill View)
            if annotation === marker {
                let identifier = "movingVehicle"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = false
                } else {
                    view?.annotation = annotation
                }
                
                let segment = segments[currentSegmentIndex]
                view?.image = renderMarkerImage(for: segment)
                
                view?.displayPriority = .required
                view?.zPriority = .max
                view?.centerOffset = CGPoint(x: 0, y: 0)
                
                // Rotación suave
                view?.transform = CGAffineTransform(rotationAngle: CGFloat(currentHeading.toRadians()))
                
                return view
            }

            // Stop annotations
            if let stopAnnotation = annotation as? StopAnnotation {
                if stopAnnotation.isDestination {
                    let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "destination")
                    view.markerTintColor = .systemRed
                    view.glyphImage = UIImage(systemName: "flag.fill")
                    view.displayPriority = .defaultHigh
                    return view
                } else if stopAnnotation.isOrigin {
                    let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "origin")
                    view.markerTintColor = .systemGreen
                    view.glyphImage = UIImage(systemName: "play.fill")
                    view.displayPriority = .defaultHigh
                    return view
                } else {
                    let view = MKAnnotationView(annotation: annotation, reuseIdentifier: "stop")
                    view.displayPriority = .defaultLow
                    return view
                }
            }

            return nil
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? SegmentPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = polyline.color
                renderer.lineWidth = polyline.segmentIndex == currentSegmentIndex ? 6 : 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
} // End of NativeAnimatedMapView

// MARK: - Helper Classes

/// Custom polyline that stores segment info
class SegmentPolyline: MKPolyline {
    var segmentIndex: Int = 0
    var color: UIColor = .systemBlue
}

/// Custom annotation for stops
class StopAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var isOrigin: Bool = false
    var isDestination: Bool = false

    init(coordinate: CLLocationCoordinate2D, title: String?, isOrigin: Bool = false, isDestination: Bool = false) {
        self.coordinate = coordinate
        self.title = title
        self.isOrigin = isOrigin
        self.isDestination = isDestination
    }
}

// MARK: - Math Extensions

extension Double {
    func toRadians() -> Double { self * .pi / 180 }
    func toDegrees() -> Double { self * 180 / .pi }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
