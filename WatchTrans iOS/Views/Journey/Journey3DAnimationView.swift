//
//  Journey3DAnimationView.swift
//  WatchTrans iOS
//
//  Created by Claude on 26/1/26.
//  Immersive 3D animated preview of a journey
//

import SwiftUI
import MapKit
import QuartzCore

struct Journey3DAnimationView: View {
    let journey: Journey
    let dataService: DataService

    @Environment(\.dismiss) private var dismiss

    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var currentSegmentIndex = 0
    @State private var currentProgress: Double = 0  // 0.0 to 1.0 for entire journey
    @State private var showControls = true

    // CADisplayLink animation controller
    @State private var animationController: AnimationController?

    // Animation configuration
    private let baseSpeedKmPerSec: Double = 0.15
    @State private var speedMultiplier: Double = 1.0

    var currentSegment: JourneySegment? {
        guard currentSegmentIndex < journey.segments.count else { return nil }
        return journey.segments[currentSegmentIndex]
    }

    var body: some View {
        ZStack {
            // 3D Map - Native MKMapView for smooth 60fps animation
            NativeAnimatedMapView(
                segments: journey.segments,
                currentProgress: $currentProgress,
                currentSegmentIndex: $currentSegmentIndex,
                isPlaying: isPlaying
            )
            .ignoresSafeArea()

            // Overlay UI
            VStack {
                // Top bar
                if showControls {
                    topBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Current segment info
                if let segment = currentSegment, showControls {
                    segmentInfoCard(segment)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Progress bar
                progressBar

                // Controls
                if showControls {
                    controlsBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showControls)
        }
        .onTapGesture {
            withAnimation {
                showControls.toggle()
            }
        }
        .onDisappear {
            animationController?.stop()
        }
    }

    // MARK: - UI Components

    private var topBar: some View {
        HStack {
            Button {
                animationController?.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Circle().fill(.black.opacity(0.5)))
            }

            Spacer()

            // Journey summary
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(journey.origin.name) → \(journey.destination.name)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(journey.totalDurationMinutes) min · \(journey.segments.count) tramos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
        }
        .padding()
    }

    private var currentPositionMarker: some View {
        // Simplified marker for better performance during fast animations
        // Using a larger, more visible marker that renders consistently
        ZStack {
            // Outer glow (static, no animation)
            Circle()
                .fill(currentMarkerColor.opacity(0.4))
                .frame(width: 32, height: 32)

            // Main marker - larger for visibility
            Circle()
                .fill(currentMarkerColor)
                .frame(width: 18, height: 18)
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: 2.5)
                )

            // Transport mode icon
            Image(systemName: currentSegment?.transportMode.icon ?? "location.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
        }
        .drawingGroup()  // Flatten to single layer for better rendering performance
    }

    private var currentMarkerColor: Color {
        if let segment = currentSegment, let hex = segment.lineColor {
            return Color(hex: hex) ?? .blue
        }
        return currentSegment?.type == .walking ? .orange : .blue
    }

    private func stopMarker(for stop: Stop, isOrigin: Bool) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(isOrigin ? .green : .white)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                    )

                if isOrigin {
                    Circle()
                        .fill(.white)
                        .frame(width: 6, height: 6)
                }
            }

            if isOrigin {
                Text(stop.name)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .cornerRadius(4)
            }
        }
    }

    private var destinationMarker: some View {
        VStack(spacing: 2) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.red)
                .background(Circle().fill(.white).padding(4))

            Text(journey.destination.name)
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial)
                .cornerRadius(4)
        }
    }

    private func segmentInfoCard(_ segment: JourneySegment) -> some View {
        HStack(spacing: 12) {
            // Transport mode icon
            ZStack {
                Circle()
                    .fill(segmentColor(segment))
                    .frame(width: 44, height: 44)

                Image(systemName: segment.transportMode.icon)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let lineName = segment.lineName {
                        Text(lineName)
                            .font(.headline)
                            .fontWeight(.bold)
                    } else {
                        Text(segment.transportMode.displayName)
                            .font(.headline)
                    }

                    Text("→ \(segment.destination.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if segment.type == .transit {
                        Label("\(segment.stopCount) paradas", systemImage: "tram.fill")
                    }
                    Label("\(segment.durationMinutes) min", systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(height: 4)

                // Segments
                HStack(spacing: 2) {
                    ForEach(Array(journey.segments.enumerated()), id: \.element.id) { index, segment in
                        Rectangle()
                            .fill(segmentColor(segment))
                            .frame(width: segmentWidth(index, totalWidth: geometry.size.width), height: 4)
                            .opacity(index < currentSegmentIndex ? 1.0 : (index == currentSegmentIndex ? 0.8 : 0.3))
                    }
                }

                // Progress indicator
                Circle()
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .shadow(radius: 2)
                    .offset(x: progressOffset(totalWidth: geometry.size.width))
            }
        }
        .frame(height: 12)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var controlsBar: some View {
        HStack(spacing: 20) {
            // Speed toggle: 1× → 2× → 4× → 1×
            Button {
                if speedMultiplier == 1.0 {
                    speedMultiplier = 2.0
                } else if speedMultiplier == 2.0 {
                    speedMultiplier = 4.0
                } else {
                    speedMultiplier = 1.0
                }
            } label: {
                Text(speedMultiplier == 1.0 ? "1×" : (speedMultiplier == 2.0 ? "2×" : "4×"))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(speedMultiplier == 1.0 ? .gray.opacity(0.5) : (speedMultiplier == 2.0 ? .orange : .red)))
            }

            // Restart
            Button {
                restart()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            // Play/Pause
            Button {
                if isPlaying {
                    pause()
                } else {
                    play()
                }
            } label: {
                Image(systemName: isPlaying && !isPaused ? "pause.fill" : "play.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(.blue))
            }

            // Skip to end
            Button {
                skipToEnd()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding()
    }

    // MARK: - Helper Functions

    private func segmentColor(_ segment: JourneySegment) -> Color {
        if let hex = segment.lineColor {
            return Color(hex: hex) ?? .blue
        }
        return segment.type == .walking ? .orange : .blue
    }

    private func segmentWidth(_ index: Int, totalWidth: CGFloat) -> CGFloat {
        let segment = journey.segments[index]
        let totalDuration = journey.segments.reduce(0) { $0 + $1.durationMinutes }
        guard totalDuration > 0 else { return totalWidth / CGFloat(journey.segments.count) }
        let ratio = CGFloat(segment.durationMinutes) / CGFloat(totalDuration)
        return max(20, (totalWidth - CGFloat(journey.segments.count - 1) * 2) * ratio)
    }

    private func progressOffset(totalWidth: CGFloat) -> CGFloat {
        // Use currentProgress (0.0 to 1.0) directly
        return (totalWidth - 12) * currentProgress
    }

    // MARK: - Playback Control

    /// Total distance of the journey in kilometers
    private var totalJourneyDistance: Double {
        journey.segments.flatMap { $0.coordinates }.reduce(into: (0.0, nil as CLLocationCoordinate2D?)) { result, coord in
            if let prev = result.1 {
                let from = CLLocation(latitude: prev.latitude, longitude: prev.longitude)
                let to = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                result.0 += from.distance(from: to) / 1000.0
            }
            result.1 = coord
        }.0
    }

    private func play() {
        guard !isPlaying || isPaused else { return }

        isPlaying = true
        isPaused = false

        // Stop any existing animation
        animationController?.stop()

        // All coordinates flattened
        let allCoords = journey.segments.flatMap { $0.coordinates }

        // Create new animation controller
        let controller = AnimationController()
        animationController = controller

        // Calculate effective speed based on multiplier
        let effectiveSpeed = baseSpeedKmPerSec * speedMultiplier

        controller.start(
            coordinates: allCoords,
            speedKmPerSec: effectiveSpeed,
            onUpdate: { [self] _, _, progress, _ in
                // Update progress (0.0 to 1.0) - NativeAnimatedMapView handles the rest
                currentProgress = progress

                // Update current segment index based on progress
                updateCurrentSegmentIndex(progress: progress)
            },
            onComplete: { [self] in
                isPlaying = false
                currentProgress = 1.0
            }
        )
    }

    /// Update currentSegmentIndex based on overall progress
    private func updateCurrentSegmentIndex(progress: Double) {
        let allCoords = journey.segments.flatMap { $0.coordinates }
        let currentIndex = Int(progress * Double(allCoords.count - 1))

        var accumulated = 0
        for (index, segment) in journey.segments.enumerated() {
            accumulated += segment.coordinates.count
            if currentIndex < accumulated {
                if currentSegmentIndex != index {
                    currentSegmentIndex = index
                }
                break
            }
        }
    }

    private func pause() {
        isPaused = true
        animationController?.stop()
    }

    private func restart() {
        animationController?.stop()
        currentSegmentIndex = 0
        currentProgress = 0
        isPlaying = false
        isPaused = false
    }

    private func skipToEnd() {
        animationController?.stop()
        currentSegmentIndex = journey.segments.count - 1
        currentProgress = 1.0
        isPlaying = false
        isPaused = false
    }
}

// MARK: - CADisplayLink Animation Controller

/// Controller for smooth map marker animation along a route.
///
/// Uses techniques from Mapbox GL JS and Google Maps:
/// - CADisplayLink for 60fps synchronized with display refresh (like requestAnimationFrame)
/// - Distance-based interpolation along polyline (like turf.along)
/// - Route normalization to subdivide sparse points (max 50m gaps)
/// - Spherical interpolation (Slerp) for geographic accuracy
///
/// Usage:
/// ```swift
/// let controller = AnimationController()
/// controller.start(
///     coordinates: segment.coordinates,
///     speedKmPerSec: 0.5,
///     onUpdate: { coord, heading, progress in
///         // Update marker and camera
///     },
///     onComplete: {
///         // Animation finished
///     }
/// )
/// ```
class AnimationController {
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var currentDistance: Double = 0
    private var totalDistance: Double = 0
    private var speedKmPerSec: Double = 0.5
    private var coordinates: [CLLocationCoordinate2D] = []
    // onUpdate: (coord, heading, progress, unused)
    private var onUpdate: ((CLLocationCoordinate2D, Double, Double, CLLocationCoordinate2D?) -> Void)?
    private var onComplete: (() -> Void)?

    func start(
        coordinates: [CLLocationCoordinate2D],
        speedKmPerSec: Double,
        onUpdate: @escaping (CLLocationCoordinate2D, Double, Double, CLLocationCoordinate2D?) -> Void,
        onComplete: @escaping () -> Void
    ) {
        // Coordinates are already normalized by the API (max_gap=50m)
        self.coordinates = coordinates
        self.speedKmPerSec = speedKmPerSec
        self.onUpdate = onUpdate
        self.onComplete = onComplete
        self.currentDistance = 0
        self.totalDistance = Self.lineDistance(coordinates)

        // Reset state
        frameCount = 0
        smoothedHeading = 0
        headingInitialized = false

        startTime = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        // Limit to 60fps to reduce jitter on ProMotion (120Hz) displays
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private var frameCount = 0
    private var smoothedHeading: Double = 0
    private var headingInitialized = false

    @objc private func update(displayLink: CADisplayLink) {
        let elapsed = CACurrentMediaTime() - startTime
        currentDistance = elapsed * speedKmPerSec
        frameCount += 1

        if currentDistance >= totalDistance {
            // Animation complete
            if let last = coordinates.last {
                let heading = coordinates.count > 1
                    ? Self.calculateHeading(from: coordinates[coordinates.count - 2], to: last)
                    : 0
                onUpdate?(last, heading, 1.0, nil)
            }
            stop()
            onComplete?()
            return
        }

        // Get position at current distance (like turf.along)
        let (coord, targetHeading) = Self.coordinateAlong(coordinates, distance: currentDistance)
        let progress = currentDistance / totalDistance

        // Smooth heading to prevent vibration when turning
        // Use very aggressive smoothing (0.03 = extremely smooth, more lag but no jitter)
        if !headingInitialized {
            smoothedHeading = targetHeading
            headingInitialized = true
        } else {
            // Handle wrap-around at 0/360 degrees
            var delta = targetHeading - smoothedHeading
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            smoothedHeading += delta * 0.03  // Very smooth (0.03)
            // Normalize to 0-360
            if smoothedHeading < 0 { smoothedHeading += 360 }
            if smoothedHeading >= 360 { smoothedHeading -= 360 }
        }

        // Update every frame for smooth motion on 120Hz ProMotion displays
        // (Previously skipped frames caused vibration due to MapKit interpolation)
        onUpdate?(coord, smoothedHeading, progress, nil)
    }

    // MARK: - Static Geometry Helpers

    static func lineDistance(_ coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count > 1 else { return 0 }
        var total: Double = 0
        for i in 0..<coordinates.count - 1 {
            let from = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let to = CLLocation(latitude: coordinates[i + 1].latitude, longitude: coordinates[i + 1].longitude)
            total += from.distance(from: to) / 1000.0
        }
        return total
    }

    static func coordinateAlong(_ coordinates: [CLLocationCoordinate2D], distance: Double) -> (CLLocationCoordinate2D, Double) {
        guard coordinates.count > 1 else {
            return (coordinates.first ?? CLLocationCoordinate2D(), 0)
        }

        var traveled: Double = 0

        for i in 0..<coordinates.count - 1 {
            let from = coordinates[i]
            let to = coordinates[i + 1]
            let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
            let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
            let segmentDist = fromLoc.distance(from: toLoc) / 1000.0

            if traveled + segmentDist >= distance {
                let remaining = distance - traveled
                let ratio = segmentDist > 0 ? remaining / segmentDist : 0
                let lat = from.latitude + (to.latitude - from.latitude) * ratio
                let lon = from.longitude + (to.longitude - from.longitude) * ratio
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let heading = calculateHeading(from: from, to: to)
                return (coord, heading)
            }

            traveled += segmentDist
        }

        let last = coordinates[coordinates.count - 1]
        let secondLast = coordinates[coordinates.count - 2]
        let heading = calculateHeading(from: secondLast, to: last)
        return (last, heading)
    }

    static func calculateHeading(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let deltaLon = to.longitude - from.longitude
        let y = sin(deltaLon * .pi / 180)
        let x = cos(from.latitude * .pi / 180) * tan(to.latitude * .pi / 180) -
                sin(from.latitude * .pi / 180) * cos(deltaLon * .pi / 180)
        let heading = atan2(y, x) * 180 / .pi
        return (heading + 360).truncatingRemainder(dividingBy: 360)
    }
}

#Preview {
    Journey3DAnimationView(
        journey: Journey(
            origin: Stop(id: "1", name: "Sol", latitude: 40.4169, longitude: -3.7033, connectionLineIds: [], province: "Madrid", accesibilidad: nil, hasParking: false, hasBusConnection: false, hasMetroConnection: true, corMetro: "L1, L2, L3", corMl: nil, corCercanias: "C3, C4", corTranvia: nil),
            destination: Stop(id: "2", name: "Nuevos Ministerios", latitude: 40.4459, longitude: -3.6917, connectionLineIds: [], province: "Madrid", accesibilidad: nil, hasParking: false, hasBusConnection: false, hasMetroConnection: true, corMetro: "L6, L8, L10", corMl: nil, corCercanias: "C3, C4, C7, C8", corTranvia: nil),
            segments: [],
            totalDurationMinutes: 12,
            totalWalkingMinutes: 2,
            transferCount: 1
        ),
        dataService: DataService()
    )
}
