//
//  Arrival.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//

import Foundation

struct Arrival: Identifiable, Codable {
    let id: String
    let lineId: String
    let lineName: String
    let destination: String   // "Aranjuez" - headsign from API
    let scheduledTime: Date
    let expectedTime: Date    // May differ if delayed
    let platform: String?
    let platformEstimated: Bool  // true if platform is estimated from historical data

    // Train position info (from API train_position object)
    let trainCurrentStop: String?      // "Alcalá de Henares"
    let trainProgressPercent: Double?  // 77.5
    let trainLatitude: Double?
    let trainLongitude: Double?
    let trainStatus: String?           // "IN_TRANSIT_TO", "STOPPED_AT"
    let trainEstimated: Bool?          // true if position is estimated
    let delaySeconds: Int?

    // Route info for detail view
    let routeColor: String?
    let routeId: String?  // Full route ID for API calls (e.g., "RENFE_C3_36")

    // Frequency-based (Metro)
    let frequencyBased: Bool
    let headwayMinutes: Int?

    // Delay calculation
    var isDelayed: Bool {
        if let delay = delaySeconds, delay > 60 {
            return true
        }
        return expectedTime > scheduledTime
    }

    var delayMinutes: Int {
        if let delay = delaySeconds {
            return delay / 60
        }
        guard expectedTime > scheduledTime else { return 0 }
        return Int(expectedTime.timeIntervalSince(scheduledTime) / 60)
    }

    // Minutes until arrival
    var minutesUntilArrival: Int {
        let interval = expectedTime.timeIntervalSinceNow
        return max(0, Int(interval / 60))
    }

    /// Formatted scheduled time string (e.g., "18:54")
    var scheduledTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: scheduledTime)
    }

    // Display string for arrival time
    // For GTFS-RT lines (Cercanías): show minutes if <30, show time if >=30
    // For frequency-based lines: show frequency or "+30 min"
    var arrivalTimeString: String {
        let minutes = minutesUntilArrival

        if minutes == 0 {
            return "Now"
        } else if minutes == 1 {
            return "1 min"
        } else if minutes >= 30 && isCercaniasLine {
            // Cercanías with GTFS-RT: show actual time when >= 30 min away
            return scheduledTimeString
        } else if minutes > 30 && !isCercaniasLine {
            // For all non-Cercanías lines (Metro, ML, Tranvía, etc.) cap at +30 min
            return "+ 30 min"
        } else {
            return "\(minutes) min"
        }
    }

    // Progress value for progress bar (0.0 to 1.0)
    // Assumes max display is 30 minutes
    var progressValue: Double {
        let minutes = Double(minutesUntilArrival)
        let maxMinutes = 30.0
        return max(0, min(1.0, 1.0 - (minutes / maxMinutes)))
    }

    /// Returns true if we have train position info to display
    var hasTrainPosition: Bool {
        return trainCurrentStop != nil || (trainLatitude != nil && trainLongitude != nil)
    }

    /// Returns human-readable train status
    var trainStatusText: String? {
        guard let status = trainStatus else { return nil }
        switch status {
        case "IN_TRANSIT_TO":
            return "En camino"
        case "STOPPED_AT":
            return "Parado en"
        case "INCOMING_AT":
            return "Llegando a"
        case "WAITING_AT_ORIGIN":
            return "En origen"
        case "SCHEDULED":
            return "Programado"
        case "CANCELED", "CANCELLED":
            return "Cancelado"
        case "SKIPPED":
            return "Omitido"
        case "NO_DATA":
            return "Sin datos"
        default:
            return status
        }
    }

    /// Check if this is a Metro/ML line (static GTFS, no real-time delay info)
    /// Uses lineId to distinguish Metro from FGC (both have L-prefixed lines)
    var isMetroLine: Bool {
        // If API says it's frequency-based, trust that
        if frequencyBased { return true }

        // Check by agency in lineId (e.g., "TMB_METRO_l1", "METRO_MADRID_l1")
        let lowerLineId = lineId.lowercased()
        if lowerLineId.contains("metro") { return true }
        if lowerLineId.contains("11t") { return true }  // Metro Madrid network

        // FGC lines should NOT be detected as Metro
        if lowerLineId.contains("fgc") { return false }

        // Fallback to name-based detection for ML (Metro Ligero)
        return lineName.hasPrefix("ML")
    }

    /// Check if this is a frequency-based line (Metro, ML, Tranvía)
    /// These lines don't have precise schedules, only frequency info
    var isFrequencyBasedLine: Bool {
        // If API explicitly says frequency-based, trust that
        if frequencyBased { return true }

        // Check by agency
        let lowerLineId = lineId.lowercased()
        if lowerLineId.contains("metro") { return true }
        if lowerLineId.contains("tram") || lowerLineId.contains("tranvia") { return true }
        if lowerLineId.contains("11t") || lowerLineId.contains("12t") { return true }  // Metro/ML Madrid

        // FGC is NOT purely frequency-based (has scheduled times)
        if lowerLineId.contains("fgc") { return false }

        // Fallback for ML and T lines
        return lineName.hasPrefix("ML") || lineName.hasPrefix("T")
    }

    /// Check if this is a Cercanías/Rodalies line (C1, C2, R1, R2, etc.)
    /// These are the only lines that show exact times even for > 30 min
    /// Excludes FGC R-lines (R5, R6, R50, R60) which are regional but not Rodalies/Cercanías
    var isCercaniasLine: Bool {
        let lowerLineId = lineId.lowercased()

        // FGC R-lines are NOT Cercanías/Rodalies
        if lowerLineId.contains("fgc") { return false }

        // Check by network ID in lineId
        if lowerLineId.contains("51t") { return true }  // Rodalies de Catalunya
        if lowerLineId.contains("10t") { return true }  // Cercanías Madrid
        if lowerLineId.contains("30t") { return true }  // Cercanías Sevilla
        if lowerLineId.contains("40t") { return true }  // Cercanías Valencia
        if lowerLineId.contains("50t") { return true }  // Cercanías Málaga
        if lowerLineId.contains("60t") { return true }  // Cercanías Bilbao
        if lowerLineId.contains("20t") { return true }  // Cercanías Asturias
        if lowerLineId.contains("70t") { return true }  // Cercanías Zaragoza

        // Fallback: C-lines are always Cercanías, R-lines only if not FGC
        if lineName.hasPrefix("C") { return true }
        if lineName.hasPrefix("R") && !lowerLineId.contains("fgc") { return true }

        return false
    }
}
