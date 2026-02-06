//
//  BackgroundRefreshService.swift
//  WatchTrans Watch App
//
//  Handles background refresh tasks for keeping departure data updated
//

import Foundation
import WatchKit
import WidgetKit

class BackgroundRefreshService {
    static let shared = BackgroundRefreshService()

    private let networkService = NetworkService()
    private lazy var gtfsService = GTFSRealtimeService(networkService: networkService)

    // UserDefaults keys for shared data
    private let lastFetchKey = "lastBackgroundFetch"
    private let cachedDeparturesKey = "cachedDepartures"
    private let favoriteStopIdKey = "favoriteStopId"

    private init() {}

    // MARK: - Schedule Background Refresh

    /// Schedule the next background refresh (call after each refresh completes)
    func scheduleNextRefresh() {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        
        var interval: TimeInterval = 15 * 60 // Default 15 min
        
        // Intelligent scheduling based on typical Spanish commute hours
        if (7...10).contains(hour) || (17...20).contains(hour) {
            // Commute hours: High frequency (15 min)
            interval = 15 * 60
        } else if (0...5).contains(hour) {
            // Late night: Low frequency (60 min)
            interval = 60 * 60
        } else {
            // Regular day: Medium frequency (30 min)
            interval = 30 * 60
        }

        let preferredDate = now.addingTimeInterval(interval)

        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: preferredDate,
            userInfo: nil
        ) { error in
            if let error = error {
                DebugLog.log("⚠️ [BackgroundRefresh] Failed to schedule: \(error)")
            } else {
                DebugLog.log("✅ [BackgroundRefresh] Scheduled for \(preferredDate) (interval: \(Int(interval/60)) min)")
            }
        }
    }

    // MARK: - Handle Background Task

    /// Handle the background refresh task
    func handleBackgroundRefresh(task: WKApplicationRefreshBackgroundTask) async {
        DebugLog.log("🔄 [BackgroundRefresh] Starting background refresh...")

        defer {
            // Always schedule next refresh and complete the task
            scheduleNextRefresh()
            task.setTaskCompletedWithSnapshot(false)
        }

        // Get the active stop ID to fetch departures for
        guard let stopId = getFavoriteStopId() else {
            DebugLog.log("⚠️ [BackgroundRefresh] No active stop set")
            return
        }

        do {
            // Fetch departures from API
            let departures = try await gtfsService.fetchDepartures(stopId: stopId, limit: 5)

            // Cache the results
            cacheDepartures(departures, for: stopId)

            // Update last fetch time
            SharedStorage.shared.saveLastBackgroundFetch(Date())

            DebugLog.log("✅ [BackgroundRefresh] Fetched \(departures.count) departures for \(stopId)")

            // Reload complications with new data
            reloadComplications()

        } catch {
            DebugLog.log("⚠️ [BackgroundRefresh] Failed to fetch: \(error)")
        }
    }

    // MARK: - Cached Data Management

    /// Get the favorite stop ID for background updates
    func getFavoriteStopId() -> String? {
        return SharedStorage.shared.getActiveStopId()
    }

    /// Set the favorite stop ID for background updates
    func setFavoriteStopId(_ stopId: String) {
        SharedStorage.shared.saveActiveStopId(stopId)
        DebugLog.log("✅ [BackgroundRefresh] Set active stop: \(stopId)")
    }

    /// Cache departures for later use by complications
    private func cacheDepartures(_ departures: [DepartureResponse], for stopId: String) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(departures) {
            SharedStorage.shared.saveCachedDeparturesData(data)
        }
    }

    /// Get cached departures
    func getCachedDepartures() -> [DepartureResponse]? {
        guard let data = SharedStorage.shared.getCachedDeparturesData() else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode([DepartureResponse].self, from: data)
    }

    /// Get the last background fetch time
    func getLastFetchTime() -> Date? {
        return SharedStorage.shared.getLastBackgroundFetch()
    }

    // MARK: - Complications

    /// Reload all complications with updated data
    private func reloadComplications() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
