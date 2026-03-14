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

    /// Get transport type from API agency_id
    static func from(agencyId: String) -> TransportType {
        let upper = agencyId.uppercased()
        
        if upper.contains("METRO_LIGERO") || upper.contains("ML") {
            return .metroLigero
        }
        // Generic Metro detection (covers METRO_SEVILLA, TMB_METRO, METRO_BILBAO...)
        if upper.contains("METRO") {
            return .metro
        }
        // Generic Tram detection (covers TRAM_SEV, TRAM_BCN, TRANVIA_MURCIA, TUSSAM...)
        if upper.contains("TRAM") || upper.contains("TRANVIA") || upper.contains("TUSSAM") {
            return .tram
        }
        if upper.contains("FGC") {
            return .fgc
        }
        
        return .cercanias
    }
}
