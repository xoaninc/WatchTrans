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

    /// Get transport type from API agency_id
    static func from(agencyId: String) -> TransportType {
        switch agencyId {
        case "METRO_MADRID":
            return .metro
        case "METRO_LIGERO":
            return .metroLigero
        default:
            return .cercanias
        }
    }
}
