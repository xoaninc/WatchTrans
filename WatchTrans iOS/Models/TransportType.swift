//
//  TransportType.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//

import Foundation

enum TransportType: String, Codable, Identifiable {
    case metro = "Metro"
    case metroLigero = "Metro Ligero"
    case cercanias = "Cercanías"
    case tram = "Tram"
    case fgc = "FGC"  // Ferrocarrils de la Generalitat de Catalunya
    case euskotren = "Euskotren"
    case bus = "Bus"

    var id: String { rawValue }

    /// Get transport type from GTFS route_type
    static func from(routeType: Int) -> TransportType {
        switch routeType {
        case 0: return .tram
        case 1: return .metro
        case 2: return .cercanias
        case 3: return .bus
        case 7: return .cercanias  // funicular — agrupado con cercanías
        default: return .cercanias
        }
    }
}
