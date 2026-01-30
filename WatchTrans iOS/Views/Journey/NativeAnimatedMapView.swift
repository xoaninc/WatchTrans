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

        // 3D configuration
        mapView.showsBuildings = false
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.mapType = .standard
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsTraffic = false

        // Debug: Log segment info
        print("🗺️ [NativeMap] makeUIView called with \(segments.count) segments")
        for (index, segment) in segments.enumerated() {
            print("🗺️ [NativeMap]   Segment \(index): \(segment.lineName ?? "walk") - \(segment.coordinates.count) coords")
        }
        print("🗺️ [NativeMap] Total coordinates: \(allCoordinates.count)")

        // Add polylines for each segment (only if they have coordinates)
        for (index, segment) in segments.enumerated() {
            guard segment.coordinates.count >= 2 else {
                print("🗺️ [NativeMap] ⚠️ Skipping segment \(index) - insufficient coordinates")
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
            print("🗺️ [NativeMap] ⚠️ No coordinates for marker!")
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
            print("🗺️ [NativeMap] ⚠️ No coordinates for initial camera!")
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
            context.coordinator.startAnimation(speed: 0.4 * speedMultiplier)
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

        // MKAnnotation marker (MapKit handles coordinate-to-screen conversion)
        var marker: MKPointAnnotation = MKPointAnnotation()

        // Pre-computed distances for fast lookup (avoids creating CLLocation objects every frame)
        private var cumulativeDistances: [Double] = []

        // Animation state
        private var displayLink: CADisplayLink?
        private var animationStartTime: CFTimeInterval = 0
        private var totalDistance: Double = 0
        private var speedKmPerSec: Double = 0.15
        private var frameCount: Int = 0  // For throttling updates
        private var cameraAnimator: UIViewPropertyAnimator?  // Smooth camera animation
        private var savedProgress: Double = 0  // For pause/resume
        var isAnimating: Bool = false
        var onProgressUpdate: ((Double) -> Void)?
        var onSegmentIndexUpdate: ((Int) -> Void)?
        var onAnimationComplete: (() -> Void)?
        var onMapReady: (() -> Void)?

        func setupAnnotation(at coord: CLLocationCoordinate2D, in map: MKMapView) {
            self.mapView = map
            marker.coordinate = coord
            map.addAnnotation(marker)
        }

        // MARK: - Map Setup

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
            print("🗺️ [Map] Setting up 3D start position")

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
                    print("🗺️ [Map] ✅ Ready to play")
                    self?.onMapReady?()
                }
            } else {
                self.onMapReady?()
            }
        }

        // MARK: - Animation Control

        func startAnimation(speed: Double) {
            guard !allCoordinates.isEmpty else {
                print("🎬 [Coordinator] Cannot start - no coordinates")
                return
            }

            // Stop display link but don't reset progress
            displayLink?.invalidate()
            displayLink = nil
            cameraAnimator?.stopAnimation(true)
            cameraAnimator = nil

            // Pre-compute cumulative distances if not done yet
            if cumulativeDistances.isEmpty {
                precomputeDistances()
            }

            speedKmPerSec = speed
            totalDistance = cumulativeDistances.last ?? 0
            isAnimating = true
            frameCount = 0

            // Resume from saved progress: calculate start time as if we started earlier
            let alreadyTraveled = savedProgress * totalDistance
            let timeAlreadyElapsed = alreadyTraveled / speedKmPerSec
            animationStartTime = CACurrentMediaTime() - timeAlreadyElapsed

            print("🎬 [Coordinator] Starting animation: \(allCoordinates.count) coords, \(totalDistance) km, \(speed) km/s, resuming from \(Int(savedProgress * 100))%")

            displayLink = CADisplayLink(target: self, selector: #selector(animationTick))
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            displayLink?.add(to: .main, forMode: .common)
        }

        func resetAnimation() {
            savedProgress = 0
        }

        private func precomputeDistances() {
            cumulativeDistances = [0]
            var total: Double = 0
            for i in 0..<allCoordinates.count - 1 {
                let from = allCoordinates[i]
                let to = allCoordinates[i + 1]
                // Haversine distance (faster than CLLocation)
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

        func stopAnimation() {
            // Save current progress before stopping
            if isAnimating && totalDistance > 0 {
                let elapsed = CACurrentMediaTime() - animationStartTime
                let distanceTraveled = elapsed * speedKmPerSec
                savedProgress = min(distanceTraveled / totalDistance, 1.0)
            }

            displayLink?.invalidate()
            displayLink = nil
            cameraAnimator?.stopAnimation(true)
            cameraAnimator = nil
            isAnimating = false
        }

        @objc private func animationTick() {
            guard let map = mapView, !allCoordinates.isEmpty else { return }

            frameCount += 1
            let elapsed = CACurrentMediaTime() - animationStartTime
            let distanceTraveled = elapsed * speedKmPerSec
            let progress = min(distanceTraveled / totalDistance, 1.0)

            // THROTTLE: Only update SwiftUI every 6 frames (~10fps) to avoid re-render overhead
            if frameCount % 6 == 0 {
                onProgressUpdate?(progress)
            }

            if progress >= 1.0 {
                onProgressUpdate?(1.0)  // Final update
                stopAnimation()
                onAnimationComplete?()
                return
            }

            // Calculate position using pre-computed distances (fast binary search)
            let (interpolatedCoord, coordIndex) = coordinateAtProgressFast(progress)

            // Calculate which segment we're in (only notify when it changes)
            let newSegmentIndex = segmentIndexForCoordinateIndex(coordIndex)
            if newSegmentIndex != currentSegmentIndex {
                currentSegmentIndex = newSegmentIndex
                onSegmentIndexUpdate?(newSegmentIndex)
            }

            // Look-ahead for camera (balanced: smooth but follows closely)
            let lookAheadIndex = min(coordIndex + 3, allCoordinates.count - 1)
            let targetCoord = allCoordinates[lookAheadIndex]

            // Smooth heading
            let targetHeading = calculateBearing(from: interpolatedCoord, to: targetCoord)
            smoothHeading(target: targetHeading)

            // Update every 3 frames (20fps) with smooth property animator
            // Longer duration creates overlap between animations for ultra-smooth motion
            if frameCount % 3 == 0 {
                // Stop any running animation
                cameraAnimator?.stopAnimation(true)

                let camera = MKMapCamera(
                    lookingAtCenter: targetCoord,
                    fromDistance: 2000,
                    pitch: 60,
                    heading: self.currentHeading
                )

                // Animate BOTH marker and camera together with easeInOut for smoother feel
                cameraAnimator = UIViewPropertyAnimator(duration: 0.1, curve: .easeInOut) { [weak self, weak map] in
                    self?.marker.coordinate = interpolatedCoord
                    map?.camera = camera
                }
                cameraAnimator?.startAnimation()
            }
        }

        /// Fast coordinate lookup using pre-computed cumulative distances
        private func coordinateAtProgressFast(_ progress: Double) -> (CLLocationCoordinate2D, Int) {
            let targetDistance = progress * totalDistance

            // Binary search to find the segment
            var low = 0
            var high = cumulativeDistances.count - 1
            while low < high {
                let mid = (low + high + 1) / 2
                if cumulativeDistances[mid] <= targetDistance {
                    low = mid
                } else {
                    high = mid - 1
                }
            }

            let i = min(low, allCoordinates.count - 2)
            let segmentStart = cumulativeDistances[i]
            let segmentEnd = cumulativeDistances[i + 1]
            let segmentLength = segmentEnd - segmentStart

            let ratio = segmentLength > 0 ? (targetDistance - segmentStart) / segmentLength : 0
            let from = allCoordinates[i]
            let to = allCoordinates[i + 1]

            let lat = from.latitude + (to.latitude - from.latitude) * ratio
            let lon = from.longitude + (to.longitude - from.longitude) * ratio

            return (CLLocationCoordinate2D(latitude: lat, longitude: lon), i)
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

        private func smoothHeading(target: Double) {
            var delta = target - currentHeading
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            currentHeading += delta * 0.08  // Smoothing factor

            // Normalize to 0-360
            if currentHeading < 0 { currentHeading += 360 }
            if currentHeading >= 360 { currentHeading -= 360 }
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
            // Moving marker
            if annotation === marker {
                let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "movingMarker")
                view.displayPriority = .required  // Prevents frustum culling
                view.zPriority = .max             // Always on top
                view.animatesWhenAdded = false
                view.glyphImage = UIImage(systemName: "tram.fill")
                view.markerTintColor = .systemBlue
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
}

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
