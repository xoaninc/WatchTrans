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

// MARK: - ETA Response

/// Response from GET /api/v1/gtfs/eta/stops/{stop_id}
struct ETAResponse: Codable, Identifiable {
    let tripId: String
    let stopId: String
    let scheduledArrival: Date
    let estimatedArrival: Date
    let delaySeconds: Int
    let delayMinutes: Int
    let isDelayed: Bool
    let isOnTime: Bool
    let confidenceLevel: String    // "high", "medium", "low"
    let calculationMethod: String
    let vehicleId: String?
    let distanceToStopMeters: Double?
    let currentStopId: String?
    let calculatedAt: Date

    var id: String { "\(tripId)_\(stopId)" }

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case stopId = "stop_id"
        case scheduledArrival = "scheduled_arrival"
        case estimatedArrival = "estimated_arrival"
        case delaySeconds = "delay_seconds"
        case delayMinutes = "delay_minutes"
        case isDelayed = "is_delayed"
        case isOnTime = "is_on_time"
        case confidenceLevel = "confidence_level"
        case calculationMethod = "calculation_method"
        case vehicleId = "vehicle_id"
        case distanceToStopMeters = "distance_to_stop_meters"
        case currentStopId = "current_stop_id"
        case calculatedAt = "calculated_at"
    }
}

// MARK: - Stop Delay Response

/// Response from GET /api/v1/gtfs/realtime/stops/{stop_id}/delays
struct StopDelayResponse: Codable {
    let tripId: String
    let stopId: String
    let arrivalDelay: Int?
    let arrivalTime: Date?
    let departureDelay: Int?
    let departureTime: Date?

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case stopId = "stop_id"
        case arrivalDelay = "arrival_delay"
        case arrivalTime = "arrival_time"
        case departureDelay = "departure_delay"
        case departureTime = "departure_time"
    }
}

// MARK: - Vehicle Position Response

/// Response from GET /api/v1/gtfs/realtime/vehicles
struct VehiclePositionResponse: Codable, Identifiable {
    let vehicleId: String
    let tripId: String
    let position: PositionSchema
    let currentStatus: String
    let stopId: String?
    let label: String?
    let timestamp: Date
    let updatedAt: Date?

    var id: String { vehicleId }

    enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
        case tripId = "trip_id"
        case position
        case currentStatus = "current_status"
        case stopId = "stop_id"
        case label, timestamp
        case updatedAt = "updated_at"
    }
}

struct PositionSchema: Codable {
    let latitude: Double
    let longitude: Double
}

// MARK: - Network Response

/// Response from GET /api/v1/gtfs/networks
struct NetworkResponse: Codable, Identifiable {
    let code: String
    let name: String
    let city: String
    let region: String
    let color: String
    let textColor: String
    let logoUrl: String?
    let wikipediaUrl: String?
    let description: String?
    let routeCount: Int

    var id: String { code }

    enum CodingKeys: String, CodingKey {
        case code, name, city, region, color, description
        case textColor = "text_color"
        case logoUrl = "logo_url"
        case wikipediaUrl = "wikipedia_url"
        case routeCount = "route_count"
    }
}

// MARK: - Network Detail Response

/// Response from GET /api/v1/gtfs/networks/{code}
struct NetworkDetailResponse: Codable, Identifiable {
    let code: String
    let name: String
    let city: String
    let region: String
    let color: String
    let textColor: String
    let logoUrl: String?
    let wikipediaUrl: String?
    let description: String?
    let routeCount: Int
    let lines: [LineResponse]

    var id: String { code }

    enum CodingKeys: String, CodingKey {
        case code, name, city, region, color, description, lines
        case textColor = "text_color"
        case logoUrl = "logo_url"
        case wikipediaUrl = "wikipedia_url"
        case routeCount = "route_count"
    }
}

// MARK: - Line Response

/// Line within a network
struct LineResponse: Codable, Identifiable {
    let lineCode: String
    let color: String
    let textColor: String
    let routeCount: Int
    let routes: [[String: AnyCodableValue]]  // Flexible structure for route details

    var id: String { lineCode }

    enum CodingKeys: String, CodingKey {
        case color, routes
        case lineCode = "line_code"
        case textColor = "text_color"
        case routeCount = "route_count"
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

    enum CodingKeys: String, CodingKey {
        case id, color
        case shortName = "short_name"
        case longName = "long_name"
        case routeType = "route_type"
        case textColor = "text_color"
        case agencyId = "agency_id"
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
    let nucleoId: Int?
    let nucleoName: String?
    let lineas: String?  // Comma-separated line names: "C1,C10,C2,C3"
    let parkingBicis: String?
    let accesibilidad: String?
    let corBus: String?
    let corMetro: String?

    enum CodingKeys: String, CodingKey {
        case id, name, lat, lon, code, province, accesibilidad, lineas
        case locationType = "location_type"
        case parentStationId = "parent_station_id"
        case zoneId = "zone_id"
        case nucleoId = "nucleo_id"
        case nucleoName = "nucleo_name"
        case parkingBicis = "parking_bicis"
        case corBus = "cor_bus"
        case corMetro = "cor_metro"
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

// MARK: - Trip Update Response (Realtime)

/// Response from GET /api/v1/gtfs/realtime/delays
struct TripUpdateResponse: Codable, Identifiable {
    let tripId: String
    let delay: Int
    let delayMinutes: Int
    let isDelayed: Bool
    let vehicleId: String?
    let wheelchairAccessible: Bool?
    let timestamp: Date
    let updatedAt: Date?

    var id: String { tripId }

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case delay
        case delayMinutes = "delay_minutes"
        case isDelayed = "is_delayed"
        case vehicleId = "vehicle_id"
        case wheelchairAccessible = "wheelchair_accessible"
        case timestamp
        case updatedAt = "updated_at"
    }
}

// MARK: - Nucleo Response

/// Response from GET /api/v1/gtfs/nucleos
struct NucleoResponse: Codable, Identifiable {
    let id: Int
    let name: String
    let color: String
    let boundingBoxMinLat: Double
    let boundingBoxMaxLat: Double
    let boundingBoxMinLon: Double
    let boundingBoxMaxLon: Double
    let centerLat: Double
    let centerLon: Double
    let stationsCount: Int
    let linesCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, color
        case boundingBoxMinLat = "bounding_box_min_lat"
        case boundingBoxMaxLat = "bounding_box_max_lat"
        case boundingBoxMinLon = "bounding_box_min_lon"
        case boundingBoxMaxLon = "bounding_box_max_lon"
        case centerLat = "center_lat"
        case centerLon = "center_lon"
        case stationsCount = "stations_count"
        case linesCount = "lines_count"
    }

    /// Check if coordinates are within this nucleo's bounding box
    func contains(latitude: Double, longitude: Double) -> Bool {
        return latitude >= boundingBoxMinLat && latitude <= boundingBoxMaxLat &&
               longitude >= boundingBoxMinLon && longitude <= boundingBoxMaxLon
    }
}

// MARK: - Alert Response

/// Response from GET /api/v1/gtfs/realtime/alerts
struct AlertResponse: Codable, Identifiable {
    let alertId: String
    let cause: String
    let effect: String
    let headerText: String?
    let descriptionText: String
    let url: String?
    let activePeriodStart: Date?
    let activePeriodEnd: Date?
    let isActive: Bool
    let informedEntities: [InformedEntity]
    let timestamp: Date
    let updatedAt: Date?

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
    let stopId: String?
    let tripId: String?
    let agencyId: String?
    let routeType: Int?

    enum CodingKeys: String, CodingKey {
        case routeId = "route_id"
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

// MARK: - AnyCodableValue for flexible JSON

/// Helper for decoding flexible JSON structures
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}
