//
//  AdminService.swift
//  WatchTrans iOS
//
//  Created by Claude on 28/1/26.
//  Admin functions for developer use only
//

import Foundation

/// Admin service for developer-only functions
/// Token is stored securely in Keychain
enum AdminService {
    // Admin endpoint (different from public API)
    private static let adminURL = "https://juanmacias.com/admin/reload-gtfs"

    // MARK: - Reload GTFS

    enum ReloadResult {
        case success(String)
        case unauthorized
        case error(String)
        case noToken
    }

    /// Reload GTFS data on the server
    /// Requires admin token to be stored in Keychain
    static func reloadGTFS() async -> ReloadResult {
        guard let token = KeychainService.read(.adminToken) else {
            return .noToken
        }

        guard let url = URL(string: adminURL) else {
            return .error("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "X-Admin-Token")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .error("Invalid response")
            }

            switch httpResponse.statusCode {
            case 200:
                // Try to parse response message
                if let json = try? JSONDecoder().decode(ReloadResponse.self, from: data) {
                    return .success(json.message ?? "GTFS reload iniciado")
                }
                return .success("GTFS reload iniciado")

            case 401:
                return .unauthorized

            default:
                return .error("Error \(httpResponse.statusCode)")
            }
        } catch {
            return .error(error.localizedDescription)
        }
    }

    // MARK: - Token Management

    /// Save admin token to Keychain
    static func saveToken(_ token: String) -> Bool {
        return KeychainService.save(token, for: .adminToken)
    }

    /// Check if admin token is configured
    static func hasToken() -> Bool {
        return KeychainService.exists(.adminToken)
    }

    /// Remove admin token
    static func removeToken() {
        KeychainService.delete(.adminToken)
    }
}

// MARK: - Response Model

private struct ReloadResponse: Codable {
    let status: String?
    let message: String?
}
