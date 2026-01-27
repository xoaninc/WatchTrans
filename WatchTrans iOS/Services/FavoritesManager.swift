//
//  FavoritesManager.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//

import Foundation
import SwiftData

/// Result of attempting to add a favorite
enum AddFavoriteResult {
    case success
    case alreadyExists
    case limitReached
    case saveFailed(Error)
}

@Observable
class FavoritesManager {
    private var modelContext: ModelContext

    var favorites: [Favorite] = []
    var maxFavorites: Int { APIConfiguration.maxFavorites }

    /// Last error that occurred (observable for UI feedback)
    var lastError: Error?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadFavorites()
    }

    /// Clear the last error (call after showing error to user)
    func clearError() {
        lastError = nil
    }

    // MARK: - Public Methods

    // Load all favorites from SwiftData
    func loadFavorites() {
        let descriptor = FetchDescriptor<Favorite>(
            sortBy: [SortDescriptor(\.addedDate, order: .reverse)]
        )

        do {
            favorites = try modelContext.fetch(descriptor)
            syncToSharedStorage()
        } catch {
            DebugLog.log("⚠️ [FavoritesManager] Failed to load favorites: \(error)")
            lastError = error
            favorites = []
        }
    }

    // MARK: - Shared Storage Sync

    /// Sync favorites to SharedStorage for widget access and iCloud
    private func syncToSharedStorage() {
        let sharedFavorites = favorites.map { favorite in
            SharedStorage.SharedFavorite(stopId: favorite.stopId, stopName: favorite.stopName)
        }
        SharedStorage.shared.saveFavorites(sharedFavorites)

        // Also sync to iCloud for cross-device sync
        iCloudSyncService.shared.pushFavoritesToiCloud()
    }

    // Check if a stop is favorited
    func isFavorite(stopId: String) -> Bool {
        return favorites.contains { $0.stopId == stopId }
    }

    // Add a stop to favorites
    func addFavorite(stop: Stop) -> AddFavoriteResult {
        // Check if already favorited
        if isFavorite(stopId: stop.id) {
            return .alreadyExists
        }

        // Check if limit reached
        if favorites.count >= maxFavorites {
            return .limitReached
        }

        // Create and save favorite
        let favorite = Favorite(
            stopId: stop.id,
            stopName: stop.name,
            addedDate: Date(),
            usageCount: 0
        )

        modelContext.insert(favorite)

        do {
            try modelContext.save()
            loadFavorites()
            return .success
        } catch {
            DebugLog.log("⚠️ [FavoritesManager] Failed to save favorite: \(error)")
            lastError = error
            return .saveFailed(error)
        }
    }

    // Remove a stop from favorites
    func removeFavorite(stopId: String) {
        guard let favorite = favorites.first(where: { $0.stopId == stopId }) else {
            return
        }

        modelContext.delete(favorite)

        do {
            try modelContext.save()
            loadFavorites()
        } catch {
            DebugLog.log("⚠️ [FavoritesManager] Failed to remove favorite: \(error)")
            lastError = error
        }
    }

    // Increment usage count when user views a favorite
    func incrementUsageCount(stopId: String) {
        guard let favorite = favorites.first(where: { $0.stopId == stopId }) else {
            return
        }

        favorite.usageCount += 1

        do {
            try modelContext.save()
        } catch {
            DebugLog.log("⚠️ [FavoritesManager] Failed to update usage count: \(error)")
            lastError = error
        }
    }

    // Get favorite stops as Stop objects
    func getFavoriteStops(from allStops: [Stop]) -> [Stop] {
        return favorites.compactMap { favorite in
            allStops.first { $0.id == favorite.stopId }
        }
    }
}
