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
    var animationSpeed: Double {
        switch self {
        case .metro: return 1.5      // Fast underground
        case .cercanias: return 1.8  // Fastest
        case .metroLigero: return 1.2
        case .tranvia: return 1.0
        case .bus: return 0.8
        case .walking: return 0.3    // Slow walking
        }
    }

    /// Camera altitude for 3D preview
    var cameraAltitude: Double {
        switch self {
        case .metro: return 200      // Low, close to ground
        case .cercanias: return 400  // Higher for longer distances
        case .metroLigero: return 250
        case .tranvia: return 150    // Street level
        case .bus: return 150
        case .walking: return 100    // Very close, pedestrian view
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

// MARK: - Graph Node for Routing

/// Node in the transit graph for pathfinding
struct TransitNode: Hashable {
    let stopId: String
    let lineId: String?  // nil for transfer nodes

    func hash(into hasher: inout Hasher) {
        hasher.combine(stopId)
        hasher.combine(lineId)
    }

    static func == (lhs: TransitNode, rhs: TransitNode) -> Bool {
        lhs.stopId == rhs.stopId && lhs.lineId == rhs.lineId
    }
}

/// Edge in the transit graph
struct TransitEdge {
    let from: TransitNode
    let to: TransitNode
    let weight: Double        // Time in minutes
    let type: EdgeType
    let lineId: String?
    let lineName: String?
    let lineColor: String?
}

enum EdgeType {
    case ride       // Riding on a line
    case transfer   // Walking transfer between lines
    case boarding   // Boarding a line at a stop
    case alighting  // Getting off a line at a stop
}
