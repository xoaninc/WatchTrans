//
//  Storage.swift
//  WatchTrans
//
//  Simple disk cache: save/load Codable objects as JSON files.
//  Uses filesystem modificationDate for TTL — no metadata structs needed.
//

import Foundation

enum StorageError: Error {
    case notFound
    case expired
    case decodeFailed
}

final class Storage {
    private let folderURL: URL
    private let fileManager: FileManager = .default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(folder: String) {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.folderURL = caches.appendingPathComponent(folder, isDirectory: true)
        try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    func save<T: Codable>(object: T, forKey key: String) throws {
        let data = try encoder.encode(object)
        let url = fileURL(forKey: key)
        try data.write(to: url)
    }

    func load<T: Codable>(forKey key: String, as type: T.Type, maxAge: TimeInterval) throws -> T {
        let url = fileURL(forKey: key)

        guard fileManager.fileExists(atPath: url.path) else {
            throw StorageError.notFound
        }

        // Check TTL using file modification date
        if maxAge != .infinity {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard let modified = attributes[.modificationDate] as? Date else {
                throw StorageError.notFound
            }
            if Date().timeIntervalSince(modified) > maxAge {
                throw StorageError.expired
            }
        }

        let data = try Data(contentsOf: url)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // Model changed — cache is stale
            try? fileManager.removeItem(at: url)
            throw StorageError.decodeFailed
        }
    }

    func remove(forKey key: String) throws {
        let url = fileURL(forKey: key)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    func removeAll() throws {
        if fileManager.fileExists(atPath: folderURL.path) {
            try fileManager.removeItem(at: folderURL)
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
    }

    func exists(forKey key: String) -> Bool {
        fileManager.fileExists(atPath: fileURL(forKey: key).path)
    }

    private func fileURL(forKey key: String) -> URL {
        folderURL.appendingPathComponent(key, isDirectory: false)
    }
}
