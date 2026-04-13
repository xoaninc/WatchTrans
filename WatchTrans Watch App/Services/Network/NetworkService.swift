//
//  NetworkService.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//  HTTP client for API requests with retry logic
//

import Foundation
import Pulse

class NetworkService {
    private let session: URLSession

    // Retry configuration
    private let maxRetries = 3
    private let baseDelay: TimeInterval = 1.0  // 1 second base delay

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = APIConfiguration.requestTimeout
        configuration.timeoutIntervalForResource = APIConfiguration.resourceTimeout
        configuration.waitsForConnectivity = true
        // Pulse Integration: Use URLSessionProxyDelegate to log requests
        self.session = URLSession(configuration: configuration, delegate: URLSessionProxyDelegate(), delegateQueue: nil)
    }

    /// Create a URLRequest with the API authorization header
    private func authorizedRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(APIConfiguration.authHeader, forHTTPHeaderField: "Authorization")
        return request
    }

    /// Fetch and decode JSON data from a URL with automatic retry
    func fetch<T: Decodable>(_ url: URL) async throws -> T {
        return try await fetchWithRetry(url, attempt: 1)
    }

    /// Internal fetch with retry logic using exponential backoff
    private func fetchWithRetry<T: Decodable>(_ url: URL, attempt: Int) async throws -> T {
        do {
            return try await performFetch(url)
        } catch let error as NetworkError {
            // Don't retry for certain errors
            switch error {
            case .decodingError, .badResponse, .timeout, .unknown:
                // These won't be fixed by retrying (fail fast)
                throw error
            case .noConnection, .serverError:
                // These might be temporary - retry
                if attempt < maxRetries {
                    let delay = baseDelay * pow(2.0, Double(attempt - 1))  // Exponential backoff: 1s, 2s, 4s
                    DebugLog.log("🔄 [NetworkService] Retry \(attempt)/\(maxRetries) after \(delay)s for: \(url.lastPathComponent)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await fetchWithRetry(url, attempt: attempt + 1)
                }
                throw error
            }
        }
    }

    /// Perform the actual fetch request
    private func performFetch<T: Decodable>(_ url: URL) async throws -> T {
        do {
            DebugLog.log("🌐 [NetworkService] GET \(url.lastPathComponent)")
            let (data, response) = try await session.data(for: authorizedRequest(for: url))

            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.badResponse
            }

            DebugLog.log("🌐 [NetworkService] GET \(url.lastPathComponent) -> \(httpResponse.statusCode)")
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            // Decode JSON
            let decoder = JSONDecoder()

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }

        } catch let error as NetworkError {
            DebugLog.log("🌐 [NetworkService] GET failed: \(error)")
            throw error
        } catch let error as URLError {
            // Map URLError to NetworkError
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                DebugLog.log("🌐 [NetworkService] GET no connection: \(error)")
                throw NetworkError.noConnection
            case .timedOut:
                DebugLog.log("🌐 [NetworkService] GET timeout: \(error)")
                throw NetworkError.timeout
            default:
                DebugLog.log("🌐 [NetworkService] GET url error: \(error)")
                throw NetworkError.unknown(error)
            }
        } catch {
            DebugLog.log("🌐 [NetworkService] GET unknown error: \(error)")
            throw NetworkError.unknown(error)
        }
    }

    /// Fetch raw data from a URL with automatic retry (for non-JSON responses)
    func fetchData(_ url: URL) async throws -> Data {
        return try await fetchDataWithRetry(url, attempt: 1)
    }

    /// POST raw data to a URL with automatic retry (for admin actions)
    func postData(_ url: URL, body: Data? = nil, headers: [String: String] = [:]) async throws -> Data {
        return try await postDataWithRetry(url, body: body, headers: headers, attempt: 1)
    }

    /// Internal fetchData with retry logic
    private func fetchDataWithRetry(_ url: URL, attempt: Int) async throws -> Data {
        do {
            return try await performFetchData(url)
        } catch let error as NetworkError {
            switch error {
            case .decodingError, .badResponse, .timeout, .unknown:
                // Fail fast
                throw error
            case .noConnection, .serverError:
                if attempt < maxRetries {
                    let delay = baseDelay * pow(2.0, Double(attempt - 1))
                    DebugLog.log("🔄 [NetworkService] Retry \(attempt)/\(maxRetries) after \(delay)s for: \(url.lastPathComponent)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await fetchDataWithRetry(url, attempt: attempt + 1)
                }
                throw error
            }
        }
    }

    /// Perform the actual data fetch
    private func performFetchData(_ url: URL) async throws -> Data {
        do {
            DebugLog.log("🌐 [NetworkService] GET(data) \(url.lastPathComponent)")
            let (data, response) = try await session.data(for: authorizedRequest(for: url))

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.badResponse
            }

            DebugLog.log("🌐 [NetworkService] GET(data) \(url.lastPathComponent) -> \(httpResponse.statusCode)")
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            return data

        } catch let error as NetworkError {
            DebugLog.log("🌐 [NetworkService] GET(data) failed: \(error)")
            throw error
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                DebugLog.log("🌐 [NetworkService] GET(data) no connection: \(error)")
                throw NetworkError.noConnection
            case .timedOut:
                DebugLog.log("🌐 [NetworkService] GET(data) timeout: \(error)")
                throw NetworkError.timeout
            default:
                DebugLog.log("🌐 [NetworkService] GET(data) url error: \(error)")
                throw NetworkError.unknown(error)
            }
        } catch {
            DebugLog.log("🌐 [NetworkService] GET(data) unknown error: \(error)")
            throw NetworkError.unknown(error)
        }
    }

    /// Internal postData with retry logic
    private func postDataWithRetry(_ url: URL, body: Data?, headers: [String: String], attempt: Int) async throws -> Data {
        do {
            return try await performPostData(url, body: body, headers: headers)
        } catch let error as NetworkError {
            switch error {
            case .decodingError, .badResponse, .timeout, .unknown:
                // Fail fast
                throw error
            case .noConnection, .serverError:
                if attempt < maxRetries {
                    let delay = baseDelay * pow(2.0, Double(attempt - 1))
                    DebugLog.log("🔄 [NetworkService] Retry \(attempt)/\(maxRetries) after \(delay)s for POST: \(url.lastPathComponent)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await postDataWithRetry(url, body: body, headers: headers, attempt: attempt + 1)
                }
                throw error
            }
        }
    }

    /// Perform the actual POST request
    private func performPostData(_ url: URL, body: Data?, headers: [String: String]) async throws -> Data {
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue(APIConfiguration.authHeader, forHTTPHeaderField: "Authorization")
            headers.forEach { key, value in
                request.setValue(value, forHTTPHeaderField: key)
            }

            DebugLog.log("🌐 [NetworkService] POST \(url.lastPathComponent)")
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.badResponse
            }

            DebugLog.log("🌐 [NetworkService] POST \(url.lastPathComponent) -> \(httpResponse.statusCode)")
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            return data
        } catch let error as NetworkError {
            DebugLog.log("🌐 [NetworkService] POST failed: \(error)")
            throw error
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                DebugLog.log("🌐 [NetworkService] POST no connection: \(error)")
                throw NetworkError.noConnection
            case .timedOut:
                DebugLog.log("🌐 [NetworkService] POST timeout: \(error)")
                throw NetworkError.timeout
            default:
                DebugLog.log("🌐 [NetworkService] POST url error: \(error)")
                throw NetworkError.unknown(error)
            }
        } catch {
            DebugLog.log("🌐 [NetworkService] POST unknown error: \(error)")
            throw NetworkError.unknown(error)
        }
    }
}
