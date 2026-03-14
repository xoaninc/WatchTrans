//
//  Stop.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//

import Foundation
import CoreLocation

struct Stop: Identifiable, Equatable, Hashable {
    let id: String
    let name: String          // "Sol", "Atocha"
    let latitude: Double
    let longitude: Double

    // Additional fields from API
    let province: String?
    let accesibilidad: String?
    let hasParking: Bool
    let hasBusConnection: Bool
    let hasMetroConnection: Bool
    let isHub: Bool           // true if station has 2+ different transport types

    // Connection details - Metro, Metro Ligero, Cercanías, and Tram line numbers
    let corMetro: String?      // Metro connections: "L1, L10" or "L6, L8, L10"
    let corMl: String?         // Metro Ligero connections: "ML1" or "ML2, ML3"
    let corTren: String?       // Train connections (Cercanías, FEVE, etc.): "C1, C10, C2" (for Metro/ML stops)
    let corTranvia: String?    // Tram connections: "T1"
    let corBus: String?        // Bus connections
    let corFunicular: String?  // Funicular connections
    let correspondences: StopCorrespondences?
    let wheelchairBoarding: Int? // 0=unknown, 1=accessible, 2=not accessible, null=no data
    let serviceStatus: String?  // "active", "suspended", "partial" etc.
    let suspendedSince: String? // ISO date string when service was suspended

    init(id: String, name: String, latitude: Double, longitude: Double,
         province: String? = nil, accesibilidad: String? = nil,
         hasParking: Bool = false, hasBusConnection: Bool = false, hasMetroConnection: Bool = false,
         isHub: Bool = false,
         corMetro: String? = nil, corMl: String? = nil, corTren: String? = nil, corTranvia: String? = nil,
         corBus: String? = nil, corFunicular: String? = nil,
         correspondences: StopCorrespondences? = nil, wheelchairBoarding: Int? = nil,
         serviceStatus: String? = nil, suspendedSince: String? = nil) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.province = province
        self.accesibilidad = accesibilidad
        self.hasParking = hasParking
        self.hasBusConnection = hasBusConnection
        self.hasMetroConnection = hasMetroConnection
        self.isHub = isHub
        self.corMetro = corMetro
        self.corMl = corMl
        self.corTren = corTren
        self.corTranvia = corTranvia
        self.corBus = corBus
        self.corFunicular = corFunicular
        self.correspondences = correspondences
        self.wheelchairBoarding = wheelchairBoarding
        self.serviceStatus = serviceStatus
        self.suspendedSince = suspendedSince
    }

    // Computed property for CLLocation
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    /// Get the transport type from the stop ID prefix
    var transportType: TransportType {
        if id.hasPrefix("METRO_") {
            return .metro
        } else if id.hasPrefix("ML_") || id.hasPrefix("METRO_LIGERO") {
            return .metroLigero
        } else if id.hasPrefix("TRANVIA_") || id.hasPrefix("TRAM_") {
            return .tram
        } else if id.hasPrefix("FGC") {
            return .fgc
        }

        // If the stop ID doesn't encode the mode, infer from cor_* fields.
        if corMl != nil && !(corMl?.isEmpty ?? true) { return .metroLigero }
        if corMetro != nil && !(corMetro?.isEmpty ?? true) { return .metro }
        if corTranvia != nil && !(corTranvia?.isEmpty ?? true) { return .tram }
        if corTren != nil && !(corTren?.isEmpty ?? true) { return .cercanias }
        if corFunicular != nil && !(corFunicular?.isEmpty ?? true) { return .cercanias }

        return .cercanias
    }

    // Calculate distance from current location
    func distance(from location: CLLocation) -> Double {
        return self.location.distance(from: location)
    }

    // Format distance for display
    func formattedDistance(from location: CLLocation) -> String {
        let distanceInMeters = distance(from: location)

        if distanceInMeters < 1000 {
            return "\(Int(distanceInMeters))m"
        } else {
            let distanceInKm = distanceInMeters / 1000
            return String(format: "%.1fkm", distanceInKm)
        }
    }

    /// Check if this stop has correspondence with other lines (excluding the current line being viewed)
    /// Used to show interchange markers on route maps
    func hasCorrespondence(excludingLine currentLine: String) -> Bool {
        let normalizedCurrent = Self.normalizeLineName(currentLine)

        // Count metro lines excluding the current one
        let metroLines = corMetro?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { Self.normalizeLineName(String($0)) != normalizedCurrent && !$0.isEmpty } ?? []

        // Count metro ligero lines excluding current
        let mlLines = corMl?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { Self.normalizeLineName(String($0)) != normalizedCurrent && !$0.isEmpty } ?? []

        // Count train lines (Cercanías, FEVE, etc.) excluding current
        let cercaniasLines = corTren?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { Self.normalizeLineName(String($0)) != normalizedCurrent && !$0.isEmpty } ?? []

        // Count tram lines excluding current
        let tramLines = corTranvia?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { Self.normalizeLineName(String($0)) != normalizedCurrent && !$0.isEmpty } ?? []

        // Has correspondence if any other lines exist
        return !metroLines.isEmpty || !mlLines.isEmpty || !cercaniasLines.isEmpty || !tramLines.isEmpty || (corFunicular != nil && !corFunicular!.isEmpty) || (corBus != nil && !corBus!.isEmpty) || correspondences != nil
    }

    /// Normalize line name for comparison (handles "L1" vs "1" vs "Línea 1" etc.)
    private static func normalizeLineName(_ name: String) -> String {
        var normalized = name.lowercased()
            .replacingOccurrences(of: "línea ", with: "")
            .replacingOccurrences(of: "linea ", with: "")
            .replacingOccurrences(of: "line ", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Remove common prefixes to get just the number/identifier
        // "l1" -> "1", "c3" -> "3", "ml2" -> "ml2" (keep ml prefix)
        if normalized.hasPrefix("l") && !normalized.hasPrefix("ml") {
            normalized = String(normalized.dropFirst())
        } else if normalized.hasPrefix("c") && normalized.count > 1 {
            let afterC = normalized.dropFirst()
            if afterC.first?.isNumber == true {
                normalized = String(afterC)
            }
        }

        return normalized
    }
}

// MARK: - Codable conformance

extension Stop: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name
        case latitude = "lat"
        case longitude = "lon"
        case province, accesibilidad
        case hasParking = "has_parking"
        case hasBusConnection = "has_bus_connection"
        case hasMetroConnection = "has_metro_connection"
        case isHub = "is_hub"
        case corMetro = "cor_metro"
        case corMl = "cor_ml"
        case corTren = "cor_tren"
        case corTranvia = "cor_tranvia"
        case corBus = "cor_bus"
        case corFunicular = "cor_funicular"
        case correspondences
        case wheelchairBoarding = "wheelchair_boarding"
        case serviceStatus = "service_status"
        case suspendedSince = "suspended_since"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        province = try container.decodeIfPresent(String.self, forKey: .province)
        accesibilidad = try container.decodeIfPresent(String.self, forKey: .accesibilidad)
        hasParking = try container.decodeIfPresent(Bool.self, forKey: .hasParking) ?? false
        hasBusConnection = try container.decodeIfPresent(Bool.self, forKey: .hasBusConnection) ?? false
        hasMetroConnection = try container.decodeIfPresent(Bool.self, forKey: .hasMetroConnection) ?? false
        isHub = try container.decodeIfPresent(Bool.self, forKey: .isHub) ?? false
        corMetro = try container.decodeIfPresent(String.self, forKey: .corMetro)
        corMl = try container.decodeIfPresent(String.self, forKey: .corMl)
        corTren = try container.decodeIfPresent(String.self, forKey: .corTren)
        corTranvia = try container.decodeIfPresent(String.self, forKey: .corTranvia)
        corBus = try container.decodeIfPresent(String.self, forKey: .corBus)
        corFunicular = try container.decodeIfPresent(String.self, forKey: .corFunicular)
        correspondences = try container.decodeIfPresent(StopCorrespondences.self, forKey: .correspondences)
        wheelchairBoarding = try container.decodeIfPresent(Int.self, forKey: .wheelchairBoarding)
        serviceStatus = try container.decodeIfPresent(String.self, forKey: .serviceStatus)
        suspendedSince = try container.decodeIfPresent(String.self, forKey: .suspendedSince)
    }
}
