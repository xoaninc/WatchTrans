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
                "¿Cuándo pasa el tren en \(\.$stop) con \(.applicationName)?",
                "Salidas de \(\.$stop) con \(.applicationName)",
                "Horarios de \(\.$stop) en \(.applicationName)",

                // English phrases
                "Next train at \(\.$stop) with \(.applicationName)",
                "When is the next train at \(\.$stop) with \(.applicationName)?",
                "Departures from \(\.$stop) with \(.applicationName)",
                "\(.applicationName) departures at \(\.$stop)"
            ],
            shortTitle: "Next Train",
            systemImageName: "tram.fill"
        )

        // Plan Route shortcut (uses RAPTOR algorithm via API)
        AppShortcut(
            intent: PlanRouteIntent(),
            phrases: [
                // Spanish phrases
                "¿Cómo llego de \(\.$fromStop) a \(\.$toStop) con \(.applicationName)?",
                "Ruta de \(\.$fromStop) a \(\.$toStop) con \(.applicationName)",
                "Planifica viaje de \(\.$fromStop) a \(\.$toStop) con \(.applicationName)",
                "Ir de \(\.$fromStop) a \(\.$toStop) en \(.applicationName)",
                "¿Cómo voy de \(\.$fromStop) a \(\.$toStop) con \(.applicationName)?",

                // English phrases
                "How do I get from \(\.$fromStop) to \(\.$toStop) with \(.applicationName)?",
                "Route from \(\.$fromStop) to \(\.$toStop) with \(.applicationName)",
                "Plan trip from \(\.$fromStop) to \(\.$toStop) with \(.applicationName)",
                "Directions from \(\.$fromStop) to \(\.$toStop) using \(.applicationName)",
                "\(.applicationName) route \(\.$fromStop) to \(\.$toStop)"
            ],
            shortTitle: "Plan Route",
            systemImageName: "arrow.triangle.swap"
        )
    }
}

// MARK: - Stop Entity (for Siri parameter)

/// Represents a transit stop that Siri can understand and query
struct StopEntity: AppEntity {
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
    private var apiBaseURL: String { APIConfiguration.baseURL }

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
        var suggestions: [StopEntity] = []

        // 1. Add favorites first
        let favorites = SharedStorage.shared.getFavorites()
        suggestions.append(contentsOf: favorites.map {
            StopEntity(id: $0.stopId, name: $0.stopName)
        })

        // 2. Add hub stops (major interchange stations)
        let hubs = SharedStorage.shared.getHubStops()
        for hub in hubs {
            if !suggestions.contains(where: { $0.id == hub.stopId }) {
                suggestions.append(StopEntity(id: hub.stopId, name: hub.stopName))
            }
        }

        // 3. Add nearby stops if we have location
        if let location = SharedStorage.shared.getLocation() {
            let nearby = try? await fetchNearbyStops(lat: location.latitude, lon: location.longitude, limit: 5)
            for stop in nearby ?? [] {
                if !suggestions.contains(where: { $0.id == stop.id }) {
                    suggestions.append(stop)
                }
            }
        }

        return Array(suggestions.prefix(10))
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
        let urlString = "\(apiBaseURL)/stops/by-coordinates?lat=\(lat)&lon=\(lon)&limit=\(limit)"

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
        let urlString = "\(apiBaseURL)/stops?search=\(encoded)&limit=10"

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
