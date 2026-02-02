//
//  ImageCacheService.swift
//  WatchTrans iOS
//
//  Created by Claude on 31/1/26.
//  Persistent image cache for logos - works offline
//

import UIKit

/// Manages persistent image caching for logos
/// Stores downloaded images in the Caches directory for offline use
actor ImageCacheService {
    static let shared = ImageCacheService()

    private let cacheDirectory: URL
    private var memoryCache: [String: UIImage] = [:]

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("logos", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Get image from cache (memory first, then disk)
    func getImage(for key: String) -> UIImage? {
        // Check memory cache first
        if let cached = memoryCache[key] {
            return cached
        }

        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key)
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            // Store in memory for faster access next time
            memoryCache[key] = image
            return image
        }

        return nil
    }

    /// Save image to cache (memory and disk)
    func saveImage(_ image: UIImage, for key: String) {
        memoryCache[key] = image

        let fileURL = cacheDirectory.appendingPathComponent(key)
        if let data = image.pngData() {
            try? data.write(to: fileURL)
        }
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
