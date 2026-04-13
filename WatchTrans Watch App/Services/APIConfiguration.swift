//
//  APIConfiguration.swift
//  WatchTrans iOS
//
//  Centralized API configuration
//

import Foundation

struct APIConfiguration {
    // MARK: - Production URLs

    /// Base URL for API host
    static let apiBaseURL = "https://api.watch-trans.app"

    /// Base URL for GTFS Static API (routes, stops, trips)
    static let baseURL = "\(apiBaseURL)/api/gtfs"

    /// Base URL for GTFS Real-time API (vehicles, alerts, trip updates)
    static let gtfsRTBaseURL = "\(apiBaseURL)/api/gtfs-rt"

    /// Base URL for static assets (logos)
    static let logosBaseURL = "\(apiBaseURL)/static/logos/"
    
    // MARK: - Development URLs (uncomment for local testing)
    // static let baseURL = "http://localhost:8000/api/gtfs"
    // static let gtfsRTBaseURL = "http://localhost:8000/api/gtfs-rt"

    // MARK: - Timeouts

    /// Default request timeout (seconds)
    static let requestTimeout: TimeInterval = 15

    /// Default resource timeout (seconds)
    static let resourceTimeout: TimeInterval = 20

    // MARK: - Authentication
    static let authHeader = "Bearer \(APISecrets.apiKey)"

    // MARK: - Limits
    /// Maximum favorites
    static let maxFavorites = 3

    /// Default departures limit for API calls
    static let defaultDeparturesLimit = 20

    // MARK: - Refresh Intervals

    /// Auto-refresh interval for main app (seconds)
    static let autoRefreshInterval: TimeInterval = 45

    // MARK: - Cache

    /// Arrival cache TTL (seconds)
    /// Must be shorter than autoRefreshInterval to ensure fresh data on each refresh
    static let arrivalCacheTTL: TimeInterval = 20

    /// Stale cache grace period (seconds)
    static let staleCacheGracePeriod: TimeInterval = 300  // 5 minutes

    // MARK: - GTFS Time Processing

    /// Morning threshold in minutes (04:00 = 240 minutes)
    /// Used to distinguish morning service from late-night service when processing frequencies.
    static let morningThresholdMinutes = 4 * 60  // 04:00
}
