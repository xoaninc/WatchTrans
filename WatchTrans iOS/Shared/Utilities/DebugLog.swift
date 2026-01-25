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
enum DebugLog {
    /// Set to false to disable all debug logging
    static var isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// Log a message (only in debug builds when enabled)
    static func log(_ message: String) {
        guard isEnabled else { return }
        print(message)
    }

    /// Log with a specific category prefix
    static func log(_ category: String, _ message: String) {
        guard isEnabled else { return }
        print("[\(category)] \(message)")
    }
}
