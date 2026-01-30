//
//  NetworkMonitor.swift
//  WatchTrans iOS
//
//  Created by Claude on 28/1/26.
//  Monitors network connectivity to enable offline mode
//

import Foundation
import Network
import Combine

/// Monitors network connectivity status
/// Uses NWPathMonitor for reliable detection of WiFi/Cellular availability
@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.watchtrans.networkmonitor")

    /// Current connectivity status
    @Published private(set) var isConnected = true

    /// Connection type (wifi, cellular, etc)
    @Published private(set) var connectionType: ConnectionType = .unknown

    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            let connectionType = self?.getConnectionType(path) ?? .unknown

            Task { @MainActor [weak self] in
                self?.isConnected = isConnected
                self?.connectionType = connectionType

                if isConnected {
                    DebugLog.log("🌐 [Network] Connected via \(connectionType)")
                } else {
                    DebugLog.log("🌐 [Network] Disconnected - offline mode active")
                }
            }
        }
        monitor.start(queue: queue)
    }

    nonisolated private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        }
        return .unknown
    }

    deinit {
        monitor.cancel()
    }
}
