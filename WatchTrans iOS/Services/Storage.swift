//
//  Storage.swift
//  WatchTrans
//
//  Simple disk cache: save/load Codable objects as JSON files.
//  Uses filesystem modificationDate for TTL.
//  Detects model changes using Swift Mirror to list all stored properties.
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
        let wrapper = CacheWrapper(schema: mirrorSchema(for: object), payload: object)
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

        // Compare saved schema against current model's schema
        let currentSchema = mirrorSchema(for: wrapper.payload)
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

    // MARK: - Schema Detection via Mirror

    /// Use Swift Mirror to get all property names and types of the stored object.
    /// This is independent of JSON encoding — it sees ALL properties including nil optionals.
    /// When a field is added/removed/renamed, the schema changes and cache auto-invalidates.
    private func mirrorSchema<T>(for object: T) -> String {
        let target: Any
        // For arrays, mirror the first element's type
        if let array = object as? [Any], let first = array.first {
            target = first
        } else {
            target = object
        }
        let mirror = Mirror(reflecting: target)
        let fields = mirror.children.compactMap { child -> String? in
            guard let label = child.label else { return nil }
            return "\(label):\(type(of: child.value))"
        }
        return fields.sorted().joined(separator: ",")
    }
}
