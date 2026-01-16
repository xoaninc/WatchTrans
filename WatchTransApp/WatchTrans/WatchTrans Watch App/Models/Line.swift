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
    let type: TransportType   // .metro, .cercanias, .tram
    let colorHex: String      // Store as hex string for Codable
    let nucleo: String        // Nucleo name from API: "madrid", "sevilla", etc.

    // Computed property for SwiftUI Color
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}

// Helper extension to create Color from hex
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
