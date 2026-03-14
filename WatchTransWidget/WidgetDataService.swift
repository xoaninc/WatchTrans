//
//  WidgetDataService.swift
//  WatchTransWidgetExtension
//
//  Created by Conductor on 06/02/26.
//

import Foundation

/// Lightweight data service for Widgets - Dependency free (no Pulse, no complex retry)
class WidgetDataService {
    static let shared = WidgetDataService()
    
    // Hardcoded for Widget simplicity, or use shared APIConfiguration if available
    private let baseURL = "https://api.watch-trans.app/api/gtfs"
    
    private init() {}
    
    /// Fetch upcoming departures from a stop
    func fetchDepartures(stopId: String, limit: Int = 3) async throws -> [DepartureResponse] {
        guard let url = URL(string: "\(baseURL)/stops/\(stopId)/departures?limit=\(limit)") else {
            throw URLError(.badURL)
        }
        
        // Use standard URLSession.shared for widgets (background session support if needed later)
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, 
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        // Assuming DepartureResponse is available via target membership
        let departures = try decoder.decode([DepartureResponse].self, from: data)
        return departures
    }
    
    /// Fetch departures for multiple stops concurrently
    func fetchMultipleDepartures(stopIds: [String], limitPerStop: Int = 2) async -> [String: [DepartureResponse]] {
        var results: [String: [DepartureResponse]] = [:]
        
        await withTaskGroup(of: (String, [DepartureResponse]?).self) { group in
            for stopId in stopIds {
                group.addTask {
                    do {
                        let departures = try await self.fetchDepartures(stopId: stopId, limit: limitPerStop)
                        return (stopId, departures)
                    } catch {
                        return (stopId, nil)
                    }
                }
            }
            
            for await (stopId, departures) in group {
                if let departures = departures {
                    results[stopId] = departures
                }
            }
        }
        
        return results
    }
}
