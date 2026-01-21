//
//  NetworkError.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//  Network error types for API communication
//

import Foundation

enum NetworkError: Error {
    case noConnection
    case timeout
    case badResponse
    case decodingError(Error)
    case serverError(Int)
    case unknown(Error)

    var isTransient: Bool {
        switch self {
        case .timeout, .noConnection:
            return true
        case .serverError(let code) where code >= 500:
            return true
        default:
            return false
        }
    }

    var localizedDescription: String {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .badResponse:
            return "Invalid server response"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error (\(code))"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
