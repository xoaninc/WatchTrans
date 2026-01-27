//
//  GTFSRealtimeService.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//  Updated on 16/1/26 to use RedCercanías API (redcercanias.com)
//

import Foundation

@Observable
class GTFSRealtimeService {
    private let networkService: NetworkService

    // Use centralized API configuration
    private var baseURL: String { APIConfiguration.baseURL }

    var isLoading = false
    var lastFetchTime: Date?

    init(networkService: NetworkService = NetworkService()) {
        self.networkService = networkService
    }

    // MARK: - Departures (Primary endpoint for arrivals)

    /// Fetch upcoming departures from a stop
    /// This is the main endpoint for showing arrivals in the app
    /// Includes: delay info, train position, platform, frequency data
    func fetchDepartures(stopId: String, routeId: String? = nil, limit: Int = 20) async throws -> [DepartureResponse] {
        isLoading = true
        defer { isLoading = false }

        var urlString = "\(baseURL)/stops/\(stopId)/departures?limit=\(limit)"
        if let routeId = routeId {
            urlString += "&route_id=\(routeId)"
        }

        DebugLog.log("🚉 [DEP] Fetching: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }

        do {
            let rawData = try await networkService.fetchData(url)
            let rawString = String(data: rawData, encoding: .utf8) ?? "nil"
            DebugLog.log("🚉 [DEP] 📦 RAW response (\(rawData.count) bytes): \(rawString.prefix(500))")

            let decoder = JSONDecoder()
            let departures = try decoder.decode([DepartureResponse].self, from: rawData)

            lastFetchTime = Date()
            DebugLog.log("🚉 [DEP] ✅ Got \(departures.count) departures for \(stopId)")

            for (i, dep) in departures.prefix(3).enumerated() {
                let platformInfo = dep.platform.map { "vía \($0)\(dep.platformEstimated == true ? "?" : "")" } ?? ""
                DebugLog.log("🚉 [DEP]   [\(i)] \(dep.routeShortName) → \(dep.headsign ?? "?") in \(dep.minutesUntil)min \(platformInfo) (freq:\(dep.frequencyBased ?? false))")
            }

            return departures
        } catch {
            DebugLog.log("🚉 [DEP] ❌ FAILED for \(stopId): \(error)")
            throw error
        }
    }

    // MARK: - Routes & Stops

    /// Fetch stops for a route
    func fetchRouteStops(routeId: String) async throws -> [StopResponse] {
        guard let url = URL(string: "\(baseURL)/routes/\(routeId)/stops") else {
            throw NetworkError.badResponse
        }

        let stops: [StopResponse] = try await networkService.fetch(url)
        return stops
    }

    /// Fetch frequencies for a route (Metro, ML, Tranvía - frequency-based)
    func fetchFrequencies(routeId: String) async throws -> [FrequencyResponse] {
        let urlString = "\(baseURL)/routes/\(routeId)/frequencies"
        DebugLog.log("📅 [FREQ] Fetching: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }

        let data = try await networkService.fetchData(url)

        if let jsonString = String(data: data, encoding: .utf8) {
            DebugLog.log("📅 [FREQ] Raw JSON (first 300 chars): \(String(jsonString.prefix(300)))")
        }

        let decoder = JSONDecoder()
        do {
            let frequencies = try decoder.decode([FrequencyResponse].self, from: data)
            DebugLog.log("📅 [FREQ] ✅ Decoded \(frequencies.count) entries for \(routeId)")

            let byDayType = Dictionary(grouping: frequencies, by: { $0.dayType })
            for (dayType, freqs) in byDayType {
                let starts = freqs.map { $0.startTime }.sorted()
                let ends = freqs.map { $0.endTime }.sorted()
                DebugLog.log("📅 [FREQ]   \(dayType): \(freqs.count) entries, \(starts.first ?? "?") - \(ends.last ?? "?")")
            }

            return frequencies
        } catch {
            DebugLog.log("📅 [FREQ] ❌ Decode FAILED: \(error)")
            throw NetworkError.decodingError(error)
        }
    }

    /// Fetch operating hours for a route (Cercanías - schedule-based from stop_times)
    func fetchRouteOperatingHours(routeId: String) async throws -> RouteOperatingHoursResponse {
        guard let url = URL(string: "\(baseURL)/routes/\(routeId)/operating-hours") else {
            throw NetworkError.badResponse
        }

        DebugLog.log("📅 [RenfeServer] Calling: \(url.absoluteString)")
        let hours: RouteOperatingHoursResponse = try await networkService.fetch(url)
        DebugLog.log("📅 [RenfeServer] Operating hours for \(hours.routeShortName):")
        if let wd = hours.weekday {
            DebugLog.log("   📅 weekday: \(wd.firstDeparture) - \(wd.lastDeparture) (\(wd.totalTrips) trips)")
        }
        if let sat = hours.saturday {
            DebugLog.log("   📅 saturday: \(sat.firstDeparture) - \(sat.lastDeparture) (\(sat.totalTrips) trips)")
        }
        if let sun = hours.sunday {
            DebugLog.log("   📅 sunday: \(sun.firstDeparture) - \(sun.lastDeparture) (\(sun.totalTrips) trips)")
        }
        return hours
    }

    /// Fetch stops (with optional filters) - Used for search functionality
    func fetchStops(search: String? = nil, locationType: Int? = nil, limit: Int = 100) async throws -> [StopResponse] {
        var urlString = "\(baseURL)/stops?limit=\(limit)"

        if let search = search {
            urlString += "&search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)"
        }
        if let locationType = locationType {
            urlString += "&location_type=\(locationType)"
        }

        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }

        let stops: [StopResponse] = try await networkService.fetch(url)
        return stops
    }

    // MARK: - Trips

    /// Fetch trip details with all stops
    func fetchTrip(tripId: String) async throws -> TripDetailResponse {
        guard let url = URL(string: "\(baseURL)/trips/\(tripId)") else {
            throw NetworkError.badResponse
        }

        let trip: TripDetailResponse = try await networkService.fetch(url)
        return trip
    }

    // MARK: - Coordinate-based Location Detection

    /// Fetch stops by coordinates - uses Haversine distance calculation
    /// Returns all stops within radius_km, ordered by distance
    func fetchStopsByCoordinates(latitude: Double, longitude: Double, radiusKm: Int = 50, limit: Int = 600) async throws -> [StopResponse] {
        let urlString = "\(baseURL)/stops/by-coordinates?lat=\(latitude)&lon=\(longitude)&radius_km=\(radiusKm)&limit=\(limit)"
        DebugLog.log("📍 [COORD] Fetching stops: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }

        let stops: [StopResponse] = try await networkService.fetch(url)
        DebugLog.log("📍 [COORD] ✅ Got \(stops.count) stops for coordinates (\(latitude), \(longitude))")
        return stops
    }

    /// Fetch routes by coordinates - uses PostGIS province detection
    /// Returns all routes in the detected province's transport networks
    func fetchRoutesByCoordinates(latitude: Double, longitude: Double, limit: Int = 600) async throws -> [RouteResponse] {
        let urlString = "\(baseURL)/coordinates/routes?lat=\(latitude)&lon=\(longitude)&limit=\(limit)"
        DebugLog.log("📍 [COORD] Fetching routes: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }

        let routes: [RouteResponse] = try await networkService.fetch(url)
        DebugLog.log("📍 [COORD] ✅ Got \(routes.count) routes for coordinates (\(latitude), \(longitude))")
        return routes
    }

    // MARK: - Networks

    /// Fetch all available networks with transport type info
    func fetchNetworks() async throws -> [NetworkResponse] {
        guard let url = URL(string: "\(baseURL)/networks") else {
            throw NetworkError.badResponse
        }

        let networks: [NetworkResponse] = try await networkService.fetch(url)
        DebugLog.log("🌐 [RT] Fetched \(networks.count) networks")
        return networks
    }

    // MARK: - Alerts

    /// Fetch all active alerts
    func fetchAlerts() async throws -> [AlertResponse] {
        guard let url = URL(string: "\(baseURL)/realtime/alerts") else {
            throw NetworkError.badResponse
        }

        let alerts: [AlertResponse] = try await networkService.fetch(url)
        return alerts.filter { $0.isActive ?? true }
    }

    /// Fetch alerts for a specific stop (more efficient than fetchAlerts + filter)
    func fetchAlertsForStop(stopId: String) async throws -> [AlertResponse] {
        guard let url = URL(string: "\(baseURL)/realtime/stops/\(stopId)/alerts") else {
            throw NetworkError.badResponse
        }

        let alerts: [AlertResponse] = try await networkService.fetch(url)
        return alerts.filter { $0.isActive ?? true }
    }

    /// Fetch alerts for a specific route
    func fetchAlertsForRoute(routeId: String) async throws -> [AlertResponse] {
        guard let url = URL(string: "\(baseURL)/realtime/routes/\(routeId)/alerts") else {
            throw NetworkError.badResponse
        }

        let alerts: [AlertResponse] = try await networkService.fetch(url)
        return alerts.filter { $0.isActive ?? true }
    }

    // MARK: - Estimated Positions

    /// Fetch estimated positions for a network
    func fetchEstimatedPositionsForNetwork(networkId: String) async throws -> [EstimatedPositionResponse] {
        guard let url = URL(string: "\(baseURL)/realtime/networks/\(networkId)/estimated") else {
            throw NetworkError.badResponse
        }

        let positions: [EstimatedPositionResponse] = try await networkService.fetch(url)
        DebugLog.log("📍 [RT] Fetched \(positions.count) estimated positions for network \(networkId)")
        return positions
    }

    /// Fetch estimated positions for a route
    func fetchEstimatedPositionsForRoute(routeId: String) async throws -> [EstimatedPositionResponse] {
        guard let url = URL(string: "\(baseURL)/realtime/routes/\(routeId)/estimated") else {
            throw NetworkError.badResponse
        }

        let positions: [EstimatedPositionResponse] = try await networkService.fetch(url)
        return positions
    }

    // MARK: - Platforms & Correspondences

    /// Fetch platform coordinates for a station
    /// Returns the exact coordinates of each platform/line within a station
    func fetchPlatforms(stopId: String) async throws -> PlatformsResponse {
        guard let url = URL(string: "\(baseURL)/stops/\(stopId)/platforms") else {
            throw NetworkError.badResponse
        }

        let response: PlatformsResponse = try await networkService.fetch(url)
        DebugLog.log("🚏 [RT] Fetched \(response.platforms.count) platforms for \(stopId)")
        return response
    }

    /// Fetch walking correspondences from a station
    /// Returns nearby stations connected by walking passages
    func fetchCorrespondences(stopId: String) async throws -> CorrespondencesResponse {
        guard let url = URL(string: "\(baseURL)/stops/\(stopId)/correspondences") else {
            throw NetworkError.badResponse
        }

        let response: CorrespondencesResponse = try await networkService.fetch(url)
        DebugLog.log("🚶 [RT] Fetched \(response.correspondences.count) correspondences for \(stopId)")
        return response
    }

    // MARK: - Route Shapes

    /// Fetch shape (polyline) for a route
    /// Returns the coordinates to draw the route on a map
    func fetchRouteShape(routeId: String) async throws -> RouteShapeResponse {
        guard let url = URL(string: "\(baseURL)/routes/\(routeId)/shape") else {
            throw NetworkError.badResponse
        }

        let response: RouteShapeResponse = try await networkService.fetch(url)
        DebugLog.log("🗺️ [RT] Fetched \(response.shape.count) shape points for \(routeId)")
        return response
    }
}
