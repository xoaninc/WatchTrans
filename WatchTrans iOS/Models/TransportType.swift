//
//  TransportType.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//

import Foundation

enum TransportType: String, Codable, Identifiable {
    case metro = "Metro"
    case tren = "Tren"
    case tram = "Tram"
    case bus = "Bus"
    case funicular = "Funicular"

    var id: String { rawValue }

    /// Get transport type from GTFS route_type
    static func from(routeType: Int) -> TransportType {
        switch routeType {
        case 0: return .tram
        case 1: return .metro
        case 2: return .tren
        case 3: return .bus
        case 7: return .funicular
        default: return .tren
        }
    }
}
