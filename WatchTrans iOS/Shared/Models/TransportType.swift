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

    /// Get transport type from API agency_id
    static func from(agencyId: String) -> TransportType {
        switch agencyId {
        case "METRO_LIGERO":
            return .metroLigero
        case "TMB_METRO":
            // Barcelona Metro (TMB - Transports Metropolitans de Barcelona)
            return .metro
        case "FGC":
            // Ferrocarrils de la Generalitat de Catalunya
            return .fgc
        default:
            // Any agency starting with METRO_ is metro (Madrid, Sevilla, Bilbao, etc.)
            if agencyId.hasPrefix("METRO_") {
                return .metro
            }
            // Any agency starting with TRANVIA_ is tram (Sevilla, Murcia, Zaragoza)
            if agencyId.hasPrefix("TRANVIA_") {
                return .tram
            }
            // Any agency starting with TRAM_ is tram (Barcelona Tram, Alicante)
            if agencyId.hasPrefix("TRAM_") {
                return .tram
            }
            return .cercanias
        }
    }
}
