//
//  Stop.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//

import Foundation
import CoreLocation

struct Stop: Identifiable, Equatable {
    let id: String
    let name: String          // "Sol", "Atocha"
    let latitude: Double
    let longitude: Double
    let connectionLineIds: [String]   // IDs of other lines at this stop

    // Additional fields from RenfeServer API
    let province: String?
    let accesibilidad: String?
    let hasParking: Bool
    let hasBusConnection: Bool
    let hasMetroConnection: Bool
    let isHub: Bool           // true if station has 2+ different transport types

    // Connection details - Metro, Metro Ligero, Cercanías, and Tram line numbers
    let corMetro: String?      // Metro connections: "L1, L10" or "L6, L8, L10"
    let corMl: String?         // Metro Ligero connections: "ML1" or "ML2, ML3"
    let corCercanias: String?  // Cercanías connections: "C1, C10, C2" (for Metro/ML stops)
    let corTranvia: String?    // Tram connections: "T1"

    init(id: String, name: String, latitude: Double, longitude: Double, connectionLineIds: [String] = [],
         province: String? = nil, accesibilidad: String? = nil,
         hasParking: Bool = false, hasBusConnection: Bool = false, hasMetroConnection: Bool = false,
         isHub: Bool = false,
         corMetro: String? = nil, corMl: String? = nil, corCercanias: String? = nil, corTranvia: String? = nil) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.connectionLineIds = connectionLineIds
        self.province = province
        self.accesibilidad = accesibilidad
        self.hasParking = hasParking
        self.hasBusConnection = hasBusConnection
        self.hasMetroConnection = hasMetroConnection
        self.isHub = isHub
        self.corMetro = corMetro
        self.corMl = corMl
        self.corCercanias = corCercanias
        self.corTranvia = corTranvia
    }

    // Computed property for CLLocation
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
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
}

// MARK: - Codable conformance

extension Stop: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, connectionLineIds
        case province, accesibilidad
        case hasParking, hasBusConnection, hasMetroConnection, isHub
        case corMetro, corMl, corCercanias, corTranvia
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        connectionLineIds = try container.decodeIfPresent([String].self, forKey: .connectionLineIds) ?? []
        province = try container.decodeIfPresent(String.self, forKey: .province)
        accesibilidad = try container.decodeIfPresent(String.self, forKey: .accesibilidad)
        hasParking = try container.decodeIfPresent(Bool.self, forKey: .hasParking) ?? false
        hasBusConnection = try container.decodeIfPresent(Bool.self, forKey: .hasBusConnection) ?? false
        hasMetroConnection = try container.decodeIfPresent(Bool.self, forKey: .hasMetroConnection) ?? false
        isHub = try container.decodeIfPresent(Bool.self, forKey: .isHub) ?? false
        corMetro = try container.decodeIfPresent(String.self, forKey: .corMetro)
        corMl = try container.decodeIfPresent(String.self, forKey: .corMl)
        corCercanias = try container.decodeIfPresent(String.self, forKey: .corCercanias)
        corTranvia = try container.decodeIfPresent(String.self, forKey: .corTranvia)
    }
}
