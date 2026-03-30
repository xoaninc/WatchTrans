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

    /// Journey departure time (from first segment)
    var departureTime: Date? {
        segments.first?.departureTime
    }

    /// Journey arrival time (from last segment)
    var arrivalTime: Date? {
        segments.last?.arrivalTime
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    /// Formatted departure time (HH:mm)
    var departureTimeString: String? {
        guard let time = departureTime else { return nil }
        return Self.timeFormatter.string(from: time)
    }

    /// Formatted arrival time (HH:mm)
    var arrivalTimeString: String? {
        guard let time = arrivalTime else { return nil }
        return Self.timeFormatter.string(from: time)
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
    let suggestedHeading: Double?   // Optional: Suggested camera heading for this segment
    let departureTime: Date?        // When this segment departs
    let arrivalTime: Date?          // When this segment arrives
    
    // RAPTOR Guidance
    let instructions: String?       // Specific guidance
    let entranceName: String?       // Which entrance to use at origin
    let exitName: String?           // Which exit to use at destination
    
    // Platform/Track information
    let platform: String?           // Platform/track number ("1", "2", "Vía 3", etc.)
    let platformEstimated: Bool     // true if platform is estimated

    /// All stops including origin and destination
    var allStops: [Stop] {
        [origin] + intermediateStops + [destination]
    }

    /// Number of stops (not counting origin)
    var stopCount: Int {
        intermediateStops.count + 1
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    /// Formatted departure time (HH:mm)
    var departureTimeString: String? {
        guard let time = departureTime else { return nil }
        return Self.timeFormatter.string(from: time)
    }

    /// Formatted arrival time (HH:mm)
    var arrivalTimeString: String? {
        guard let time = arrivalTime else { return nil }
        return Self.timeFormatter.string(from: time)
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
    case tren = "cercanias"
    case metroLigero = "metro_ligero"
    case tranvia = "tranvia"
    case bus = "bus"
    case walking = "walking"

    var icon: String {
        switch self {
        case .metro: return "MetroSymbol"
        case .tren: return "TrenSymbol"
        case .metroLigero: return "MetroSymbol"
        case .tranvia: return "TramSymbol"
        case .bus: return "BusSymbol"
        case .walking: return "figure.walk"
        }
    }

    /// Whether this mode uses a custom asset (true) or SF Symbol (false)
    var isCustomAsset: Bool {
        self != .walking
    }

    /// Localized UI label for each transport mode.
    /// These are UI-only display strings — they are NOT sent by the API.
    /// The API sends the raw `mode` string (e.g. "metro", "cercanias") which maps to `rawValue`.
    /// All mode labels are centralized here; do not add them in views or other models.
    var displayName: String {
        switch self {
        case .metro: return "Metro"
        case .tren: return "Cercanías"
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
        case .metro: return 1.5        // Fast urban transit (reduced from 2.0)
        case .tren: return 1.8    // Faster regional (reduced from 2.5)
        case .metroLigero: return 1.4
        case .tranvia: return 1.2
        case .bus: return 1.2
        case .walking: return 0.6      // Brisk walk (doubled from 0.3 to fix "stuck" progress bar feeling)
        }
    }

    /// Camera altitude for 3D preview (meters)
    var cameraAltitude: Double {
        switch self {
        case .metro: return 3600       // City overview (Zoomed out 20%)
        case .tren: return 5400   // Regional view (Zoomed out 20%)
        case .metroLigero: return 3600 // (Zoomed out 20%)
        case .tranvia: return 3000     // City view (Zoomed out 20%)
        case .bus: return 3000         // (Zoomed out 20%)
        case .walking: return 2000     // Neighborhood view (Unchanged)
        }
    }

    /// Camera pitch for 3D preview (0 = top-down, 90 = horizontal)
    var cameraPitch: Double {
        switch self {
        case .metro: return 60
        case .tren: return 50
        case .metroLigero: return 55
        case .tranvia: return 65
        case .bus: return 60
        case .walking: return 70     // More horizontal for walking
        }
    }
}
