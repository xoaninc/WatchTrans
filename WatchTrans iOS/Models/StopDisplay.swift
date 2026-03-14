//
//  StopDisplay.swift
//  WatchTrans iOS
//
//  Created by Codex on 5/2/26.
//

import Foundation

/// UI representation of a stop scoped to a single transport type
struct StopDisplay: Identifiable, Equatable {
    let stop: Stop
    let transportType: TransportType
    let allowedLineIds: [String]

    var id: String {
        "\(stop.id)|\(transportType.rawValue)"
    }

    /// Key for recent stops tracking
    var recentKey: String {
        id
    }

    /// Normalized line IDs for quick filtering
    var normalizedLineIds: Set<String> {
        Set(allowedLineIds.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
    }
}
