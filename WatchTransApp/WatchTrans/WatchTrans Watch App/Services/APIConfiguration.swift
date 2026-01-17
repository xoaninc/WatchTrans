//
//  APIConfiguration.swift
//  WatchTrans Watch App
//
//  Created by Claude on 17/1/26.
//  Centralized API configuration
//

import Foundation

/// Centralized API configuration to avoid hardcoded URLs across the codebase
enum APIConfiguration {
    /// Base URL for RenfeServer API
    static let baseURL = "https://redcercanias.com/api/v1/gtfs"

    /// API version (for future use)
    static let apiVersion = "v1"

    // MARK: - Timeouts

    /// Default request timeout (seconds)
    static let requestTimeout: TimeInterval = 10

    /// Default resource timeout (seconds)
    static let resourceTimeout: TimeInterval = 15

    /// Widget request timeout (shorter for complications)
    static let widgetRequestTimeout: TimeInterval = 5

    // MARK: - Refresh Intervals

    /// Auto-refresh interval for main app (seconds)
    static let autoRefreshInterval: TimeInterval = 50

    /// Widget refresh interval (seconds)
    static let widgetRefreshInterval: TimeInterval = 150  // 2.5 minutes

    // MARK: - Cache

    /// Arrival cache TTL (seconds)
    static let arrivalCacheTTL: TimeInterval = 60

    /// Stale cache grace period (seconds)
    static let staleCacheGracePeriod: TimeInterval = 300  // 5 minutes

    // MARK: - Limits

    /// Maximum favorites
    static let maxFavorites = 5

    /// Default departures limit for API calls
    static let defaultDeparturesLimit = 20

    /// Widget departures limit
    static let widgetDeparturesLimit = 5
}
