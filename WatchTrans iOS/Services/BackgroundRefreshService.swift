//
//  BackgroundRefreshService.swift
//  WatchTrans iOS
//
//  Created by Claude on 30/1/26.
//  Handles background refresh to keep departure data fresh
//

import BackgroundTasks
import Foundation

/// Service that manages background app refresh for iOS
/// Keeps favorite stops' departures cached for instant display when app opens
@MainActor
class BackgroundRefreshService {
    static let shared = BackgroundRefreshService()

    /// Task identifier - must match Info.plist BGTaskSchedulerPermittedIdentifiers
    static let refreshTaskIdentifier = "juan.WatchTrans.refreshDepartures"

    private init() {}

    // MARK: - Registration

    /// Register background task handler - call this in AppDelegate.didFinishLaunching
    func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await self.handleRefresh(task: task as! BGAppRefreshTask)
            }
        }
        DebugLog.log("📱 [BGRefresh] Registered background task: \(Self.refreshTaskIdentifier)")
    }

    // MARK: - Scheduling

    /// Schedule the next background refresh - call when app goes to background
    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        // Request refresh in 15 minutes (system may delay based on usage patterns)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            DebugLog.log("📱 [BGRefresh] ✅ Scheduled next refresh in ~15 minutes")
        } catch {
            DebugLog.log("📱 [BGRefresh] ❌ Failed to schedule: \(error.localizedDescription)")
        }
    }

    /// Cancel any pending background refresh
    func cancelScheduledRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshTaskIdentifier)
        DebugLog.log("📱 [BGRefresh] Cancelled scheduled refresh")
    }

    // MARK: - Task Handling

    /// Handle background refresh task
    private func handleRefresh(task: BGAppRefreshTask) async {
        DebugLog.log("📱 [BGRefresh] ========== BACKGROUND REFRESH STARTED ==========")

        // Schedule next refresh immediately
        scheduleRefresh()

        // Set expiration handler
        task.expirationHandler = {
            DebugLog.log("📱 [BGRefresh] ⚠️ Task expired before completion")
            task.setTaskCompleted(success: false)
        }

        // Check if we have network
        guard NetworkMonitor.shared.isConnected else {
            DebugLog.log("📱 [BGRefresh] ⚠️ No network - skipping refresh")
            task.setTaskCompleted(success: false)
            return
        }

        // Get favorites from SharedStorage
        let favorites = SharedStorage.shared.getFavorites()
        guard !favorites.isEmpty else {
            DebugLog.log("📱 [BGRefresh] No favorites to refresh")
            task.setTaskCompleted(success: true)
            return
        }

        DebugLog.log("📱 [BGRefresh] Refreshing \(favorites.count) favorites...")

        // Fetch departures for favorites (max 5 to stay within time limit)
        let service = GTFSRealtimeService()
        var successCount = 0

        for favorite in favorites.prefix(5) {
            do {
                let departures = try await service.fetchDepartures(stopId: favorite.stopId, limit: 20)
                if !departures.isEmpty {
                    successCount += 1
                    DebugLog.log("📱 [BGRefresh] ✅ \(favorite.stopName): \(departures.count) departures")
                }
            } catch {
                DebugLog.log("📱 [BGRefresh] ❌ \(favorite.stopId): \(error.localizedDescription)")
            }
        }

        DebugLog.log("📱 [BGRefresh] ========== COMPLETED: \(successCount)/\(min(favorites.count, 5)) ==========")
        task.setTaskCompleted(success: successCount > 0)
    }
}
