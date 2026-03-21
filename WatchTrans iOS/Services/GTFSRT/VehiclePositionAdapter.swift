//
//  VehiclePositionAdapter.swift
//  WatchTrans
//
//  Created by System on 03/02/26.
//  Adapter to convert new GTFS-RT vehicle format to EstimatedPosition
//

import Foundation

// MARK: - AnyCodableValue

/// A type-erased Codable value for handling dynamic JSON fields like raw_data
enum AnyCodableValue: Codable {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            self = .double(doubleVal)
        } else if let stringVal = try? container.decode(String.self) {
            self = .string(stringVal)
        } else if let boolVal = try? container.decode(Bool.self) {
            self = .bool(boolVal)
        } else if container.decodeNil() {
            self = .null
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }

    var intValue: Int? {
        switch self {
        case .int(let v): return v
        case .double(let v): return Int(v)
        default: return nil
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let v): return v
        default: return nil
        }
    }
}

/// New GTFS-RT vehicle position format from newserver_01
struct VehiclePositionResponse: Codable {
    let id: String
    let operatorId: String
    let vehicleId: String
    let latitude: Double?
    let longitude: Double?
    let bearing: Double?
    let speed: Double?
    let timestamp: String
    
    // Enriched fields (when enrich=true)
    let tripId: String?
    let routeId: String?
    let routeShortName: String?
    let routeColor: String?
    let headsign: String?
    let currentStopSequence: Int?
    let currentStatus: String?
    let vehicleLabel: String?
    let rawData: [String: AnyCodableValue]?

    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, bearing, speed, timestamp, headsign
        case operatorId = "operator_id"
        case vehicleId = "vehicle_id"
        case tripId = "trip_id"
        case routeId = "route_id"
        case routeShortName = "route_short_name"
        case routeColor = "route_color"
        case currentStopSequence = "current_stop_sequence"
        case currentStatus = "current_status"
        case vehicleLabel = "vehicle_label"
        case rawData = "raw_data"
    }
}

/// Adapter to convert VehiclePositionResponse to EstimatedPositionResponse
struct VehiclePositionAdapter {
    
    /// Convert new format to old EstimatedPositionResponse
    static func toEstimatedPosition(_ vehicle: VehiclePositionResponse) -> EstimatedPositionResponse? {
        // If the vehicle already has enrich data (server fixed), use it
        if let tripId = vehicle.tripId,
           let routeId = vehicle.routeId,
           let routeShortName = vehicle.routeShortName,
           let lat = vehicle.latitude,
           let lon = vehicle.longitude {
            
            let position = PositionSchema(latitude: lat, longitude: lon)
            let status = vehicle.currentStatus ?? "IN_TRANSIT_TO"
            
            return EstimatedPositionResponse(
                tripId: tripId,
                routeId: routeId,
                routeShortName: routeShortName,
                routeColor: vehicle.routeColor,
                headsign: vehicle.headsign,
                position: position,
                currentStatus: status,
                currentStopId: nil, // Server might not provide this yet in v1
                currentStopName: nil,
                nextStopId: nil,
                nextStopName: nil,
                progressPercent: nil,
                estimated: true
            )
        }
        
        // Fallback: Require minimum fields
        guard let lat = vehicle.latitude,
              let lon = vehicle.longitude,
              let tripId = vehicle.tripId,
              let routeId = vehicle.routeId,
              let routeShortName = vehicle.routeShortName else {
            return nil
        }
        
        let position = PositionSchema(
            latitude: lat,
            longitude: lon
        )
        
        // Map status
        let status = vehicle.currentStatus ?? "UNKNOWN"
        
        return EstimatedPositionResponse(
            tripId: tripId,
            routeId: routeId,
            routeShortName: routeShortName,
            routeColor: vehicle.routeColor,
            headsign: vehicle.headsign,
            position: position,
            currentStatus: status,
            currentStopId: nil,
            currentStopName: nil,
            nextStopId: nil,
            nextStopName: nil,
            progressPercent: nil,
            estimated: true
        )
    }
    
    /// Convert array
    static func toEstimatedPositions(_ vehicles: [VehiclePositionResponse]) -> [EstimatedPositionResponse] {
        return vehicles.compactMap { toEstimatedPosition($0) }
    }
}

// MARK: - Air Quality Extraction

extension VehiclePositionAdapter {

    /// Extract air quality data from a vehicle's raw_data dictionary
    static func extractAirQuality(from vehicle: VehiclePositionResponse) -> TrainAirQuality? {
        guard let rawData = vehicle.rawData else { return nil }

        let co2 = rawData["co2"]?.intValue
        let humidity = rawData["humidity"]?.intValue
        let temperature = rawData["temperature"]?.intValue
        let co2Rating = rawData["co2_rating"]?.stringValue

        // Only return if we have at least some air quality data
        guard co2 != nil || humidity != nil || temperature != nil || co2Rating != nil else {
            return nil
        }

        return TrainAirQuality(vehicleId: nil, co2: co2, humidity: humidity, temperature: temperature, co2Rating: co2Rating)
    }

    /// Extract air quality for all Metro Sevilla vehicles, keyed by vehicle_label
    static func extractAllAirQuality(from vehicles: [VehiclePositionResponse]) -> [String: TrainAirQuality] {
        var result: [String: TrainAirQuality] = [:]
        for vehicle in vehicles {
            // Use vehicleLabel if available, fallback to vehicleId
            let key = vehicle.vehicleLabel ?? vehicle.vehicleId
            if let airQuality = extractAirQuality(from: vehicle) {
                result[key] = airQuality
            }
        }
        return result
    }
}

/// Extension to GTFSRealtimeService to use adapter
extension GTFSRealtimeService {

    /// Fetch vehicle positions with new API and convert to old format
    func fetchVehiclePositionsConverted(operatorId: String) async throws -> [EstimatedPositionResponse] {
        // Need to access the network service - make it internal instead of private
        guard let url = URL(string: "\(APIConfiguration.gtfsRTBaseURL)/vehicles?operator_id=\(operatorId)&enrich=true") else {
            throw NetworkError.badResponse
        }

        DebugLog.log("🚗 [RT] Fetching vehicles (NEW format): \(url.absoluteString)")

        // Fetch data using NetworkService directly
        let networkService = NetworkService()
        let data = try await networkService.fetchData(url)
        let decoder = JSONDecoder()
        let vehicles = try decoder.decode([VehiclePositionResponse].self, from: data)

        DebugLog.log("🚗 [RT] Got \(vehicles.count) vehicles, converting to EstimatedPosition...")

        let estimated = VehiclePositionAdapter.toEstimatedPositions(vehicles)
        DebugLog.log("🚗 [RT] ✅ Converted \(estimated.count) vehicles")

        return estimated
    }

    /// Fetch air quality data from dedicated endpoint
    /// Returns a dictionary keyed by vehicle_id/train_code (e.g. "107")
    func fetchMetroSevillaAirQuality() async throws -> [String: TrainAirQuality] {
        guard let url = URL(string: "\(APIConfiguration.gtfsRTBaseURL)/air-quality/?operator_id=metro_sevilla") else {
            throw NetworkError.badResponse
        }

        DebugLog.log("🌿 [RT] Fetching air quality from dedicated endpoint")

        let networkService = NetworkService()
        let data = try await networkService.fetchData(url)
        let readings = try JSONDecoder().decode([TrainAirQuality].self, from: data)

        var result: [String: TrainAirQuality] = [:]
        for reading in readings {
            if let id = reading.vehicleId {
                result[id] = reading
            }
        }

        DebugLog.log("🌿 [RT] ✅ Got air quality for \(result.count) train units")
        return result
    }
}

