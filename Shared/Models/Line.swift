//
//  Line.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//

import Foundation
import SwiftUI

struct Line: Identifiable, Codable {
    let id: String
    let name: String          // "C3", "L1", "ML1"
    let longName: String      // "Chamartín - Aeropuerto T4"
    let type: TransportType   // .metro, .cercanias, .tram
    let colorHex: String      // Store as hex string for Codable
    let nucleo: String        // Province/network name: "madrid", "sevilla", "barcelona", etc.
    let routeIds: [String]    // Actual API route IDs (e.g., ["RENFE_C1_34"])

    // Computed property for SwiftUI Color (uses Color+Hex extension)
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}
