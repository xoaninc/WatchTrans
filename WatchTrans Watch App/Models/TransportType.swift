//
//  TransportType.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//

import Foundation

enum TransportType: String, Codable {
    case metro = "Metro"
    case metroLigero = "Metro Ligero"
    case cercanias = "Cercanías"
    case tram = "Tram"
    case fgc = "FGC"  // Ferrocarrils de la Generalitat de Catalunya

    /// Get transport type from GTFS route_type
    static func from(routeType: Int) -> TransportType {
        switch routeType {
        case 0: return .tram
        case 1: return .metro
        case 2: return .cercanias
        case 3: return .cercanias  // bus — Watch no tiene .bus, se agrupa
        case 7: return .cercanias  // funicular
        default: return .cercanias
        }
    }
}
