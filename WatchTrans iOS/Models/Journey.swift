//
//  Journey.swift
//  WatchTrans iOS
//
//  Created by Claude on 26/1/26.
//  Models for journey planning and route calculation
//

import Foundation
import CoreLocation

// MARK: - Journey Result

/// Complete journey from origin to destination
struct Journey: Identifiable {
    let id = UUID()
    let origin: Stop
    let destination: Stop
    let segments: [JourneySegment]
    let totalDurationMinutes: Int
    let totalWalkingMinutes: Int
    let transferCount: Int

    /// All coordinates for the entire journey (for map display)
    var allCoordinates: [CLLocationCoordinate2D] {
        segments.flatMap { $0.coordinates }
    }

    /// Calculate total duration
    static func calculateDuration(segments: [JourneySegment]) -> Int {
        segments.reduce(0) { $0 + $1.durationMinutes }
    }

    /// Calculate walking time
    static func calculateWalkingTime(segments: [JourneySegment]) -> Int {
        segments.filter { $0.type == .walking }.reduce(0) { $0 + $1.durationMinutes }
    }
}

// MARK: - Journey Segment

/// A single segment of a journey (one line or walking)
struct JourneySegment: Identifiable {
    let id = UUID()
    let type: SegmentType
    let transportMode: TransportMode
    let lineName: String?           // "L1", "C3", nil for walking
    let lineColor: String?          // Hex color
    let origin: Stop
    let destination: Stop
    let intermediateStops: [Stop]   // Stops between origin and destination
    let durationMinutes: Int
    let coordinates: [CLLocationCoordinate2D]  // Shape points or stop coordinates

    /// All stops including origin and destination
    var allStops: [Stop] {
        [origin] + intermediateStops + [destination]
    }

    /// Number of stops (not counting origin)
    var stopCount: Int {
        intermediateStops.count + 1
    }
}

// MARK: - Segment Type

enum SegmentType {
    case transit   // Metro, Cercanías, Tram, etc.
    case walking   // Walking between stations
}

// MARK: - Transport Mode

enum TransportMode: String, CaseIterable {
    case metro = "metro"
    case cercanias = "cercanias"
    case metroLigero = "metro_ligero"
    case tranvia = "tranvia"
    case bus = "bus"
    case walking = "walking"

    var icon: String {
        switch self {
        case .metro: return "tram.fill"
        case .cercanias: return "train.side.front.car"
        case .metroLigero: return "lightrail.fill"
        case .tranvia: return "tram"
        case .bus: return "bus.fill"
        case .walking: return "figure.walk"
        }
    }

    var displayName: String {
        switch self {
        case .metro: return "Metro"
        case .cercanias: return "Cercanías"
        case .metroLigero: return "Metro Ligero"
        case .tranvia: return "Tranvía"
        case .bus: return "Bus"
        case .walking: return "Andando"
        }
    }

    /// Animation speed multiplier for 3D preview
    /// Base speed is 0.08 km/s, multiplied by this value
    ///
    /// Proportional to real-world commercial speeds (Spain):
    /// - Cercanías Renfe: ~45 km/h (regional rail, long inter-station distances)
    /// - Metro Madrid/BCN: ~30 km/h (urban metro)
    /// - Metro Ligero: ~22 km/h (light rail, some surface sections)
    /// - Tranvía/TRAM: ~18 km/h (street-running trams)
    /// - Walking: ~4.5 km/h (pedestrian speed)
    var animationSpeed: Double {
        switch self {
        case .metro: return 2.0        // Fast urban transit
        case .cercanias: return 2.5    // Faster regional
        case .metroLigero: return 1.8
        case .tranvia: return 1.5
        case .bus: return 1.5
        case .walking: return 0.3      // Slow for short walks
        }
    }

    /// Camera altitude for 3D preview (meters)
    var cameraAltitude: Double {
        switch self {
        case .metro: return 3000       // City overview (was 2000, too close)
        case .cercanias: return 4500   // Regional view
        case .metroLigero: return 3000
        case .tranvia: return 2500     // City view
        case .bus: return 2500
        case .walking: return 2000     // Neighborhood view (was 1200, too close)
        }
    }

    /// Camera pitch for 3D preview (0 = top-down, 90 = horizontal)
    var cameraPitch: Double {
        switch self {
        case .metro: return 60
        case .cercanias: return 50
        case .metroLigero: return 55
        case .tranvia: return 65
        case .bus: return 60
        case .walking: return 70     // More horizontal for walking
        }
    }
}
