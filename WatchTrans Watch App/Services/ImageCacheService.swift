//
//  ImageCacheService.swift
//  WatchTrans Watch App
//
//  Created by Claude on 31/1/26.
//  Persistent image cache for logos - works offline on watchOS
//

import SwiftUI

/// Manages persistent image caching for logos on watchOS
/// Stores downloaded images in the Caches directory for offline use
actor ImageCacheService {
    static let shared = ImageCacheService()

    private let cacheDirectory: URL
    private var memoryCache: [String: Data] = [:]

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("logos", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Get image data from cache (memory first, then disk)
    func getImageData(for key: String) -> Data? {
        // Check memory cache first
        if let cached = memoryCache[key] {
            return cached
        }

        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key)
        if let data = try? Data(contentsOf: fileURL) {
            // Store in memory for faster access next time
            memoryCache[key] = data
            return data
        }

        return nil
    }

    /// Save image data to cache (memory and disk)
    func saveImageData(_ data: Data, for key: String) {
        memoryCache[key] = data

        let fileURL = cacheDirectory.appendingPathComponent(key)
        try? data.write(to: fileURL)
    }

    /// Check if image exists in cache
    func hasImage(for key: String) -> Bool {
        if memoryCache[key] != nil {
            return true
        }
        let fileURL = cacheDirectory.appendingPathComponent(key)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
}
