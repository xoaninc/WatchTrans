//
//  KeychainService.swift
//  WatchTrans iOS
//
//  Created by Claude on 28/1/26.
//  Secure storage for sensitive data like admin tokens
//

import Foundation
import Security

/// Service for secure storage using iOS Keychain
enum KeychainService {
    private static let service = "com.xoaninc.WatchTrans"

    // MARK: - Keys

    enum Key: String {
        case adminToken = "admin_token"
    }

    // MARK: - Save

    /// Save a string value to Keychain
    static func save(_ value: String, for key: Key) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete existing item first
        delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Read

    /// Read a string value from Keychain
    static func read(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    // MARK: - Delete

    /// Delete a value from Keychain
    @discardableResult
    static func delete(_ key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Check

    /// Check if a key exists in Keychain
    static func exists(_ key: Key) -> Bool {
        return read(key) != nil
    }
}
