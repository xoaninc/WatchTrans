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
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.folderURL = caches.appendingPathComponent(folder, isDirectory: true)
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
            if Date().timeIntervalSince(modified) > maxAge {
                throw StorageError.expired
            }
        }

        let data = try Data(contentsOf: url)

        guard let wrapper = try? decoder.decode(CacheWrapper<T>.self, from: data) else {
            try? fileManager.removeItem(at: url)
            throw StorageError.decodeFailed
        }

        let currentSchema = schemaKey(for: wrapper.payload)
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
        folderURL.appendingPathComponent(key, isDirectory: false)
    }

    /// Build a string of all JSON keys in the object. If a field is added/removed, this changes.
    private func schemaKey<T: Codable>(for object: T) -> String {
        guard let data = try? encoder.encode(object),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return ""
        }
        return extractKeys(from: json).sorted().joined(separator: ",")
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
