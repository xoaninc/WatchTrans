//
//  SharedStorage.swift
//  WatchTrans iOS
//
//  Created by Claude on 17/1/26.
//  Shared storage for App Group - allows widget to access app data
//

import Foundation

/// Shared storage using App Group for communication between iOS app and widget
///
/// SETUP REQUIRED IN XCODE:
/// 1. Select WatchTrans iOS target -> Signing & Capabilities -> + Capability -> App Groups
/// 2. Add group: "group.juan.WatchTrans.iOS"
/// 3. Select iOS Widget Extension target -> Signing & Capabilities -> + Capability -> App Groups
/// 4. Add same group: "group.juan.WatchTrans.iOS"
///
class SharedStorage {
    static let shared = SharedStorage()

    // App Group identifier - must match in Xcode capabilities
    private let appGroupId = "group.juan.WatchTrans.iOS"

    // Keys for stored values
    private enum Keys {
        static let lastLatitude = "lastLatitude"
        static let lastLongitude = "lastLongitude"
        static let lastLocationTimestamp = "lastLocationTimestamp"
        static let lastNucleoName = "lastNucleoName"
        static let lastNucleoId = "lastNucleoId"
        static let favorites = "favorites"
        static let hubStops = "hubStops"
    }

    /// Simple favorite structure for sharing via UserDefaults
    struct SharedFavorite: Codable {
        let stopId: String
        let stopName: String
    }

    /// Hub stop structure for sharing via UserDefaults
    struct SharedHubStop: Codable {
        let stopId: String
        let stopName: String
    }

    // Shared UserDefaults suite
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    // Fallback to standard if App Group not configured
    private var defaults: UserDefaults {
        sharedDefaults ?? UserDefaults.standard
    }

    private init() {}

    // MARK: - Location Storage

    /// Save user's last known location
    func saveLocation(latitude: Double, longitude: Double) {
        defaults.set(latitude, forKey: Keys.lastLatitude)
        defaults.set(longitude, forKey: Keys.lastLongitude)
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastLocationTimestamp)

        // Also save to standard defaults for backward compatibility
        UserDefaults.standard.set(latitude, forKey: Keys.lastLatitude)
        UserDefaults.standard.set(longitude, forKey: Keys.lastLongitude)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.lastLocationTimestamp)

        print("📍 [SharedStorage] Saved location: (\(latitude), \(longitude))")
    }

    /// Get user's last known location
    /// Returns nil if no location has been saved (uses timestamp to validate)
    func getLocation() -> (latitude: Double, longitude: Double)? {
        // Use timestamp to check if location was ever saved (not coordinate values)
        // This avoids the bug where (0, 0) coordinates (valid in Ghana) would be rejected
        guard defaults.object(forKey: Keys.lastLocationTimestamp) != nil else {
            // Try standard defaults as fallback
            guard UserDefaults.standard.object(forKey: Keys.lastLocationTimestamp) != nil else {
                return nil
            }
            let stdLat = UserDefaults.standard.double(forKey: Keys.lastLatitude)
            let stdLon = UserDefaults.standard.double(forKey: Keys.lastLongitude)
            return (stdLat, stdLon)
        }

        let lat = defaults.double(forKey: Keys.lastLatitude)
        let lon = defaults.double(forKey: Keys.lastLongitude)

        // Log if location is stale (but still return it - stale is better than none)
        if let timestamp = defaults.object(forKey: Keys.lastLocationTimestamp) as? TimeInterval {
            let age = Date().timeIntervalSince1970 - timestamp
            let maxAge: TimeInterval = 3600 // 1 hour
            if age > maxAge {
                print("⚠️ [SharedStorage] Location is stale (\(Int(age/60)) min old)")
            }
        }

        return (lat, lon)
    }

    // MARK: - Nucleo Storage

    /// Save detected nucleo info
    func saveNucleo(name: String, id: Int) {
        defaults.set(name, forKey: Keys.lastNucleoName)
        defaults.set(id, forKey: Keys.lastNucleoId)
        print("📍 [SharedStorage] Saved nucleo: \(name) (id: \(id))")
    }

    /// Get last detected nucleo
    func getNucleo() -> (name: String, id: Int)? {
        guard let name = defaults.string(forKey: Keys.lastNucleoName),
              !name.isEmpty else { return nil }
        let id = defaults.integer(forKey: Keys.lastNucleoId)
        return (name, id)
    }

    // MARK: - Utility

    /// Check if App Group is properly configured
    var isAppGroupConfigured: Bool {
        return sharedDefaults != nil
    }

    /// Clear all shared data
    func clearAll() {
        defaults.removeObject(forKey: Keys.lastLatitude)
        defaults.removeObject(forKey: Keys.lastLongitude)
        defaults.removeObject(forKey: Keys.lastLocationTimestamp)
        defaults.removeObject(forKey: Keys.lastNucleoName)
        defaults.removeObject(forKey: Keys.lastNucleoId)
        defaults.removeObject(forKey: Keys.favorites)
    }

    // MARK: - Favorites Storage

    /// Save favorites to shared storage (call when favorites change)
    func saveFavorites(_ favorites: [SharedFavorite]) {
        do {
            let data = try JSONEncoder().encode(favorites)
            defaults.set(data, forKey: Keys.favorites)
            print("📍 [SharedStorage] Saved \(favorites.count) favorites")
        } catch {
            print("⚠️ [SharedStorage] Failed to encode favorites: \(error)")
        }
    }

    /// Get favorites from shared storage
    func getFavorites() -> [SharedFavorite] {
        guard let data = defaults.data(forKey: Keys.favorites) else {
            return []
        }

        do {
            return try JSONDecoder().decode([SharedFavorite].self, from: data)
        } catch {
            print("⚠️ [SharedStorage] Failed to decode favorites: \(error)")
            return []
        }
    }

    /// Get last known nucleo name (convenience for widget)
    func getNucleoName() -> String? {
        defaults.string(forKey: Keys.lastNucleoName)
    }

    // MARK: - Hub Stops Storage

    /// Save hub stops to shared storage (stations with 2+ transport types)
    func saveHubStops(_ stops: [SharedHubStop]) {
        do {
            let data = try JSONEncoder().encode(stops)
            defaults.set(data, forKey: Keys.hubStops)
            print("📍 [SharedStorage] Saved \(stops.count) hub stops")
        } catch {
            print("⚠️ [SharedStorage] Failed to encode hub stops: \(error)")
        }
    }

    /// Get hub stops from shared storage
    func getHubStops() -> [SharedHubStop] {
        guard let data = defaults.data(forKey: Keys.hubStops) else {
            return []
        }

        do {
            return try JSONDecoder().decode([SharedHubStop].self, from: data)
        } catch {
            print("⚠️ [SharedStorage] Failed to decode hub stops: \(error)")
            return []
        }
    }
}
