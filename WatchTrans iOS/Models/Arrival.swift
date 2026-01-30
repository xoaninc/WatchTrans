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

    // Offline mode flag
    let isOfflineData: Bool

    // Occupancy data (GTFS-RT standard, currently only TMB Metro Barcelona)
    let occupancyStatus: Int?       // 0-8 GTFS-RT OccupancyStatus
    let occupancyPercentage: Int?   // 0-100 percentage

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

    /// Formatted expected time string (e.g., "18:54")
    /// Uses expectedTime which includes any delays
    var expectedTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: expectedTime)
    }

    /// Check if this line has GTFS-RT (real-time data with precise schedules)
    /// Lines with GTFS-RT: Cercanías, Rodalies, Euskotren, FGC, Metro Bilbao, etc.
    /// Lines WITHOUT GTFS-RT: Metro Madrid, Metro Sevilla, Tranvía (frequency-based only)
    var hasGTFSRT: Bool {
        !frequencyBased
    }

    // Display string for arrival time
    // For GTFS-RT lines: show minutes if <30, show actual time if >=30
    // For frequency-based lines (no GTFS-RT): show minutes or "+30 min"
    var arrivalTimeString: String {
        let minutes = minutesUntilArrival

        if minutes == 0 {
            return "Now"
        } else if minutes == 1 {
            return "1 min"
        } else if minutes >= 30 && hasGTFSRT {
            // GTFS-RT lines: show expected time (with delays) when >= 30 min away
            return expectedTimeString
        } else if minutes > 30 {
            // Frequency-based lines (no GTFS-RT): cap at +30 min
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

    // MARK: - Occupancy

    /// Occupancy level for display (green/yellow/red/gray)
    var occupancyLevel: OccupancyLevel {
        guard let status = occupancyStatus else { return .unknown }
        switch status {
        case 0, 1: return .low        // EMPTY, MANY_SEATS_AVAILABLE
        case 2, 3: return .medium     // FEW_SEATS_AVAILABLE, STANDING_ROOM_ONLY
        case 4, 5, 6: return .high    // CRUSHED_STANDING_ROOM_ONLY, FULL, NOT_ACCEPTING_PASSENGERS
        default: return .unknown      // NO_DATA_AVAILABLE (7), NOT_BOARDABLE (8)
        }
    }

    /// Returns true if we have occupancy data to display
    var hasOccupancyData: Bool {
        occupancyStatus != nil && occupancyStatus != 7 && occupancyStatus != 8
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

// MARK: - Occupancy Level

/// Occupancy level for visual display
enum OccupancyLevel {
    case low       // 🟢 Empty or many seats (0-1)
    case medium    // 🟡 Few seats or standing (2-3)
    case high      // 🔴 Full or crushed (4-6)
    case unknown   // ⚫ No data (7-8 or nil)

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "red"
        case .unknown: return "gray"
        }
    }

    var iconName: String {
        switch self {
        case .low: return "person"
        case .medium: return "person.2"
        case .high: return "person.3"
        case .unknown: return "questionmark"
        }
    }

    var description: String {
        switch self {
        case .low: return "Poco lleno"
        case .medium: return "Moderado"
        case .high: return "Muy lleno"
        case .unknown: return "Sin datos"
        }
    }
}
