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

    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var currentSegmentIndex = 0
    @State private var currentProgress: Double = 0  // 0.0 to 1.0 for entire journey
    @State private var showControls = true
    @State private var speedMultiplier: Double = 1.0
    @State private var isMapReady = false  // True when map tiles are preloaded

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
                isMapReady: $isMapReady,
                isPlaying: isPlaying,
                speedMultiplier: speedMultiplier
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
            isPlaying = false
        }
    }

    // MARK: - UI Components

    private var topBar: some View {
        HStack {
            Button {
                isPlaying = false
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
            // Speed toggle: 0.5× → 1× → 2× → 0.5×
            Button {
                if speedMultiplier == 0.5 {
                    speedMultiplier = 1.0
                } else if speedMultiplier == 1.0 {
                    speedMultiplier = 2.0
                } else {
                    speedMultiplier = 0.5
                }
            } label: {
                Text(speedMultiplier == 0.5 ? "0.5×" : (speedMultiplier == 1.0 ? "1×" : "2×"))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(speedMultiplier == 0.5 ? .blue : (speedMultiplier == 1.0 ? .gray.opacity(0.5) : .orange)))
            }
            .disabled(!isMapReady)
            .opacity(isMapReady ? 1.0 : 0.5)

            // Restart
            Button {
                restart()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .disabled(!isMapReady)
            .opacity(isMapReady ? 1.0 : 0.5)

            // Play/Pause
            Button {
                if isPlaying {
                    pause()
                } else {
                    play()
                }
            } label: {
                ZStack {
                    if !isMapReady {
                        // Loading indicator while map preloads
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: isPlaying && !isPaused ? "pause.fill" : "play.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 60, height: 60)
                .background(Circle().fill(isMapReady ? .blue : .gray))
            }
            .disabled(!isMapReady)

            // Skip to end
            Button {
                skipToEnd()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .disabled(!isMapReady)
            .opacity(isMapReady ? 1.0 : 0.5)
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

    private func play() {
        guard !isPlaying || isPaused else { return }

        print("🎬 [SwiftUI] Play pressed")
        isPlaying = true
        isPaused = false
        // Animation is now handled by NativeAnimatedMapView's Coordinator
    }

    private func pause() {
        isPaused = true
        isPlaying = false  // This will trigger stopAnimation in Coordinator
    }

    private func restart() {
        isPlaying = false  // Stop animation
        currentSegmentIndex = 0
        currentProgress = 0
        isPaused = false
    }

    private func skipToEnd() {
        isPlaying = false  // Stop animation
        currentSegmentIndex = journey.segments.count - 1
        currentProgress = 1.0
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
