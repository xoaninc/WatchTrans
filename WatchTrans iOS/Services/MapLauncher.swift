//
//  MapLauncher.swift
//  WatchTrans iOS
//
//  Created by Claude on 27/1/26.
//  Opens locations in external map apps
//

import UIKit
import CoreLocation

/// Service for opening locations in external map apps
enum MapLauncher {

    /// Available map apps
    enum MapApp: CaseIterable {
        case appleMaps
        case googleMaps
        case citymapper
        case waze

        var name: String {
            switch self {
            case .appleMaps: return "Apple Maps"
            case .googleMaps: return "Google Maps"
            case .citymapper: return "Citymapper"
            case .waze: return "Waze"
            }
        }

        var icon: String {
            switch self {
            case .appleMaps: return "map.fill"
            case .googleMaps: return "g.circle.fill"
            case .citymapper: return "arrow.triangle.turn.up.right.diamond.fill"
            case .waze: return "car.fill"
            }
        }

        /// URL scheme to check if app is installed
        fileprivate var urlScheme: String? {
            switch self {
            case .appleMaps: return nil // Always available
            case .googleMaps: return "comgooglemaps://"
            case .citymapper: return "citymapper://"
            case .waze: return "waze://"
            }
        }
    }

    /// Returns list of installed map apps
    static func availableApps() -> [MapApp] {
        return MapApp.allCases.filter { isAppInstalled($0) }
    }

    /// Check if a map app is installed
    static func isAppInstalled(_ app: MapApp) -> Bool {
        guard let scheme = app.urlScheme,
              let url = URL(string: scheme) else {
            return true // Apple Maps is always available
        }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Open location in specified map app
    /// - Parameters:
    ///   - coordinate: The location to open
    ///   - name: Name of the location (for labeling)
    ///   - app: Which map app to use
    static func open(
        coordinate: CLLocationCoordinate2D,
        name: String,
        in app: MapApp
    ) {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name

        let urlString: String

        switch app {
        case .appleMaps:
            // Apple Maps with label
            urlString = "maps://?ll=\(lat),\(lon)&q=\(encodedName)"

        case .googleMaps:
            // Google Maps with query
            urlString = "comgooglemaps://?q=\(lat),\(lon)&zoom=17"

        case .citymapper:
            // Citymapper with coordinates
            urlString = "citymapper://directions?endcoord=\(lat),\(lon)&endname=\(encodedName)"

        case .waze:
            // Waze navigation
            urlString = "waze://?ll=\(lat),\(lon)&navigate=yes"
        }

        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    /// Open location in Apple Maps (convenience method)
    static func openInAppleMaps(coordinate: CLLocationCoordinate2D, name: String) {
        open(coordinate: coordinate, name: name, in: .appleMaps)
    }

    /// Get directions to location in specified app
    static func getDirections(
        to coordinate: CLLocationCoordinate2D,
        name: String,
        in app: MapApp
    ) {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name

        let urlString: String

        switch app {
        case .appleMaps:
            urlString = "maps://?daddr=\(lat),\(lon)&dirflg=w" // Walking directions

        case .googleMaps:
            urlString = "comgooglemaps://?daddr=\(lat),\(lon)&directionsmode=walking"

        case .citymapper:
            urlString = "citymapper://directions?endcoord=\(lat),\(lon)&endname=\(encodedName)"

        case .waze:
            urlString = "waze://?ll=\(lat),\(lon)&navigate=yes"
        }

        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
