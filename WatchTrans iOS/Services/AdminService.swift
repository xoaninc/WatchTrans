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
    // Admin endpoints (different from public API)
    // Try in order; some deployments use /admin/reload or /admin/reload-gtfs
    private static let adminURLs = [
        "\(APIConfiguration.apiBaseURL)/admin/reload",
        "\(APIConfiguration.apiBaseURL)/admin/reload-gtfs"
    ]

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

        for urlString in adminURLs {
            guard let url = URL(string: urlString) else {
                continue
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(token, forHTTPHeaderField: "X-Admin-Token")
            request.timeoutInterval = 30

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    continue
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

                case 404:
                    // Try next URL
                    continue

                default:
                    return .error("Error \(httpResponse.statusCode)")
                }
            } catch {
                return .error(error.localizedDescription)
            }
        }

        return .error("Error 404")
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
