//
//  Storage.swift
//  WatchTrans
//
//  Simple disk cache: save/load Codable objects as JSON files.
//  Uses filesystem modificationDate for TTL.
//  Detects model changes by comparing JSON key structure.
//

import Foundation

enum StorageError: Error {
    case notFound
    case expired
    case decodeFailed
    case schemaChanged
}

private struct CacheWrapper<T: Codable>: Codable {
    let schema: String
    let payload: T
}

final class Storage {
    private let folderURL: URL
    private let fileManager: FileManager = .default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(folder: String) {
        self.folderURL = URL.cachesDirectory.appending(path: folder, directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    func save<T: Codable>(object: T, forKey key: String) throws {
        let wrapper = CacheWrapper(schema: schemaKey(for: object), payload: object)
        let data = try encoder.encode(wrapper)
        try data.write(to: fileURL(forKey: key))
    }

    func load<T: Codable>(forKey key: String, as type: T.Type, maxAge: TimeInterval) throws -> T {
        let url = fileURL(forKey: key)

        guard fileManager.fileExists(atPath: url.path) else {
            throw StorageError.notFound
        }

        if maxAge != .infinity {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard let modified = attributes[.modificationDate] as? Date else {
                throw StorageError.notFound
            }
            if Date.now.timeIntervalSince(modified) > maxAge {
                throw StorageError.expired
            }
        }

        let data = try Data(contentsOf: url)

        guard let wrapper = try? decoder.decode(CacheWrapper<T>.self, from: data) else {
            try? fileManager.removeItem(at: url)
            throw StorageError.decodeFailed
        }

        // Verify schema: extract keys from raw JSON payload to avoid re-encoding
        let currentSchema = schemaKeyFromRawJSON(data)
        guard wrapper.schema == currentSchema else {
            try? fileManager.removeItem(at: url)
            throw StorageError.schemaChanged
        }

        return wrapper.payload
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
        folderURL.appending(path: key, directoryHint: .notDirectory)
    }

    // MARK: - Schema Detection

    /// Build schema key from an object by encoding it to JSON and extracting keys.
    private func schemaKey<T: Codable>(for object: T) -> String {
        guard let data = try? encoder.encode(object),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return ""
        }
        return extractKeys(from: json).sorted().joined(separator: ",")
    }

    /// Extract schema key from raw cached JSON data (avoids re-encoding the decoded payload).
    private func schemaKeyFromRawJSON(_ data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = json["payload"] else {
            return ""
        }
        return extractKeys(from: payload).sorted().joined(separator: ",")
    }

    private func extractKeys(from json: Any, prefix: String = "") -> [String] {
        var keys: [String] = []
        if let dict = json as? [String: Any] {
            for (key, _) in dict {
                keys.append(prefix.isEmpty ? key : "\(prefix).\(key)")
            }
        } else if let array = json as? [Any], let first = array.first {
            keys.append(contentsOf: extractKeys(from: first, prefix: prefix))
        }
        return keys
    }
}
