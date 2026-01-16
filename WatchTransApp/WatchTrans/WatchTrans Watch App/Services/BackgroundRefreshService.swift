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
        // Schedule refresh in 15 minutes (minimum allowed by watchOS)
        let preferredDate = Date().addingTimeInterval(15 * 60)

        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: preferredDate,
            userInfo: nil
        ) { error in
            if let error = error {
                print("⚠️ [BackgroundRefresh] Failed to schedule: \(error)")
            } else {
                print("✅ [BackgroundRefresh] Scheduled for \(preferredDate)")
            }
        }
    }

    // MARK: - Handle Background Task

    /// Handle the background refresh task
    func handleBackgroundRefresh(task: WKApplicationRefreshBackgroundTask) async {
        print("🔄 [BackgroundRefresh] Starting background refresh...")

        defer {
            // Always schedule next refresh and complete the task
            scheduleNextRefresh()
            task.setTaskCompletedWithSnapshot(false)
        }

        // Get the favorite stop ID to fetch departures for
        guard let stopId = getFavoriteStopId() else {
            print("⚠️ [BackgroundRefresh] No favorite stop set")
            return
        }

        do {
            // Fetch departures from API
            let departures = try await gtfsService.fetchDepartures(stopId: stopId, limit: 5)

            // Cache the results
            cacheDepartures(departures, for: stopId)

            // Update last fetch time
            UserDefaults.standard.set(Date(), forKey: lastFetchKey)

            print("✅ [BackgroundRefresh] Fetched \(departures.count) departures for \(stopId)")

            // Reload complications with new data
            reloadComplications()

        } catch {
            print("⚠️ [BackgroundRefresh] Failed to fetch: \(error)")
        }
    }

    // MARK: - Cached Data Management

    /// Get the favorite stop ID for background updates
    func getFavoriteStopId() -> String? {
        return UserDefaults.standard.string(forKey: favoriteStopIdKey)
    }

    /// Set the favorite stop ID for background updates
    func setFavoriteStopId(_ stopId: String) {
        UserDefaults.standard.set(stopId, forKey: favoriteStopIdKey)
        print("✅ [BackgroundRefresh] Set favorite stop: \(stopId)")
    }

    /// Cache departures for later use by complications
    private func cacheDepartures(_ departures: [DepartureResponse], for stopId: String) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(departures) {
            UserDefaults.standard.set(data, forKey: cachedDeparturesKey)
        }
    }

    /// Get cached departures
    func getCachedDepartures() -> [DepartureResponse]? {
        guard let data = UserDefaults.standard.data(forKey: cachedDeparturesKey) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode([DepartureResponse].self, from: data)
    }

    /// Get the last background fetch time
    func getLastFetchTime() -> Date? {
        return UserDefaults.standard.object(forKey: lastFetchKey) as? Date
    }

    // MARK: - Complications

    /// Reload all complications with updated data
    private func reloadComplications() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
