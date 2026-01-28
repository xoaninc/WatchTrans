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
    let isPlaying: Bool

    // All coordinates flattened for easy access
    var allCoordinates: [CLLocationCoordinate2D] {
        segments.flatMap { $0.coordinates }
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        // 3D configuration
        mapView.showsBuildings = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.mapType = .standard
        mapView.pointOfInterestFilter = .excludingAll

        // Add polylines for each segment
        for (index, segment) in segments.enumerated() {
            let polyline = SegmentPolyline(coordinates: segment.coordinates, count: segment.coordinates.count)
            polyline.segmentIndex = index
            polyline.color = segment.lineColor.flatMap { UIColor(hex: $0) } ?? (segment.type == .walking ? .orange : .systemBlue)
            mapView.addOverlay(polyline)
        }

        // Add marker at start position
        if let first = allCoordinates.first {
            context.coordinator.setupAnnotation(at: first, in: mapView)
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

        // Initial camera showing entire route
        context.coordinator.showEntireRoute(in: mapView, coordinates: allCoordinates)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.segments = segments
        context.coordinator.allCoordinates = allCoordinates
        context.coordinator.currentSegmentIndex = currentSegmentIndex

        if isPlaying {
            context.coordinator.updateProgress(currentProgress)
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
        var marker: MKPointAnnotation = MKPointAnnotation()
        var currentHeading: Double = 0
        var mapView: MKMapView?

        func setupAnnotation(at coord: CLLocationCoordinate2D, in map: MKMapView) {
            self.mapView = map
            marker.coordinate = coord
            map.addAnnotation(marker)
        }

        func showEntireRoute(in map: MKMapView, coordinates: [CLLocationCoordinate2D]) {
            guard !coordinates.isEmpty else { return }

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
        }

        func updateProgress(_ progress: Double) {
            guard allCoordinates.count > 1, let map = mapView else { return }

            // 1. Calculate exact position and index
            let floatIndex = Double(allCoordinates.count - 1) * progress
            let index = Int(floatIndex)
            let nextIndex = min(index + 1, allCoordinates.count - 1)
            let fractional = floatIndex.truncatingRemainder(dividingBy: 1)

            let currentPoint = allCoordinates[index]
            let nextPoint = allCoordinates[nextIndex]

            // Linear interpolation for marker position
            let interpolatedLat = currentPoint.latitude + (nextPoint.latitude - currentPoint.latitude) * fractional
            let interpolatedLon = currentPoint.longitude + (nextPoint.longitude - currentPoint.longitude) * fractional
            let interpolatedCoord = CLLocationCoordinate2D(latitude: interpolatedLat, longitude: interpolatedLon)

            // 2. Look-Ahead for camera (8 points ahead)
            let lookAheadIndex = min(index + 8, allCoordinates.count - 1)
            let targetCoord = allCoordinates[lookAheadIndex]

            // 3. Smoothed Heading calculation
            let targetHeading = calculateBearing(from: interpolatedCoord, to: targetCoord)
            smoothHeading(target: targetHeading)

            // 4. Get current segment's transport mode for camera settings
            let segmentCameraDistance: Double = 2500
            let segmentCameraPitch: Double = 55

            // 5. NATIVE UPDATE (No SwiftUI overhead)
            UIView.animate(withDuration: 0.016, delay: 0, options: .curveLinear) {
                self.marker.coordinate = interpolatedCoord

                let camera = MKMapCamera(
                    lookingAtCenter: targetCoord,
                    fromDistance: segmentCameraDistance,
                    pitch: segmentCameraPitch,
                    heading: self.currentHeading
                )
                map.setCamera(camera, animated: false)
            }
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
                view.displayPriority = .required  // CRITICAL: Prevents frustum culling
                view.zPriority = .max             // Always on top of buildings
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
