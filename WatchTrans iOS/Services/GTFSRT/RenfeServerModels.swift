//
//  RenfeServerModels.swift
//  WatchTrans Watch App
//
//  Created by Claude on 15/1/26.
//  Codable models for RenfeServer API responses (redcercanias.com)
//

import Foundation

// MARK: - Departure Response

/// Response from GET /api/v1/gtfs/stops/{stop_id}/departures
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

    // Frequency-based departures (Metro)
    let frequencyBased: Bool?
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
        case frequencyBased = "frequency_based"
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

// MARK: - Network Response

/// Response from GET /api/v1/gtfs/networks
struct NetworkResponse: Codable, Identifiable {
    let code: String
    let name: String
    let region: String
    let color: String
    let textColor: String
    let logoUrl: String?
    let wikipediaUrl: String?
    let description: String?
    let nucleoIdRenfe: Int?  // Legacy Renfe nucleo ID for compatibility
    let routeCount: Int
    let transportType: String?  // "cercanias", "metro", "metro_ligero", "tranvia", "fgc", "euskotren", "other"

    var id: String { code }

    enum CodingKeys: String, CodingKey {
        case code, name, region, color, description
        case textColor = "text_color"
        case logoUrl = "logo_url"
        case wikipediaUrl = "wikipedia_url"
        case nucleoIdRenfe = "nucleo_id_renfe"
        case routeCount = "route_count"
        case transportType = "transport_type"
    }
}

// MARK: - Route Response

/// Response from GET /api/v1/gtfs/routes
struct RouteResponse: Codable, Identifiable {
    let id: String
    let shortName: String
    let longName: String
    let routeType: Int
    let color: String?
    let textColor: String?
    let agencyId: String
    let networkId: String?  // Network ID (e.g., "51T", "TMB_METRO", "FGC")
    let description: String?  // e.g., "Andén 1: Sentido horario | Andén 2: Sentido antihorario"
    let isCircular: Bool?  // true for circular lines (L6, L12 MetroSur)

    enum CodingKeys: String, CodingKey {
        case id, color, description
        case shortName = "short_name"
        case longName = "long_name"
        case routeType = "route_type"
        case textColor = "text_color"
        case agencyId = "agency_id"
        case networkId = "network_id"
        case isCircular = "is_circular"
    }
}

// MARK: - Stop Response

/// Response from GET /api/v1/gtfs/stops and /api/v1/gtfs/stops/by-coordinates
struct StopResponse: Codable, Identifiable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    let code: String?
    let locationType: Int
    let parentStationId: String?
    let zoneId: String?

    // Additional fields from by-coordinates endpoint
    let province: String?
    let lineas: String?  // Comma-separated line names: "C1,C10,C2,C3"
    let parkingBicis: String?
    let accesibilidad: String?
    let corBus: String?
    let corMetro: String?      // Metro connections: "L1, L10" or "L6, L8, L10"
    let corMl: String?         // Metro Ligero connections: "ML1" or "ML2, ML3"
    let corCercanias: String?  // Cercanías connections: "C1, C10, C2" (for Metro/ML stops)
    let corTranvia: String?    // Tram connections: "T1"
    let isHub: Bool?           // true if station has 2+ different transport types

    enum CodingKeys: String, CodingKey {
        case id, name, lat, lon, code, province, accesibilidad, lineas
        case locationType = "location_type"
        case parentStationId = "parent_station_id"
        case zoneId = "zone_id"
        case parkingBicis = "parking_bicis"
        case corBus = "cor_bus"
        case corMetro = "cor_metro"
        case corMl = "cor_ml"
        case corCercanias = "cor_cercanias"
        case corTranvia = "cor_tranvia"
        case isHub = "is_hub"
    }

    /// Parse lineas string into array of line IDs
    var lineIds: [String] {
        guard let lineas = lineas, !lineas.isEmpty else { return [] }
        return lineas.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
    }
}

// MARK: - Trip Detail Response

/// Response from GET /api/v1/gtfs/trips/{trip_id}
struct TripDetailResponse: Codable, Identifiable {
    let id: String
    let routeId: String
    let routeShortName: String
    let routeLongName: String
    let routeColor: String?
    let headsign: String?
    let directionId: Int?
    let stops: [TripStopResponse]

    enum CodingKeys: String, CodingKey {
        case id, headsign, stops
        case routeId = "route_id"
        case routeShortName = "route_short_name"
        case routeLongName = "route_long_name"
        case routeColor = "route_color"
        case directionId = "direction_id"
    }
}

struct TripStopResponse: Codable {
    let stopId: String
    let stopName: String
    let arrivalTime: String
    let departureTime: String
    let stopSequence: Int
    let stopLat: Double
    let stopLon: Double

    enum CodingKeys: String, CodingKey {
        case stopId = "stop_id"
        case stopName = "stop_name"
        case arrivalTime = "arrival_time"
        case departureTime = "departure_time"
        case stopSequence = "stop_sequence"
        case stopLat = "stop_lat"
        case stopLon = "stop_lon"
    }
}

// MARK: - Network Info

/// Network info for transport networks
struct NetworkInfo: Codable, Identifiable {
    let code: String
    let name: String
    let transportType: String?  // "cercanias", "metro", "metro_ligero", "tranvia", "fgc", "euskotren", "other"

    var id: String { code }

    init(code: String, name: String, transportType: String? = nil) {
        self.code = code
        self.name = name
        self.transportType = transportType
    }
}

// MARK: - Alert Response

/// Response from GET /api/v1/gtfs/realtime/alerts
struct AlertResponse: Codable, Identifiable {
    let alertId: String
    let cause: String?
    let effect: String?
    let headerText: String?
    let descriptionText: String?  // Can be null in API
    let url: String?
    let activePeriodStart: String?
    let activePeriodEnd: String?
    let isActive: Bool?
    let informedEntities: [InformedEntity]
    let timestamp: String?
    let updatedAt: String?

    var id: String { alertId }

    enum CodingKeys: String, CodingKey {
        case alertId = "alert_id"
        case cause, effect, url, timestamp
        case headerText = "header_text"
        case descriptionText = "description_text"
        case activePeriodStart = "active_period_start"
        case activePeriodEnd = "active_period_end"
        case isActive = "is_active"
        case informedEntities = "informed_entities"
        case updatedAt = "updated_at"
    }
}

/// Entity affected by an alert
struct InformedEntity: Codable {
    let routeId: String?
    let routeShortName: String?  // e.g., "C5", "C1", "C8a"
    let stopId: String?
    let tripId: String?
    let agencyId: String?
    let routeType: Int?

    enum CodingKeys: String, CodingKey {
        case routeId = "route_id"
        case routeShortName = "route_short_name"
        case stopId = "stop_id"
        case tripId = "trip_id"
        case agencyId = "agency_id"
        case routeType = "route_type"
    }
}

// MARK: - Estimated Position Response

/// Response from GET /api/v1/gtfs/realtime/estimated
struct EstimatedPositionResponse: Codable, Identifiable {
    let tripId: String
    let routeId: String
    let routeShortName: String
    let routeColor: String?
    let headsign: String?
    let position: PositionSchema
    let currentStatus: String
    let currentStopId: String?
    let currentStopName: String?
    let nextStopId: String?
    let nextStopName: String?
    let progressPercent: Double?
    let estimated: Bool

    var id: String { tripId }

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case routeId = "route_id"
        case routeShortName = "route_short_name"
        case routeColor = "route_color"
        case headsign, position, estimated
        case currentStatus = "current_status"
        case currentStopId = "current_stop_id"
        case currentStopName = "current_stop_name"
        case nextStopId = "next_stop_id"
        case nextStopName = "next_stop_name"
        case progressPercent = "progress_percent"
    }
}

struct PositionSchema: Codable {
    let latitude: Double
    let longitude: Double
}

// MARK: - Route Operating Hours Response

/// Response from GET /api/v1/gtfs/routes/{route_id}/operating-hours
/// For schedule-based routes like Cercanías (derived from stop_times)
struct RouteOperatingHoursResponse: Codable {
    let routeId: String
    let routeShortName: String
    let weekday: DayOperatingHours?
    let friday: DayOperatingHours?
    let saturday: DayOperatingHours?
    let sunday: DayOperatingHours?
    let isSuspended: Bool?
    let suspensionMessage: String?

    enum CodingKeys: String, CodingKey {
        case routeId = "route_id"
        case routeShortName = "route_short_name"
        case weekday, friday, saturday, sunday
        case isSuspended = "is_suspended"
        case suspensionMessage = "suspension_message"
    }
}

/// Operating hours for a specific day type
struct DayOperatingHours: Codable {
    let firstDeparture: String   // "05:30:00"
    let lastDeparture: String    // "23:45:00"
    let totalTrips: Int

    enum CodingKeys: String, CodingKey {
        case firstDeparture = "first_departure"
        case lastDeparture = "last_departure"
        case totalTrips = "total_trips"
    }

    /// Format for display: "05:30 - 23:45"
    var displayString: String {
        let start = formatTime(firstDeparture)
        let end = formatTime(lastDeparture)
        return "\(start) - \(end)"
    }

    private func formatTime(_ timeStr: String) -> String {
        let parts = timeStr.split(separator: ":")
        guard parts.count >= 2 else { return timeStr }
        let hour = Int(parts[0]) ?? 0
        let minute = Int(parts[1]) ?? 0
        return String(format: "%02d:%02d", hour % 24, minute)
    }
}

// MARK: - Frequency Response

/// Response from GET /api/v1/gtfs/routes/{route_id}/frequencies
/// Contains operating hours and headway information for frequency-based services
struct FrequencyResponse: Codable, Identifiable {
    let tripId: String?         // Optional - may not be present in API response
    let routeId: String?        // Optional - may not be present in API response
    let dayType: String         // "weekday", "saturday", "sunday"
    let startTime: String       // "06:05:00"
    let endTime: String         // "01:30:00" (can be > 24:00 for next day)
    let headwaySecs: Int

    var id: String { "\(tripId ?? "freq")_\(dayType)_\(startTime)" }

    /// Headway in minutes
    var headwayMinutes: Int {
        headwaySecs / 60
    }

    /// Parse time string to components (handles times > 24:00)
    func parseTime(_ timeStr: String) -> (hour: Int, minute: Int)? {
        let parts = timeStr.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        return (hour, minute)
    }

    /// Format time for display (converts 25:00 to 01:00)
    func formatTimeForDisplay(_ timeStr: String) -> String {
        guard let (hour, minute) = parseTime(timeStr) else { return timeStr }
        let displayHour = hour % 24
        return String(format: "%02d:%02d", displayHour, minute)
    }

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case routeId = "route_id"
        case dayType = "day_type"
        case startTime = "start_time"
        case endTime = "end_time"
        case headwaySecs = "headway_secs"
    }
}

// MARK: - Platform Response

/// Response from GET /api/v1/gtfs/stops/{stop_id}/platforms
/// Contains coordinates of each platform/line within a station
struct PlatformsResponse: Codable {
    let stopId: String
    let stopName: String
    let platforms: [PlatformInfo]

    enum CodingKeys: String, CodingKey {
        case stopId = "stop_id"
        case stopName = "stop_name"
        case platforms
    }
}

/// Information about a single platform within a station
struct PlatformInfo: Codable, Identifiable {
    let id: Int
    let stopId: String
    let lines: String           // "L10" or "L1, L2"
    let lat: Double
    let lon: Double
    let source: String          // "osm", "manual", etc.

    enum CodingKeys: String, CodingKey {
        case id
        case stopId = "stop_id"
        case lines, lat, lon, source
    }

    /// Parse lines string into array
    var linesList: [String] {
        lines.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// MARK: - Correspondence Response

/// Response from GET /api/v1/gtfs/stops/{stop_id}/correspondences
/// Contains walking connections to other nearby stations
struct CorrespondencesResponse: Codable {
    let stopId: String
    let stopName: String
    let correspondences: [CorrespondenceInfo]

    enum CodingKeys: String, CodingKey {
        case stopId = "stop_id"
        case stopName = "stop_name"
        case correspondences
    }
}

/// Information about a walking connection to another station
struct CorrespondenceInfo: Codable, Identifiable {
    let id: Int
    let toStopId: String
    let toStopName: String
    let toLines: String         // "L3, L5, C5"
    let toTransportTypes: [String]?  // ["metro", "cercanias", "tranvia"]
    let distanceM: Int          // Distance in meters
    let walkTimeS: Int          // Walk time in seconds
    let source: String          // "manual", "proximity", etc.
    let walkingShape: [ShapePoint]?  // Walking route coordinates (only with include_shape=true)

    enum CodingKeys: String, CodingKey {
        case id
        case toStopId = "to_stop_id"
        case toStopName = "to_stop_name"
        case toLines = "to_lines"
        case toTransportTypes = "to_transport_types"
        case distanceM = "distance_m"
        case walkTimeS = "walk_time_s"
        case source
        case walkingShape = "walking_shape"
    }

    /// Walk time formatted as "X min"
    var walkTimeFormatted: String {
        let minutes = walkTimeS / 60
        if minutes < 1 {
            return "<1 min"
        }
        return "\(minutes) min"
    }

    /// Distance formatted as "Xm" or "X.Xkm"
    var distanceFormatted: String {
        if distanceM < 1000 {
            return "\(distanceM)m"
        }
        let km = Double(distanceM) / 1000.0
        return String(format: "%.1fkm", km)
    }

    /// Parse lines string into array
    var linesList: [String] {
        toLines.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// MARK: - Route Shape Response (for map polylines)

/// Response from GET /api/v1/gtfs/routes/{route_id}/shape
/// Contains the polyline coordinates for drawing the route on a map
/// Use ?include_stops=true to get stop coordinates projected onto the shape
struct RouteShapeResponse: Codable {
    let routeId: String
    let routeShortName: String?
    let shape: [ShapePoint]
    let stops: [ShapeStop]?  // Only present with ?include_stops=true

    enum CodingKeys: String, CodingKey {
        case routeId = "route_id"
        case routeShortName = "route_short_name"
        case shape
        case stops
    }
}

/// A single point in a route shape
struct ShapePoint: Codable {
    let lat: Double
    let lon: Double
    let sequence: Int

    enum CodingKeys: String, CodingKey {
        case lat, lon, sequence
    }
}

/// Stop info with projected coordinates onto the shape
struct ShapeStop: Codable {
    let stopId: String
    let name: String
    let sequence: Int
    let onShape: Coordinate      // Coordinates projected onto the line shape (for map markers)
    let platform: Coordinate?    // Real platform coordinates (for navigation)

    enum CodingKeys: String, CodingKey {
        case stopId = "stop_id"
        case name
        case sequence
        case onShape = "on_shape"
        case platform
    }
}

/// Simple coordinate pair
struct Coordinate: Codable {
    let lat: Double
    let lon: Double
}

// MARK: - Route Planner Response

/// Response from GET /api/v1/gtfs/route-planner
/// Contains complete journeys (Pareto-optimal alternatives) with segments, times, and normalized coordinates
/// API v2 returns journeys[] (plural), alerts[], departure/arrival timestamps
struct RoutePlanResponse: Codable {
    let success: Bool
    let message: String?
    let journeys: [RoutePlanJourney]?  // Array of Pareto-optimal alternatives (best first)
    let alerts: [RouteAlert]?          // Service alerts affecting this route

    // Backwards compatibility: also accept singular journey
    let journey: RoutePlanJourney?

    /// Get all journeys (handles both old and new API format)
    var allJourneys: [RoutePlanJourney] {
        if let journeys = journeys, !journeys.isEmpty {
            return journeys
        }
        if let journey = journey {
            return [journey]
        }
        return []
    }

    /// Best journey (first in array = fastest/optimal)
    var bestJourney: RoutePlanJourney? {
        allJourneys.first
    }
}

/// Service alert affecting a route
struct RouteAlert: Codable {
    let lineId: String?
    let message: String
    let severity: String  // "info", "warning", "error"

    enum CodingKeys: String, CodingKey {
        case lineId = "line_id"
        case message, severity
    }
}

/// Complete journey from origin to destination (API v2 format)
struct RoutePlanJourney: Codable {
    let durationMinutes: Int
    let walkingMinutes: Int
    let transfers: Int
    let segments: [RoutePlanSegment]
    let departure: String?  // ISO8601 timestamp "2026-01-28T08:32:00"
    let arrival: String?    // ISO8601 timestamp "2026-01-28T09:07:00"

    enum CodingKeys: String, CodingKey {
        case segments, departure, arrival, transfers
        case durationMinutes = "duration_minutes"
        case walkingMinutes = "walking_minutes"
    }

    // Computed properties for compatibility
    var totalDurationMinutes: Int { durationMinutes }
    var totalWalkingMinutes: Int { walkingMinutes }
    var totalTransitMinutes: Int { durationMinutes - walkingMinutes }
    var transferCount: Int { transfers }

    /// Origin is first segment's origin
    var origin: RoutePlanStop? { segments.first?.origin }

    /// Destination is last segment's destination
    var destination: RoutePlanStop? { segments.last?.destination }

    /// Parsed departure time
    var departureDate: Date? {
        guard let departure = departure else { return nil }
        return ISO8601DateFormatter().date(from: departure)
    }

    /// Parsed arrival time
    var arrivalDate: Date? {
        guard let arrival = arrival else { return nil }
        return ISO8601DateFormatter().date(from: arrival)
    }
}

/// A stop in the route plan
struct RoutePlanStop: Codable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
}

/// A segment of the journey (transit or walking) - API v2 format
struct RoutePlanSegment: Codable {
    let type: String                    // "transit" or "walking"
    let mode: String?                   // "metro", "cercanias", "walking", etc.
    let lineId: String?
    let lineName: String?
    let lineColor: String?
    let headsign: String?
    let origin: RoutePlanStop
    let destination: RoutePlanStop
    let intermediateStops: [RoutePlanStop]?
    let durationMinutes: Int
    let distanceMeters: Int?
    let coordinates: [RoutePlanCoordinate]
    let suggestedHeading: Double?       // API v2: camera heading 0-360 degrees (0=north)
    let departure: String?              // API v2: segment departure time
    let arrival: String?                // API v2: segment arrival time

    enum CodingKeys: String, CodingKey {
        case type, mode, origin, destination, coordinates, headsign, departure, arrival
        case lineId = "line_id"
        case lineName = "line_name"
        case lineColor = "line_color"
        case intermediateStops = "intermediate_stops"
        case durationMinutes = "duration_minutes"
        case distanceMeters = "distance_meters"
        case suggestedHeading = "suggested_heading"
    }

    // Compatibility alias
    var transportMode: String { mode ?? type }
}

/// A coordinate in the route plan segment
struct RoutePlanCoordinate: Codable {
    let lat: Double
    let lon: Double
}
