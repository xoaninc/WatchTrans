//
//  DebugLog.swift
//  WatchTrans
//
//  Created by Claude on 25/1/26.
//  Conditional logging utility for debug builds
//

import Foundation

/// Debug logging utility that only prints in DEBUG builds
/// Usage: DebugLog.log("message") or DebugLog.log("📍 [Service] message")
/// Note: Methods are nonisolated to allow calling from any actor context
enum DebugLog {
    /// Set to false to disable all debug logging
    nonisolated(unsafe) static var isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// Log a message (only in debug builds when enabled)
    /// nonisolated to allow calling from actors and MainActor contexts
    nonisolated static func log(_ message: String) {
        guard isEnabled else { return }
        print(message)
    }

    /// Log with a specific category prefix
    nonisolated static func log(_ category: String, _ message: String) {
        guard isEnabled else { return }
        print("[\(category)] \(message)")
    }
}
