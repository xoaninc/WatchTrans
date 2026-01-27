//
//  iCloudSyncService.swift
//  WatchTrans iOS
//
//  Created by Claude on 28/1/26.
//  Syncs favorites across devices using iCloud Key-Value Store
//

import Foundation

/// Service to sync favorites and hub stops across user's devices via iCloud
///
/// Architecture:
/// ```
/// iCloud (NSUbiquitousKeyValueStore) ←→ SharedStorage ←→ Widget/Siri
/// ```
///
/// Limits: 1MB total, 1KB per key
///
/// SETUP REQUIRED IN XCODE:
/// 1. Select WatchTrans iOS target → Signing & Capabilities → + Capability → iCloud
/// 2. Check "Key-value storage"
///
class iCloudSyncService {
    static let shared = iCloudSyncService()

    private let iCloudStore = NSUbiquitousKeyValueStore.default

    // Keys for iCloud storage (keep in sync with SharedStorage)
    private enum Keys {
        static let favorites = "favorites"
        static let hubStops = "hubStops"
        static let lastSyncTimestamp = "lastSyncTimestamp"
    }

    private init() {
        setupNotifications()
    }

    // MARK: - Setup

    /// Start listening for iCloud changes from other devices
    func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleiCloudChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )

        // Sync on launch to get any pending changes
        iCloudStore.synchronize()
        DebugLog.log("☁️ [iCloudSync] Service initialized, listening for changes")
    }

    /// Force a sync with iCloud (call on app launch)
    func syncOnLaunch() {
        // Pull from iCloud first
        if iCloudStore.synchronize() {
            DebugLog.log("☁️ [iCloudSync] Initial sync triggered")
            pullFromiCloud()
        }
    }

    // MARK: - Handle External Changes

    @objc private func handleiCloudChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        let reasonString: String
        switch changeReason {
        case NSUbiquitousKeyValueStoreServerChange:
            reasonString = "server change"
        case NSUbiquitousKeyValueStoreInitialSyncChange:
            reasonString = "initial sync"
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            reasonString = "quota violation"
            DebugLog.log("⚠️ [iCloudSync] Quota exceeded!")
            return
        case NSUbiquitousKeyValueStoreAccountChange:
            reasonString = "account change"
        default:
            reasonString = "unknown (\(changeReason))"
        }

        DebugLog.log("☁️ [iCloudSync] Received external change: \(reasonString)")

        // Get changed keys
        if let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            DebugLog.log("☁️ [iCloudSync] Changed keys: \(changedKeys)")

            for key in changedKeys {
                switch key {
                case Keys.favorites:
                    pullFavoritesFromiCloud()
                case Keys.hubStops:
                    pullHubStopsFromiCloud()
                default:
                    break
                }
            }
        }
    }

    // MARK: - Pull from iCloud (iCloud → SharedStorage)

    private func pullFromiCloud() {
        pullFavoritesFromiCloud()
        pullHubStopsFromiCloud()
    }

    private func pullFavoritesFromiCloud() {
        guard let data = iCloudStore.data(forKey: Keys.favorites) else {
            DebugLog.log("☁️ [iCloudSync] No favorites in iCloud")
            return
        }

        do {
            let favorites = try JSONDecoder().decode([SharedStorage.SharedFavorite].self, from: data)

            // Merge with local: iCloud wins if more recent, or merge unique items
            let localFavorites = SharedStorage.shared.getFavorites()
            let mergedFavorites = mergeFavorites(local: localFavorites, remote: favorites)

            SharedStorage.shared.saveFavorites(mergedFavorites)
            DebugLog.log("☁️ [iCloudSync] Pulled \(favorites.count) favorites from iCloud, merged to \(mergedFavorites.count)")
        } catch {
            DebugLog.log("⚠️ [iCloudSync] Failed to decode favorites from iCloud: \(error)")
        }
    }

    private func pullHubStopsFromiCloud() {
        guard let data = iCloudStore.data(forKey: Keys.hubStops) else {
            DebugLog.log("☁️ [iCloudSync] No hub stops in iCloud")
            return
        }

        do {
            let hubStops = try JSONDecoder().decode([SharedStorage.SharedHubStop].self, from: data)
            SharedStorage.shared.saveHubStops(hubStops)
            DebugLog.log("☁️ [iCloudSync] Pulled \(hubStops.count) hub stops from iCloud")
        } catch {
            DebugLog.log("⚠️ [iCloudSync] Failed to decode hub stops from iCloud: \(error)")
        }
    }

    // MARK: - Push to iCloud (SharedStorage → iCloud)

    /// Push current favorites to iCloud (call after user adds/removes favorite)
    func pushFavoritesToiCloud() {
        let favorites = SharedStorage.shared.getFavorites()

        do {
            let data = try JSONEncoder().encode(favorites)

            // Check size limit (1KB per key recommended, 64KB max)
            if data.count > 64000 {
                DebugLog.log("⚠️ [iCloudSync] Favorites data too large: \(data.count) bytes")
                return
            }

            iCloudStore.set(data, forKey: Keys.favorites)
            iCloudStore.set(Date().timeIntervalSince1970, forKey: Keys.lastSyncTimestamp)
            iCloudStore.synchronize()

            DebugLog.log("☁️ [iCloudSync] Pushed \(favorites.count) favorites to iCloud (\(data.count) bytes)")
        } catch {
            DebugLog.log("⚠️ [iCloudSync] Failed to encode favorites for iCloud: \(error)")
        }
    }

    /// Push hub stops to iCloud (call when hub stops are detected)
    func pushHubStopsToiCloud() {
        let hubStops = SharedStorage.shared.getHubStops()

        do {
            let data = try JSONEncoder().encode(hubStops)

            if data.count > 64000 {
                DebugLog.log("⚠️ [iCloudSync] Hub stops data too large: \(data.count) bytes")
                return
            }

            iCloudStore.set(data, forKey: Keys.hubStops)
            iCloudStore.synchronize()

            DebugLog.log("☁️ [iCloudSync] Pushed \(hubStops.count) hub stops to iCloud (\(data.count) bytes)")
        } catch {
            DebugLog.log("⚠️ [iCloudSync] Failed to encode hub stops for iCloud: \(error)")
        }
    }

    // MARK: - Merge Logic

    /// Merge local and remote favorites, keeping unique items
    /// Strategy: Union of both sets, deduplicated by stopId
    private func mergeFavorites(local: [SharedStorage.SharedFavorite], remote: [SharedStorage.SharedFavorite]) -> [SharedStorage.SharedFavorite] {
        var seen = Set<String>()
        var merged: [SharedStorage.SharedFavorite] = []

        // Add all local first (preserves user's order)
        for fav in local {
            if !seen.contains(fav.stopId) {
                seen.insert(fav.stopId)
                merged.append(fav)
            }
        }

        // Add remote items not in local
        for fav in remote {
            if !seen.contains(fav.stopId) {
                seen.insert(fav.stopId)
                merged.append(fav)
            }
        }

        return merged
    }

    // MARK: - Status

    /// Check if iCloud is available
    var isAvailable: Bool {
        // NSUbiquitousKeyValueStore is always "available" but may not sync
        // if user is not logged into iCloud
        return FileManager.default.ubiquityIdentityToken != nil
    }

    /// Get last sync timestamp
    var lastSyncDate: Date? {
        let timestamp = iCloudStore.double(forKey: Keys.lastSyncTimestamp)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }
}
