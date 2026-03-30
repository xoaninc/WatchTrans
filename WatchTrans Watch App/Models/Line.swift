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
    let type: TransportType   // .metro, .tren, .tram
    let colorHex: String      // Store as hex string for Codable
    let nucleo: String        // Province/network name: "madrid", "sevilla", "barcelona", etc.
    let agencyId: String      // Network code from API (e.g., "MMAD", "RENFE_C10", "CRTM_ML1")
    let agencyName: String?   // Human-readable agency name from API (e.g., "Cercanías Madrid")
    let routeIds: [String]    // Actual API route IDs (e.g., ["RENFE_C1_34"])
    let isCircular: Bool      // true for circular lines (L6, L12 MetroSur)
    var suspensionAlert: String? // Suspension message if service is suspended
    let serviceStatus: String?  // "active", "suspended", "partial" etc.
    let suspendedSince: String? // ISO date string when service was suspended
    let isAlternativeService: Bool? // true if running an alternative/replacement service
    let alternativeForShortName: String? // Name of route being substituted (e.g., "C1")

    // Computed property for SwiftUI Color (uses Color+Hex extension)
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}
