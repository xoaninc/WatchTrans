//
//  AppShortcuts.swift
//  WatchTrans iOS
//
//  Created by Claude on 27/1/26.
//  Updated 28/1/26: Added PlanRouteIntent shortcut
//  Defines Siri Shortcuts available to users
//

import AppIntents

// MARK: - App Shortcuts Provider

/// Exposes shortcuts to Siri and Shortcuts app
struct AppShortcuts: AppShortcutsProvider {
    /// The shortcuts that appear in Siri and Shortcuts app
    static var appShortcuts: [AppShortcut] {
        // Next Train shortcut
        AppShortcut(
            intent: NextTrainIntent(),
            phrases: [
                // Spanish phrases
                "Próximo tren en \(\.$stop) con \(.applicationName)",
                "Salidas de \(\.$stop) con \(.applicationName)",
                "Horarios de \(\.$stop) en \(.applicationName)",

                // English phrases
                "Next train at \(\.$stop) with \(.applicationName)",
                "Departures from \(\.$stop) with \(.applicationName)"
            ],
            shortTitle: "Next Train",
            systemImageName: "tram.fill"
        )

        // Plan Route shortcut (uses RAPTOR algorithm via API)
        // Note: Two-parameter phrases not supported, Siri will ask for each stop
        AppShortcut(
            intent: PlanRouteIntent(),
            phrases: [
                // Simple phrases without parameters - Siri will ask for stops
                "Planifica ruta con \(.applicationName)",
                "Plan route with \(.applicationName)"
            ],
            shortTitle: "Plan Route",
            systemImageName: "arrow.triangle.swap"
        )
    }
}

// MARK: - Stop Entity (for Siri parameter)

/// Represents a transit stop that Siri can understand and query
struct StopEntity: AppEntity, Sendable {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Stop",
        numericFormat: "\(placeholder: .int) stops"
    )

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = StopEntityQuery()
}

// MARK: - Stop Entity Query

/// Provides stop suggestions and search for Siri
struct StopEntityQuery: EntityQuery, EntityStringQuery {
    // Base URL for API (local constant to avoid MainActor issues)
    private static let apiBaseURL = "https://redcercanias.com/api/v1/gtfs"

    // MARK: - Required methods

    /// Returns entities for specific IDs (used when Siri knows the stop)
    func entities(for identifiers: [String]) async throws -> [StopEntity] {
        // Fetch stop details for known IDs
        var results: [StopEntity] = []

        for id in identifiers {
            if let stop = try? await fetchStop(id: id) {
                results.append(stop)
            }
        }

        return results
    }

    /// Returns suggested stops (favorites, recent, nearby)
    func suggestedEntities() async throws -> [StopEntity] {
        // Return empty for now - SharedStorage has MainActor issues
        // Users can type/speak the stop name instead
        return []
    }

    /// Search stops by name (when user types or speaks a name)
    func entities(matching string: String) async throws -> [StopEntity] {
        guard string.count >= 2 else { return [] }

        return try await searchStops(query: string)
    }

    // MARK: - API calls

    private func fetchStop(id: String) async throws -> StopEntity? {
        // For now, just return entity with ID - name will come from search
        return StopEntity(id: id, name: id)
    }

    private func fetchNearbyStops(lat: Double, lon: Double, limit: Int) async throws -> [StopEntity] {
        let urlString = "\(Self.apiBaseURL)/stops/by-coordinates?lat=\(lat)&lon=\(lon)&limit=\(limit)"

        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)

        struct APIStop: Codable {
            let id: String
            let name: String
        }

        let stops = try JSONDecoder().decode([APIStop].self, from: data)
        return stops.map { StopEntity(id: $0.id, name: $0.name) }
    }

    private func searchStops(query: String) async throws -> [StopEntity] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(Self.apiBaseURL)/stops?search=\(encoded)&limit=10"

        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)

        struct APIStop: Codable {
            let id: String
            let name: String
        }

        let stops = try JSONDecoder().decode([APIStop].self, from: data)
        return stops.map { StopEntity(id: $0.id, name: $0.name) }
    }
}
