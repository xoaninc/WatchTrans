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
    /// API updates every ~30s, so poll at 25s to catch changes quickly
    static let autoRefreshInterval: TimeInterval = 25

    // MARK: - Cache

    /// Arrival cache TTL (seconds)
    /// Must be shorter than autoRefreshInterval to ensure fresh data on each refresh
    static let arrivalCacheTTL: TimeInterval = 20

    /// Stale cache grace period (seconds)
    static let staleCacheGracePeriod: TimeInterval = 300  // 5 minutes

    // MARK: - Limits

    /// Maximum favorites
    static let maxFavorites = 3

    /// Default departures limit for API calls
    static let defaultDeparturesLimit = 20

    // MARK: - GTFS Time Processing

    /// Morning threshold in minutes (04:00 = 240 minutes)
    /// Used to distinguish morning service from late-night service when processing frequencies.
    /// Services starting before this time (e.g., 00:00-01:30) are considered late-night extensions,
    /// not the start of the day's service.
    static let morningThresholdMinutes = 4 * 60  // 04:00
}
