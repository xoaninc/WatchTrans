//
//  SiriModels.swift
//  WatchTrans iOS
//
//  Created by Claude on 28/1/26.
//  Codable models for Siri intents - separate file to avoid MainActor isolation
//

import Foundation
import AppIntents

// MARK: - API Helper (outside MainActor context)

/// Helper to fetch route data outside of MainActor context
/// This avoids Swift 6 concurrency warnings with Decodable
enum SiriAPIHelper {
    private static let apiBaseURL = "https://redcercanias.com/api/v1/gtfs"

    static func fetchRoute(fromId: String, toId: String) async throws -> SiriJourney {
        let urlString = "\(apiBaseURL)/route-planner?from=\(fromId)&to=\(toId)&compact=true"

        guard let url = URL(string: urlString) else {
            throw PlanRouteError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PlanRouteError.apiError
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(CompactRoutePlanResponse.self, from: data)

        guard apiResponse.success, let journey = apiResponse.journeys?.first else {
            throw PlanRouteError.noRouteFound
        }

        return journey
    }
}

// MARK: - Compact API Response Models

/// Compact response from route-planner?compact=true
/// Optimized for Widget/Siri (<5KB response)
struct CompactRoutePlanResponse: Codable, Sendable {
    let success: Bool
    let message: String?
    let journeys: [SiriJourney]?
}

struct SiriJourney: Codable, Sendable {
    let durationMinutes: Int
    let transfers: Int
    let walkingMinutes: Int
    let segments: [SiriSegment]

    enum CodingKeys: String, CodingKey {
        case durationMinutes = "duration_minutes"
        case transfers
        case walkingMinutes = "walking_minutes"
        case segments
    }
}

struct SiriSegment: Codable, Sendable {
    let type: String  // "transit" or "walk"
    let routeId: String?
    let routeName: String?
    let routeColor: String?
    let fromStopName: String
    let toStopName: String
    let durationMinutes: Int

    enum CodingKeys: String, CodingKey {
        case type
        case routeId = "route_id"
        case routeName = "route_name"
        case routeColor = "route_color"
        case fromStopName = "from_stop_name"
        case toStopName = "to_stop_name"
        case durationMinutes = "duration_minutes"
    }
}

// MARK: - Intent Errors

enum PlanRouteError: Error, CustomLocalizedStringResourceConvertible {
    case invalidURL
    case apiError
    case noRouteFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .apiError: return "Could not connect to service"
        case .noRouteFound: return "No route found"
        }
    }
}
