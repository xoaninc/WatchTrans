//
//  LocationService.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//

import Foundation
import CoreLocation
import Combine

@Observable
class LocationService: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var locationError: Error?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }

    // Request location permission
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    // Start updating location
    func startUpdating() {
        locationManager.startUpdatingLocation()
    }

    // Stop updating location
    func stopUpdating() {
        locationManager.stopUpdatingLocation()
    }

    // Request single location update
    func requestLocation() {
        locationManager.requestLocation()
    }

    // Find nearest stop from a list
    func findNearestStop(from stops: [Stop]) -> Stop? {
        guard let location = currentLocation else { return nil }

        return stops.min(by: { stop1, stop2 in
            stop1.distance(from: location) < stop2.distance(from: location)
        })
    }

    // Sort stops by distance from current location
    func sortStopsByDistance(_ stops: [Stop]) -> [Stop] {
        guard let location = currentLocation else { return stops }

        return stops.sorted { stop1, stop2 in
            stop1.distance(from: location) < stop2.distance(from: location)
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startUpdating()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        locationError = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error
        print("Location error: \(error.localizedDescription)")
    }
}
