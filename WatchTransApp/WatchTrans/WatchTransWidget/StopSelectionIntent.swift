//
//  StopSelectionIntent.swift
//  WatchTransWidget
//
//  AppIntent for configuring which stop to show in the widget
//

import AppIntents
import WidgetKit

// MARK: - Stop Entity

struct StopEntity: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Stop"

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = StopQuery()
}

// MARK: - Stop Query

struct StopQuery: EntityQuery {
    private let apiBaseURL = "https://redcercanias.com/api/v1/gtfs"

    func entities(for identifiers: [String]) async throws -> [StopEntity] {
        // Return entities for given IDs
        // For simplicity, we create entities directly from IDs
        return identifiers.map { StopEntity(id: $0, name: $0) }
    }

    func suggestedEntities() async throws -> [StopEntity] {
        // Fetch stops to suggest based on user's location
        return try await fetchNearbyStops()
    }

    func defaultResult() async -> StopEntity? {
        // Default: nearest stop or nil
        if let stops = try? await fetchNearbyStops(), let first = stops.first {
            return first
        }
        return nil
    }

    private func fetchNearbyStops() async throws -> [StopEntity] {
        // Get last known location from UserDefaults
        guard let lat = UserDefaults.standard.object(forKey: "lastLatitude") as? Double,
              let lon = UserDefaults.standard.object(forKey: "lastLongitude") as? Double else {
            // If no location, return some default Madrid stops
            return [
                StopEntity(id: "RENFE_17000", name: "Nuevos Ministerios"),
                StopEntity(id: "RENFE_18000", name: "Sol"),
                StopEntity(id: "RENFE_10000", name: "Atocha Cercanías")
            ]
        }

        // Fetch nearest stops from API
        let urlString = "\(apiBaseURL)/stops/by-coordinates?lat=\(lat)&lon=\(lon)&limit=10"
        guard let url = URL(string: urlString) else {
            return []
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let stops = try JSONDecoder().decode([APIStop].self, from: data)

        return stops.map { StopEntity(id: $0.id, name: $0.name) }
    }
}

// MARK: - API Stop Model

private struct APIStop: Codable {
    let id: String
    let name: String
}

// MARK: - Widget Configuration Intent

struct SelectStopIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Stop"
    static var description: IntentDescription = IntentDescription("Choose which stop to show departures for")

    @Parameter(title: "Stop")
    var stop: StopEntity?

    init() {}

    init(stop: StopEntity?) {
        self.stop = stop
    }
}
