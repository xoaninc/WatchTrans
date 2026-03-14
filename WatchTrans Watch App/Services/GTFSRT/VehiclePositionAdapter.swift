//
//  VehiclePositionAdapter.swift
//  WatchTrans
//
//  Created by System on 03/02/26.
//  Adapter to convert new GTFS-RT vehicle format to EstimatedPosition
//

import Foundation

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
    }
}

/// Adapter to convert VehiclePositionResponse to EstimatedPositionResponse
struct VehiclePositionAdapter {
    
    /// Convert new format to old EstimatedPositionResponse
    static func toEstimatedPosition(_ vehicle: VehiclePositionResponse) -> EstimatedPositionResponse? {
        // Require minimum fields
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
        let networkService = NetworkService.shared
        let data = try await networkService.fetchData(url)
        let decoder = JSONDecoder()
        let vehicles = try decoder.decode([VehiclePositionResponse].self, from: data)
        
        DebugLog.log("🚗 [RT] Got \(vehicles.count) vehicles, converting to EstimatedPosition...")
        
        let estimated = VehiclePositionAdapter.toEstimatedPositions(vehicles)
        DebugLog.log("🚗 [RT] ✅ Converted \(estimated.count) vehicles")
        
        return estimated
    }
}
