//
//  FavoritesManager.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//

import Foundation
import SwiftData

@Observable
class FavoritesManager {
    private var modelContext: ModelContext

    var favorites: [Favorite] = []
    var maxFavorites: Int { APIConfiguration.maxFavorites }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadFavorites()
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
            print("Failed to load favorites: \(error)")
            favorites = []
        }
    }

    // MARK: - Shared Storage Sync

    /// Sync favorites to SharedStorage for widget access
    private func syncToSharedStorage() {
        let sharedFavorites = favorites.map { favorite in
            SharedStorage.SharedFavorite(stopId: favorite.stopId, stopName: favorite.stopName)
        }
        SharedStorage.shared.saveFavorites(sharedFavorites)
    }

    // Check if a stop is favorited
    func isFavorite(stopId: String) -> Bool {
        return favorites.contains { $0.stopId == stopId }
    }

    // Add a stop to favorites
    func addFavorite(stop: Stop) -> Bool {
        // Check if already favorited
        if isFavorite(stopId: stop.id) {
            return false
        }

        // Check if limit reached
        if favorites.count >= maxFavorites {
            return false
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
            return true
        } catch {
            print("Failed to save favorite: \(error)")
            return false
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
            print("Failed to remove favorite: \(error)")
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
            print("Failed to update usage count: \(error)")
        }
    }

    // Get favorite stops as Stop objects
    func getFavoriteStops(from allStops: [Stop]) -> [Stop] {
        return favorites.compactMap { favorite in
            allStops.first { $0.id == favorite.stopId }
        }
    }
}
