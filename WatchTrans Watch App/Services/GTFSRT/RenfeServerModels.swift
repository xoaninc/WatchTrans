//
//  RenfeServerModels.swift
//  WatchTrans Watch App
//
//  Created by Claude on 15/1/26.
//  Codable models for RenfeServer API responses (api.watchtrans.app)
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

    // Frequency-based departures (Metro)
    let frequencyBased: Bool?
    let headwaySecs: Int?

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

/// Response from GET /api/gtfs/networks
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
    let routeCount: Int?
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        code = (try? container.decode(String.self, forKey: .code)) ?? ""
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        region = (try? container.decode(String.self, forKey: .region)) ?? ""
        color = (try? container.decode(String.self, forKey: .color)) ?? ""
        textColor = (try? container.decode(String.self, forKey: .textColor)) ?? ""
        logoUrl = try? container.decodeIfPresent(String.self, forKey: .logoUrl)
        wikipediaUrl = try? container.decodeIfPresent(String.self, forKey: .wikipediaUrl)
        description = try? container.decodeIfPresent(String.self, forKey: .description)
        nucleoIdRenfe = try? container.decodeIfPresent(Int.self, forKey: .nucleoIdRenfe)
        routeCount = try? container.decodeIfPresent(Int.self, forKey: .routeCount)
        transportType = try? container.decodeIfPresent(String.self, forKey: .transportType)
    }
}

// MARK: - Route Response

/// Response from GET /api/gtfs/routes
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

/// Response from GET /api/gtfs/stops and /api/gtfs/stops/by-coordinates
struct StopResponse: Codable, Identifiable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    let sequence: Int?
    let code: String?
    let locationType: Int
    let parentStationId: String?
    let zoneId: String?

    // Additional fields from by-coordinates endpoint
    let province: String?
    let lineas: String?  // Comma-separated line names: "C1,C10,C2,C3"
    let parkingBicis: String?
    let accesibilidad: String?
    let corMetro: String?      // Metro connections: "L1, L10" or "L6, L8, L10"
    let corMl: String?         // Metro Ligero connections: "ML1" or "ML2, ML3"
    let corCercanias: String?  // Cercanías connections: "C1, C10, C2" (for Metro/ML stops)
    let corTranvia: String?    // Tram connections: "T1"
    let corBus: String?        // Bus connections
    let corFunicular: String?  // Funicular connections
    let isHub: Bool?           // true if station has 2+ different transport types

    enum CodingKeys: String, CodingKey {
        case id, name, lat, lon, sequence, code, province, accesibilidad, lineas
        case locationType = "location_type"
        case parentStationId = "parent_station_id"
        case zoneId = "zone_id"
        case parkingBicis = "parking_bicis"
        case corBus = "cor_bus"
        case corMetro = "cor_metro"
        case corMl = "cor_ml"
        case corCercanias = "cor_cercanias"
        case corTranvia = "cor_tranvia"
        case corFunicular = "cor_funicular"
        case isHub = "is_hub"
    }

    /// Parse lineas string into array of line IDs
    var lineIds: [String] {
        guard let lineas = lineas, !lineas.isEmpty else { return [] }
        return lineas.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
    }
}

// MARK: - Trip Detail Response

/// Response from GET /api/gtfs/trips/{trip_id}
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

/// Response from GET /api/gtfs/realtime/alerts
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
    let informedEntities: [InformedEntity]?
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

/// Response from GET /api/gtfs/realtime/estimated
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

/// Response from GET /api/gtfs/routes/{route_id}/operating-hours
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

/// Response from GET /api/gtfs/routes/{route_id}/frequencies
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

/// Response from GET /api/gtfs/stops/{stop_id}/platforms
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
    let platformCode: String?   // "Vía 1", "Andén 2", etc.
    let lat: Double
    let lon: Double
    let source: String?         // "osm", "manual", etc.
    let color: String?
    let description: String?
    let operatorId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case stopId = "stop_id"
        case lines
        case platformCode = "platform_code"
        case lat, lon, source, color, description
        case operatorId = "operator_id"
    }

    /// Stable identifier for UI lists (API may return duplicated id values)
    var stableId: String {
        let code = platformCode ?? ""
        let cleanedLines = lines.replacingOccurrences(of: " ", with: "")
        return "\(stopId)|\(code)|\(cleanedLines)|\(lat)|\(lon)"
    }

    /// Parse lines string into array
    var linesList: [String] {
        lines.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// MARK: - Correspondence Response

/// Response from GET /api/gtfs/stops/{stop_id}/correspondences
/// Contains walking connections to other nearby stations
struct CorrespondencesResponse: Codable {
    let stopId: String
    let stopName: String
    let correspondences: [CorrespondenceInfo]?
    let transportModes: [TransportModeInfo]?
    let isHub: Bool?

    enum CodingKeys: String, CodingKey {
        case stopId = "stop_id"
        case stopName = "stop_name"
        case correspondences
        case transportModes = "transport_modes"
        case isHub = "is_hub"
    }
}

/// Connection modes available at a stop (e.g., metro lines, tram lines)
struct TransportModeInfo: Codable, Identifiable {
    let transportType: String
    let lines: String

    var id: String { "\(transportType)-\(lines)" }

    enum CodingKeys: String, CodingKey {
        case transportType = "transport_type"
        case lines
    }
}

/// Information about a walking connection to another station
struct CorrespondenceInfo: Codable, Identifiable {
    let id: Int?
    let toStopId: String
    let toStopName: String?
    let toLines: String?         // "L3, L5, C5"
    let toTransportTypes: [String]?  // ["metro", "cercanias", "tranvia"]
    let distanceM: Int?          // Distance in meters
    let walkTimeS: Int?          // Walk time in seconds
    let source: String?          // "manual", "proximity", etc.

    enum CodingKeys: String, CodingKey {
        case id
        case toStopId = "to_stop_id"
        case toStopName = "to_stop_name"
        case toLines = "to_lines"
        case toTransportTypes = "to_transport_types"
        case distanceM = "distance_m"
        case walkTimeS = "walk_time_s"
        case source
    }

    /// Stable identifier for UI
    var identifiableId: String {
        if let id = id { return String(id) }
        return toStopId
    }

    /// Walk time formatted as "X min"
    var walkTimeFormatted: String {
        guard let walkTimeS = walkTimeS else { return "" }
        let minutes = walkTimeS / 60
        if minutes < 1 {
            return "<1 min"
        }
        return "\(minutes) min"
    }

    /// Distance formatted as "Xm" or "X.Xkm"
    var distanceFormatted: String {
        guard let distanceM = distanceM else { return "" }
        if distanceM < 1000 {
            return "\(distanceM)m"
        }
        let km = Double(distanceM) / 1000.0
        return String(format: "%.1fkm", km)
    }

    /// Parse lines string into array
    var linesList: [String] {
        guard let toLines = toLines else { return [] }
        return toLines.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// MARK: - Route Shape Response (for map polylines)

/// Response from GET /api/gtfs/routes/{route_id}/shape
/// Contains the polyline coordinates for drawing the route on a map
struct RouteShapeResponse: Codable {
    let routeId: String
    let routeShortName: String?
    let shape: [ShapePoint]

    enum CodingKeys: String, CodingKey {
        case routeId = "route_id"
        case routeShortName = "route_short_name"
        case shape
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

// MARK: - Station Accesses Response

/// Response from GET /api/gtfs/stops/{stop_id}/accesses
/// Contains all physical entrances (bocas de metro) for a station
struct AccessesResponse: Codable {
    let stopId: String
    let stopName: String
    let accesses: [StationAccess]

    enum CodingKeys: String, CodingKey {
        case stopId = "stop_id"
        case stopName = "stop_name"
        case accesses
    }
}

/// A physical entrance/access point to a station
struct StationAccess: Codable, Identifiable {
    let id: Int
    let stopId: String
    let name: String
    let lat: Double
    let lon: Double
    let street: String?
    let streetNumber: String?
    let openingTime: String?
    let closingTime: String?
    let wheelchair: Bool?
    let level: Int?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case id
        case stopId = "stop_id"
        case name, lat, lon, street
        case streetNumber = "street_number"
        case openingTime = "opening_time"
        case closingTime = "closing_time"
        case wheelchair, level, source
    }

    /// Full address string
    var address: String {
        if let street = street {
            if let number = streetNumber, !number.isEmpty {
                return "\(street), \(number)"
            }
            return street
        }
        return name
    }

    /// Opening hours string
    var hoursString: String? {
        guard let open = openingTime, let close = closingTime else { return nil }
        return "\(open) - \(close)"
    }

    /// Check if currently open
    var isCurrentlyOpen: Bool {
        guard let open = openingTime, let close = closingTime else { return true }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        guard let openDate = formatter.date(from: open),
              let closeDate = formatter.date(from: close) else { return true }

        let now = Date()
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        guard let nowTime = calendar.date(from: nowComponents) else { return true }

        let openComponents = calendar.dateComponents([.hour, .minute], from: openDate)
        let closeComponents = calendar.dateComponents([.hour, .minute], from: closeDate)
        guard let openTime = calendar.date(from: openComponents),
              let closeTime = calendar.date(from: closeComponents) else { return true }

        if closeTime < openTime {
            return nowTime >= openTime || nowTime <= closeTime
        }

        return nowTime >= openTime && nowTime <= closeTime
    }
}

/// Complete journey from origin to destination
struct RoutePlanJourney: Codable {
    let origin: RoutePlanStop
    let destination: RoutePlanStop
    let totalDurationMinutes: Int
    let totalWalkingMinutes: Int
    let totalTransitMinutes: Int
    let transferCount: Int
    let segments: [RoutePlanSegment]

    enum CodingKeys: String, CodingKey {
        case origin, destination, segments
        case totalDurationMinutes = "total_duration_minutes"
        case totalWalkingMinutes = "total_walking_minutes"
        case totalTransitMinutes = "total_transit_minutes"
        case transferCount = "transfer_count"
    }
}

/// A stop in the route plan
struct RoutePlanStop: Codable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
}

/// A segment of the journey (transit or walking)
struct RoutePlanSegment: Codable {
    let type: String                    // "transit" or "walking"
    let transportMode: String           // "metro", "cercanias", "walking", etc.
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

    enum CodingKeys: String, CodingKey {
        case type, origin, destination, coordinates, headsign
        case transportMode = "transport_mode"
        case lineId = "line_id"
        case lineName = "line_name"
        case lineColor = "line_color"
        case intermediateStops = "intermediate_stops"
        case durationMinutes = "duration_minutes"
        case distanceMeters = "distance_meters"
    }
}

/// A coordinate in the route plan segment
struct RoutePlanCoordinate: Codable {
    let lat: Double
    let lon: Double
}
