//
//  NetworkService.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//  HTTP client for API requests with retry logic
//

import Foundation

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
        self.session = URLSession(configuration: configuration)
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
            case .decodingError, .badResponse:
                // These won't be fixed by retrying
                throw error
            case .noConnection, .timeout, .serverError, .unknown:
                // These might be temporary - retry
                if attempt < maxRetries {
                    let delay = baseDelay * pow(2.0, Double(attempt - 1))  // Exponential backoff: 1s, 2s, 4s
                    print("🔄 [NetworkService] Retry \(attempt)/\(maxRetries) after \(delay)s for: \(url.lastPathComponent)")
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
            let (data, response) = try await session.data(from: url)

            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.badResponse
            }

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
            throw error
        } catch let error as URLError {
            // Map URLError to NetworkError
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw NetworkError.noConnection
            case .timedOut:
                throw NetworkError.timeout
            default:
                throw NetworkError.unknown(error)
            }
        } catch {
            throw NetworkError.unknown(error)
        }
    }

    /// Fetch raw data from a URL with automatic retry (for non-JSON responses)
    func fetchData(_ url: URL) async throws -> Data {
        return try await fetchDataWithRetry(url, attempt: 1)
    }

    /// Internal fetchData with retry logic
    private func fetchDataWithRetry(_ url: URL, attempt: Int) async throws -> Data {
        do {
            return try await performFetchData(url)
        } catch let error as NetworkError {
            switch error {
            case .badResponse:
                throw error
            case .noConnection, .timeout, .serverError, .decodingError, .unknown:
                if attempt < maxRetries {
                    let delay = baseDelay * pow(2.0, Double(attempt - 1))
                    print("🔄 [NetworkService] Retry \(attempt)/\(maxRetries) after \(delay)s for: \(url.lastPathComponent)")
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
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.badResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            return data

        } catch let error as NetworkError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw NetworkError.noConnection
            case .timedOut:
                throw NetworkError.timeout
            default:
                throw NetworkError.unknown(error)
            }
        } catch {
            throw NetworkError.unknown(error)
        }
    }
}
