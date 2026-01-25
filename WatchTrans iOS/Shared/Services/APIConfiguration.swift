//
//  APIConfiguration.swift
//  WatchTrans Watch App
//
//  Created by Claude on 17/1/26.
//  Centralized API configuration
//

import Foundation

/// Centralized API configuration to avoid hardcoded values across the codebase
enum APIConfiguration {
    /// Base URL for RenfeServer API
    static let baseURL = "https://redcercanias.com/api/v1/gtfs"

    // MARK: - Timeouts

    /// Default request timeout (seconds)
    static let requestTimeout: TimeInterval = 10

    /// Default resource timeout (seconds)
    static let resourceTimeout: TimeInterval = 15

    // MARK: - Refresh Intervals

    /// Auto-refresh interval for main app (seconds)
    static let autoRefreshInterval: TimeInterval = 50

    // MARK: - Cache

    /// Arrival cache TTL (seconds)
    static let arrivalCacheTTL: TimeInterval = 60

    /// Stale cache grace period (seconds)
    static let staleCacheGracePeriod: TimeInterval = 300  // 5 minutes

    // MARK: - Limits

    /// Maximum favorites
    static let maxFavorites = 3

    /// Default departures limit for API calls
    static let defaultDeparturesLimit = 20
}
