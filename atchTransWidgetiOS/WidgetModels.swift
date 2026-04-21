//
//  WidgetModels.swift
//  WatchTransWidgetExtension
//
//  Created by Conductor on 06/02/26.
//

import Foundation

// MARK: - Departure Response

/// Response from GET /api/gtfs/stops/{stop_id}/departures
struct DepartureResponse: Codable, Identifiable {
    let tripId: String
    let routeId: String
    let routeShortName: String
    let routeColor: String?
    let headsign: String?
    let departureTime: String      // "HH:mm:ss" format
    let departureSeconds: Int      // Seconds since midnight
    let minutesUntil: Int
    let stopSequence: Int
    let platform: String?          // Platform number (if available from API)
    let platformEstimated: Bool?   // true if platform is estimated from historical data

    // Realtime fields
    let delaySeconds: Int?
    let realtimeDepartureTime: String?
    let realtimeMinutesUntil: Int?
    let isDelayed: Bool
    let trainPosition: TrainPositionResponse?

    // Route classification
    let routeType: Int?
    let headwaySecs: Int?

    // Occupancy data (GTFS-RT standard)
    let occupancyStatus: Int?       // 0-8 GTFS-RT OccupancyStatus
    let occupancyPercentage: Int?   // 0-100 percentage
    let occupancyPerCar: [Int]?     // Per-car occupancy percentages

    var id: String { tripId }

    /// Returns headway in minutes (for frequency-based services like Metro)
    var headwayMinutes: Int? {
        guard let secs = headwaySecs, secs > 0 else { return nil }
        return secs / 60
    }

    /// Returns the best available minutes until departure (realtime if available, otherwise scheduled)
    var effectiveMinutesUntil: Int {
        realtimeMinutesUntil ?? minutesUntil
    }

    /// Returns delay in minutes (nil if no delay info)
    var delayMinutes: Int? {
        guard let seconds = delaySeconds, seconds > 0 else { return nil }
        return seconds / 60
    }

    enum CodingKeys: String, CodingKey {
        case headsign, platform
        case tripId = "trip_id"
        case routeId = "route_id"
        case routeShortName = "route_short_name"
        case routeColor = "route_color"
        case departureTime = "departure_time"
        case departureSeconds = "departure_seconds"
        case minutesUntil = "minutes_until"
        case stopSequence = "stop_sequence"
        case platformEstimated = "platform_estimated"
        case delaySeconds = "delay_seconds"
        case realtimeDepartureTime = "realtime_departure_time"
        case realtimeMinutesUntil = "realtime_minutes_until"
        case isDelayed = "is_delayed"
        case trainPosition = "train_position"
        case routeType = "route_type"
        case headwaySecs = "headway_secs"
        case occupancyStatus = "occupancy_status"
        case occupancyPercentage = "occupancy_percentage"
        case occupancyPerCar = "occupancy_per_car"
    }
}

/// Train position info within departure
struct TrainPositionResponse: Codable {
    let latitude: Double
    let longitude: Double
    let currentStopName: String?
    let status: String?
    let progressPercent: Double?
    let estimated: Bool?

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, status, estimated
        case currentStopName = "current_stop_name"
        case progressPercent = "progress_percent"
    }
}
