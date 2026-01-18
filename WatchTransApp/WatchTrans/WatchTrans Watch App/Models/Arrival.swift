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

    // Display string for arrival time
    var arrivalTimeString: String {
        let minutes = minutesUntilArrival

        if minutes == 0 {
            return "Now"
        } else if minutes == 1 {
            return "1 min"
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
    var isMetroLine: Bool {
        frequencyBased || lineName.hasPrefix("L") || lineName.hasPrefix("ML")
    }

    /// Check if this is a frequency-based line (Metro, ML, Tranvía)
    /// These lines don't have precise schedules, only frequency info
    var isFrequencyBasedLine: Bool {
        frequencyBased || lineName.hasPrefix("L") || lineName.hasPrefix("ML") || lineName.hasPrefix("T")
    }

    /// Check if this is a Cercanías/Rodalies line (C1, C2, R1, R2, etc.)
    /// These are the only lines that show exact times even for > 30 min
    var isCercaniasLine: Bool {
        lineName.hasPrefix("C") || lineName.hasPrefix("R")
    }
}
