//
//  OfflineScheduleService.swift
//  WatchTrans iOS
//
//  Created by Claude on 28/1/26.
//  Manages offline caching of GTFS schedules for when there's no network
//

import Foundation

/// Service for caching and retrieving offline schedule data
/// When online: downloads and caches schedules for favorite stops
/// When offline: provides cached schedules as fallback
actor OfflineScheduleService {
    static let shared = OfflineScheduleService()

    // MARK: - Constants

    private let cacheDirectory: URL
    private let schedulesTTL: TimeInterval = 7 * 24 * 60 * 60  // 1 week
    private let maxCacheSize: Int = 50 * 1024 * 1024  // 50MB max

    // MARK: - Cache State

    private var cachedSchedules: [String: CachedStopSchedule] = [:]
    private var lastCacheUpdate: Date?
    private var cacheLoaded = false

    // MARK: - Models

    struct CachedStopSchedule: Codable {
        let stopId: String
        let stopName: String
        let departures: [CachedDeparture]
        let cachedAt: Date
        let validForDate: String  // "2026-01-28" - schedules are date-specific

        var isExpired: Bool {
            let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
            return String(today) != validForDate
        }
    }

    struct CachedDeparture: Codable {
        let routeId: String
        let routeShortName: String
        let routeColor: String?
        let headsign: String
        let scheduledTime: String  // "HH:mm:ss"
        let departureSeconds: Int  // Seconds since midnight

        /// Calculate minutes until departure from current time
        func minutesUntil(from currentTime: Date) -> Int {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute, .second], from: currentTime)
            let currentSeconds = (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0)

            var diff = departureSeconds - currentSeconds
            if diff < 0 {
                // Departure was earlier today, might be tomorrow
                diff += 24 * 3600
            }
            return max(0, diff / 60)
        }
    }

    // MARK: - Initialization

    private init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("OfflineSchedules", isDirectory: true)

        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Load cached schedules from disk (fire-and-forget task)
        _ = Task {
            await loadCacheFromDisk()
        }
    }

    // MARK: - Public API

    /// Cache schedules for a stop (call this when online)
    /// Skips caching if existing cache is less than 30 minutes old
    func cacheSchedules(for stopId: String, stopName: String, departures: [DepartureResponse]) async {
        // Skip if cache is still fresh (< 30 min old)
        if let existing = cachedSchedules[stopId],
           Date().timeIntervalSince(existing.cachedAt) < 30 * 60 {
            return
        }

        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))

        let cachedDepartures = departures.map { dep in
            CachedDeparture(
                routeId: dep.routeId,
                routeShortName: dep.routeShortName,
                routeColor: dep.routeColor,
                headsign: dep.headsign ?? "Sin destino",
                scheduledTime: dep.departureTime,
                departureSeconds: dep.departureSeconds
            )
        }

        let schedule = CachedStopSchedule(
            stopId: stopId,
            stopName: stopName,
            departures: cachedDepartures,
            cachedAt: Date(),
            validForDate: today
        )

        cachedSchedules[stopId] = schedule
        await saveCacheToDisk(for: stopId, schedule: schedule)

        DebugLog.log("📦 [Offline] Cached \(departures.count) departures for \(stopName)")
    }

    /// Get cached departures for a stop (use when offline)
    func getCachedDepartures(for stopId: String) async -> [OfflineDeparture]? {
        // Ensure cache is loaded from disk before querying
        if !cacheLoaded {
            await loadCacheFromDisk()
        }

        guard let schedule = cachedSchedules[stopId] else {
            DebugLog.log("📦 [Offline] No cache for stop \(stopId)")
            return nil
        }

        // Check if cache is still valid (same day)
        if schedule.isExpired {
            DebugLog.log("📦 [Offline] Cache expired for \(schedule.stopName) (was for \(schedule.validForDate))")
            return nil
        }

        let now = Date()
        let departures = schedule.departures
            .map { cached in
                OfflineDeparture(
                    routeId: cached.routeId,
                    routeShortName: cached.routeShortName,
                    routeColor: cached.routeColor,
                    headsign: cached.headsign,
                    scheduledTime: cached.scheduledTime,
                    minutesUntil: cached.minutesUntil(from: now),
                    isOfflineData: true
                )
            }
            .filter { $0.minutesUntil >= 0 && $0.minutesUntil < 120 }  // Next 2 hours
            .sorted { $0.minutesUntil < $1.minutesUntil }

        DebugLog.log("📦 [Offline] Returning \(departures.count) cached departures for \(schedule.stopName)")
        return departures
    }

    /// Check if we have cached data for a stop
    func hasCachedData(for stopId: String) async -> Bool {
        guard let schedule = cachedSchedules[stopId] else { return false }
        return !schedule.isExpired
    }

    /// Cache schedules for all favorite stops
    func cacheSchedulesForFavorites(using dataService: DataService) async {
        let favorites = await MainActor.run {
            SharedStorage.shared.getFavorites().map { $0.stopId }
        }
        DebugLog.log("📦 [Offline] Caching schedules for \(favorites.count) favorite stops")

        for stopId in favorites {
            do {
                // Fetch from API
                let departures = try await dataService.gtfsRealtimeService.fetchDepartures(
                    stopId: stopId,
                    routeId: nil,
                    limit: 50  // Get more for offline use
                )

                // Get stop name from dataService (MainActor isolated)
                let stopName = await MainActor.run {
                    dataService.getStop(by: stopId)?.name ?? stopId
                }

                await cacheSchedules(for: stopId, stopName: stopName, departures: departures)
            } catch {
                DebugLog.log("📦 [Offline] Failed to cache \(stopId): \(error.localizedDescription)")
            }
        }

        lastCacheUpdate = Date()
        DebugLog.log("📦 [Offline] ✅ Cache update complete")
    }

    /// Clear all cached data
    func clearCache() async {
        cachedSchedules.removeAll()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        DebugLog.log("📦 [Offline] Cache cleared")
    }

    /// Get cache statistics
    func getCacheStats() async -> CacheStats {
        let stopCount = cachedSchedules.count
        let totalDepartures = cachedSchedules.values.reduce(0) { $0 + $1.departures.count }
        let oldestCache = cachedSchedules.values.map { $0.cachedAt }.min()
        let newestCache = cachedSchedules.values.map { $0.cachedAt }.max()

        return CacheStats(
            stopsCount: stopCount,
            departuresCount: totalDepartures,
            oldestCacheDate: oldestCache,
            newestCacheDate: newestCache,
            lastUpdateDate: lastCacheUpdate
        )
    }

    struct CacheStats {
        let stopsCount: Int
        let departuresCount: Int
        let oldestCacheDate: Date?
        let newestCacheDate: Date?
        let lastUpdateDate: Date?
    }

    // MARK: - Disk Persistence

    private func loadCacheFromDisk() async {
        guard !cacheLoaded else { return }  // Already loaded

        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            cacheLoaded = true
            return
        }

        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let schedule = try? JSONDecoder().decode(CachedStopSchedule.self, from: data) {
                cachedSchedules[schedule.stopId] = schedule
            }
        }

        cacheLoaded = true
        DebugLog.log("📦 [Offline] Loaded \(cachedSchedules.count) cached schedules from disk")
    }

    private func saveCacheToDisk(for stopId: String, schedule: CachedStopSchedule) async {
        let fileURL = cacheDirectory.appendingPathComponent("\(stopId).json")

        do {
            let data = try JSONEncoder().encode(schedule)
            try data.write(to: fileURL)
        } catch {
            DebugLog.log("📦 [Offline] Failed to save cache for \(stopId): \(error)")
        }
    }
}

// MARK: - Offline Departure Model

/// Departure data from offline cache
struct OfflineDeparture {
    let routeId: String
    let routeShortName: String
    let routeColor: String?
    let headsign: String
    let scheduledTime: String  // "HH:mm:ss"
    let minutesUntil: Int
    let isOfflineData: Bool
}

// MARK: - Offline Line Itinerary Cache

/// Separate actor for caching line itineraries (stops per route) by province
actor OfflineLineService {
    static let shared = OfflineLineService()

    private let cacheDirectory: URL
    private var cachedItineraries: [String: CachedLineItinerary] = [:]  // routeId -> itinerary
    private var cachedProvince: String?
    private var cacheLoaded = false

    struct CachedLineItinerary: Codable {
        let routeId: String
        let lineName: String
        let stops: [CachedStop]
        let cachedAt: Date

        var isExpired: Bool {
            // Line itineraries valid for 1 week
            Date().timeIntervalSince(cachedAt) > 7 * 24 * 60 * 60
        }
    }

    struct CachedStop: Codable {
        let id: String
        let name: String
        let latitude: Double
        let longitude: Double
        let province: String?
        let corMetro: String?
        let corMl: String?
        let corCercanias: String?
        let corTranvia: String?
    }

    private init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("OfflineLines", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Cache all line itineraries for current province
    func cacheItinerariesForProvince(province: String, lines: [Line], dataService: DataService) async {
        DebugLog.log("📦 [OfflineLines] Caching itineraries for province: \(province)")

        // Clear old cache if province changed
        if cachedProvince != province.lowercased() {
            cachedItineraries.removeAll()
            cachedProvince = province.lowercased()
        }

        // Filter lines for this province
        let provinceLower = province.lowercased()
        let provinceLines = lines.filter { $0.nucleo.lowercased() == provinceLower }

        DebugLog.log("📦 [OfflineLines] Found \(provinceLines.count) lines for \(province)")

        for line in provinceLines {
            guard let routeId = line.routeIds.first else { continue }

            // Skip if already cached and not expired
            if let existing = cachedItineraries[routeId], !existing.isExpired {
                continue
            }

            let stops = await dataService.fetchStopsForRoute(routeId: routeId)
            guard !stops.isEmpty else { continue }

            let cachedStops = stops.map { stop in
                CachedStop(
                    id: stop.id,
                    name: stop.name,
                    latitude: stop.latitude,
                    longitude: stop.longitude,
                    province: stop.province,
                    corMetro: stop.corMetro,
                    corMl: stop.corMl,
                    corCercanias: stop.corCercanias,
                    corTranvia: stop.corTranvia
                )
            }

            let itinerary = CachedLineItinerary(
                routeId: routeId,
                lineName: line.name,
                stops: cachedStops,
                cachedAt: Date()
            )

            cachedItineraries[routeId] = itinerary
            await saveToDisk(routeId: routeId, itinerary: itinerary)
        }

        DebugLog.log("📦 [OfflineLines] ✅ Cached \(cachedItineraries.count) line itineraries")
    }

    /// Get cached stops for a route (use when offline)
    func getCachedStops(for routeId: String) async -> [Stop]? {
        if !cacheLoaded {
            await loadFromDisk()
        }

        guard let itinerary = cachedItineraries[routeId], !itinerary.isExpired else {
            return nil
        }

        // Create Stop objects on MainActor since Stop init is MainActor-isolated
        let cachedStops = itinerary.stops
        return await MainActor.run {
            cachedStops.map { cached in
                Stop(
                    id: cached.id,
                    name: cached.name,
                    latitude: cached.latitude,
                    longitude: cached.longitude,
                    connectionLineIds: [],
                    province: cached.province,
                    accesibilidad: nil,
                    hasParking: false,
                    hasBusConnection: false,
                    hasMetroConnection: cached.corMetro != nil,
                    isHub: false,
                    corMetro: cached.corMetro,
                    corMl: cached.corMl,
                    corCercanias: cached.corCercanias,
                    corTranvia: cached.corTranvia
                )
            }
        }
    }

    /// Check if we have cached itinerary for a route
    func hasCachedItinerary(for routeId: String) async -> Bool {
        if !cacheLoaded {
            await loadFromDisk()
        }
        guard let itinerary = cachedItineraries[routeId] else { return false }
        return !itinerary.isExpired
    }

    // MARK: - Disk Persistence

    private func loadFromDisk() async {
        guard !cacheLoaded else { return }

        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            cacheLoaded = true
            return
        }

        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let itinerary = try? JSONDecoder().decode(CachedLineItinerary.self, from: data) {
                cachedItineraries[itinerary.routeId] = itinerary
            }
        }

        cacheLoaded = true
        DebugLog.log("📦 [OfflineLines] Loaded \(cachedItineraries.count) cached itineraries from disk")
    }

    private func saveToDisk(routeId: String, itinerary: CachedLineItinerary) async {
        let safeRouteId = routeId.replacingOccurrences(of: "/", with: "_")
        let fileURL = cacheDirectory.appendingPathComponent("\(safeRouteId).json")

        do {
            let data = try JSONEncoder().encode(itinerary)
            try data.write(to: fileURL)
        } catch {
            DebugLog.log("📦 [OfflineLines] Failed to save \(routeId): \(error)")
        }
    }

    /// Clear all cached line itineraries
    func clearAllCache() async {
        cachedItineraries.removeAll()
        cachedProvince = nil
        cacheLoaded = false
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        DebugLog.log("📦 [OfflineLines] Cache cleared")
    }
}
