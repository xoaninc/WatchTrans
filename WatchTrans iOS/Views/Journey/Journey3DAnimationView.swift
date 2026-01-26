//
//  Journey3DAnimationView.swift
//  WatchTrans iOS
//
//  Created by Claude on 26/1/26.
//  Immersive 3D animated preview of a journey
//

import SwiftUI
import MapKit

struct Journey3DAnimationView: View {
    let journey: Journey
    let dataService: DataService

    @Environment(\.dismiss) private var dismiss

    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var currentSegmentIndex = 0
    @State private var currentPointIndex = 0
    @State private var progress: Double = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var showControls = true

    // Animation configuration
    private let pointDuration: Double = 0.15  // Base duration per point
    private let transitionDuration: Double = 1.0

    var currentSegment: JourneySegment? {
        guard currentSegmentIndex < journey.segments.count else { return nil }
        return journey.segments[currentSegmentIndex]
    }

    var body: some View {
        ZStack {
            // 3D Map
            Map(position: $mapPosition) {
                // Route polyline for current and completed segments
                ForEach(Array(journey.segments.enumerated()), id: \.element.id) { index, segment in
                    if index <= currentSegmentIndex {
                        let color = segmentColor(segment)
                        MapPolyline(coordinates: segment.coordinates)
                            .stroke(color, lineWidth: index == currentSegmentIndex ? 6 : 4)
                    }
                }

                // Current position marker
                if let segment = currentSegment,
                   currentPointIndex < segment.coordinates.count {
                    let coord = segment.coordinates[currentPointIndex]

                    Annotation("", coordinate: coord) {
                        currentPositionMarker
                    }
                }

                // Stop markers
                ForEach(journey.segments) { segment in
                    // Origin marker
                    Annotation(segment.origin.name, coordinate: CLLocationCoordinate2D(
                        latitude: segment.origin.latitude,
                        longitude: segment.origin.longitude
                    )) {
                        stopMarker(for: segment.origin, isOrigin: segment.id == journey.segments.first?.id)
                    }
                }

                // Final destination marker
                if let lastSegment = journey.segments.last {
                    Annotation(lastSegment.destination.name, coordinate: CLLocationCoordinate2D(
                        latitude: lastSegment.destination.latitude,
                        longitude: lastSegment.destination.longitude
                    )) {
                        destinationMarker
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
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
        .onAppear {
            setupInitialCamera()
        }
        .onDisappear {
            animationTask?.cancel()
        }
    }

    // MARK: - UI Components

    private var topBar: some View {
        HStack {
            Button {
                animationTask?.cancel()
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
        ZStack {
            // Pulse animation
            Circle()
                .fill(currentMarkerColor.opacity(0.3))
                .frame(width: 40, height: 40)

            // Main marker
            Circle()
                .fill(currentMarkerColor)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: 3)
                )
                .shadow(color: currentMarkerColor.opacity(0.5), radius: 5)

            // Transport mode icon
            Image(systemName: currentSegment?.transportMode.icon ?? "location.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
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
        HStack(spacing: 30) {
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
        let totalPoints = journey.segments.reduce(0) { $0 + $1.coordinates.count }
        var completedPoints = 0
        for i in 0..<currentSegmentIndex {
            completedPoints += journey.segments[i].coordinates.count
        }
        completedPoints += currentPointIndex

        guard totalPoints > 0 else { return 0 }
        let ratio = CGFloat(completedPoints) / CGFloat(totalPoints)
        return (totalWidth - 12) * ratio
    }

    // MARK: - Camera Control

    private func setupInitialCamera() {
        guard let firstSegment = journey.segments.first,
              let firstCoord = firstSegment.coordinates.first else { return }

        mapPosition = .camera(MapCamera(
            centerCoordinate: firstCoord,
            distance: firstSegment.transportMode.cameraAltitude * 10,
            heading: 0,
            pitch: 0
        ))
    }

    private func animateCamera(to coordinate: CLLocationCoordinate2D, mode: TransportMode, heading: Double = 0) {
        withAnimation(.easeInOut(duration: pointDuration * mode.animationSpeed)) {
            mapPosition = .camera(MapCamera(
                centerCoordinate: coordinate,
                distance: mode.cameraAltitude,
                heading: heading,
                pitch: mode.cameraPitch
            ))
        }
    }

    private func calculateHeading(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let deltaLon = to.longitude - from.longitude
        let y = sin(deltaLon * .pi / 180)
        let x = cos(from.latitude * .pi / 180) * tan(to.latitude * .pi / 180) -
                sin(from.latitude * .pi / 180) * cos(deltaLon * .pi / 180)
        let heading = atan2(y, x) * 180 / .pi
        return (heading + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: - Playback Control

    private func play() {
        isPlaying = true
        isPaused = false

        animationTask = Task {
            for segmentIdx in currentSegmentIndex..<journey.segments.count {
                guard !Task.isCancelled else { break }

                currentSegmentIndex = segmentIdx
                let segment = journey.segments[segmentIdx]

                // Transition animation between segments
                if segmentIdx > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(transitionDuration * 1_000_000_000))
                }

                let startIdx = segmentIdx == currentSegmentIndex ? currentPointIndex : 0

                for pointIdx in startIdx..<segment.coordinates.count {
                    guard !Task.isCancelled, !isPaused else { break }

                    currentPointIndex = pointIdx
                    let coord = segment.coordinates[pointIdx]

                    // Calculate heading to next point
                    var heading: Double = 0
                    if pointIdx < segment.coordinates.count - 1 {
                        heading = calculateHeading(from: coord, to: segment.coordinates[pointIdx + 1])
                    }

                    animateCamera(to: coord, mode: segment.transportMode, heading: heading)

                    // Wait for animation
                    let duration = pointDuration / segment.transportMode.animationSpeed
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                }

                // Reset point index for next segment
                if !isPaused {
                    currentPointIndex = 0
                }
            }

            // Animation complete
            await MainActor.run {
                isPlaying = false
            }
        }
    }

    private func pause() {
        isPaused = true
        animationTask?.cancel()
    }

    private func restart() {
        animationTask?.cancel()
        currentSegmentIndex = 0
        currentPointIndex = 0
        isPlaying = false
        isPaused = false
        setupInitialCamera()
    }

    private func skipToEnd() {
        animationTask?.cancel()
        currentSegmentIndex = journey.segments.count - 1
        if let lastSegment = journey.segments.last {
            currentPointIndex = lastSegment.coordinates.count - 1
            if let lastCoord = lastSegment.coordinates.last {
                animateCamera(to: lastCoord, mode: lastSegment.transportMode)
            }
        }
        isPlaying = false
        isPaused = false
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
