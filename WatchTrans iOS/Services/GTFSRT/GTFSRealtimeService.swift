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
        let urlString = "\(baseURL)/realtime/routes/\(routeId)/alerts"
        DebugLog.log("🔔 [GTFSRT] Fetching alerts from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            DebugLog.log("❌ [GTFSRT] Invalid URL: \(urlString)")
            throw NetworkError.badResponse
        }

        let alerts: [AlertResponse] = try await networkService.fetch(url)
        DebugLog.log("🔔 [GTFSRT] Raw response: \(alerts.count) alerts")
        
        let activeAlerts = alerts.filter { $0.isActive ?? true }
        DebugLog.log("🔔 [GTFSRT] After filtering active: \(activeAlerts.count) alerts")
        
        if activeAlerts.isEmpty && !alerts.isEmpty {
            DebugLog.log("⚠️ [GTFSRT] WARNING: All \(alerts.count) alerts were filtered out as inactive!")
            for alert in alerts {
                DebugLog.log("⚠️ [GTFSRT]   - \(alert.alertId): isActive=\(alert.isActive ?? false)")
            }
        }
        
        return activeAlerts
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
    /// - Parameters:
    ///   - stopId: The station ID
    ///   - includeShape: If true, includes walking route coordinates in response
    func fetchCorrespondences(stopId: String, includeShape: Bool = false) async throws -> CorrespondencesResponse {
        var urlString = "\(baseURL)/stops/\(stopId)/correspondences"
        if includeShape {
            urlString += "?include_shape=true"
        }

        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }

        let response: CorrespondencesResponse = try await networkService.fetch(url)
        DebugLog.log("🚶 [RT] Fetched \(response.correspondences.count) correspondences for \(stopId)\(includeShape ? " (with shapes)" : "")")
        return response
    }

    // MARK: - Route Shapes

    /// Fetch shape (polyline) for a route
    /// Returns the coordinates to draw the route on a map
    /// - Parameters:
    ///   - routeId: The route ID
    ///   - maxGap: Maximum gap between points
    ///   - includeStops: If true, includes stops with on_shape coordinates projected onto the line
    func fetchRouteShape(routeId: String, maxGap: Int? = nil, includeStops: Bool = false) async throws -> RouteShapeResponse {
        var urlString = "\(baseURL)/routes/\(routeId)/shape"
        var params: [String] = []

        if let maxGap = maxGap {
            params.append("max_gap=\(maxGap)")
        }
        if includeStops {
            params.append("include_stops=true")
        }

        if !params.isEmpty {
            urlString += "?" + params.joined(separator: "&")
        }

        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }

        DebugLog.log("🗺️ [RT] 📡 Shape request: \(urlString)")
        let response: RouteShapeResponse = try await networkService.fetch(url)
        DebugLog.log("🗺️ [RT] ✅ Shape response: \(response.shape.count) points, \(response.stops?.count ?? 0) stops for \(response.routeId)")
        return response
    }

    // MARK: - Route Planner

    /// Fetch a planned journey between two stops
    /// Returns complete journey with segments, times, and normalized coordinates
    /// - Parameters:
    ///   - fromStopId: Origin stop ID
    ///   - toStopId: Destination stop ID
    ///   - compact: If true, returns minimal response for Widget/Siri (<5KB)
    func fetchRoutePlan(fromStopId: String, toStopId: String, compact: Bool = false) async throws -> RoutePlanResponse {
        var urlString = "\(baseURL)/route-planner?from=\(fromStopId)&to=\(toStopId)"
        if compact {
            urlString += "&compact=true"
        }

        DebugLog.log("🗺️ [RT] ▶️ ROUTE PLAN REQUEST")
        DebugLog.log("🗺️ [RT]   From: \(fromStopId)")
        DebugLog.log("🗺️ [RT]   To: \(toStopId)")
        DebugLog.log("🗺️ [RT]   Compact: \(compact)")
        DebugLog.log("🗺️ [RT]   URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            DebugLog.log("🗺️ [RT] ❌ Invalid URL: \(urlString)")
            throw NetworkError.badResponse
        }

        let startTime = Date()
        let response: RoutePlanResponse = try await networkService.fetch(url)
        let elapsed = Date().timeIntervalSince(startTime)

        DebugLog.log("🗺️ [RT] ⏱️ API RESPONSE in \(String(format: "%.3f", elapsed))s")
        DebugLog.log("🗺️ [RT]   Success: \(response.success)")
        DebugLog.log("🗺️ [RT]   Message: \(response.message ?? "none")")

        if response.success {
            let journeys = response.allJourneys
            DebugLog.log("🗺️ [RT] ✅ ROUTE PLAN SUCCESS")
            DebugLog.log("🗺️ [RT]   Total journeys: \(journeys.count)")

            for (i, journey) in journeys.enumerated() {
                DebugLog.log("🗺️ [RT]   ━━━ Journey \(i+1)/\(journeys.count) ━━━")
                DebugLog.log("🗺️ [RT]     Duration: \(journey.totalDurationMinutes) min")
                DebugLog.log("🗺️ [RT]     Transfers: \(journey.transferCount)")
                DebugLog.log("🗺️ [RT]     Walking: \(journey.totalWalkingMinutes) min")
                DebugLog.log("🗺️ [RT]     Segments: \(journey.segments.count)")

                for (j, seg) in journey.segments.enumerated() {
                    let lineInfo = seg.lineName ?? "🚶 walk"
                    let coordCount = seg.coordinates.count
                    let intermediateCount = seg.intermediateStops?.count ?? 0
                    DebugLog.log("🗺️ [RT]       [\(j+1)] \(seg.type.uppercased()): \(lineInfo)")
                    DebugLog.log("🗺️ [RT]            lineId: \(seg.lineId ?? "nil")")
                    DebugLog.log("🗺️ [RT]            \(seg.origin.name) → \(seg.destination.name)")
                    DebugLog.log("🗺️ [RT]            \(seg.durationMinutes) min | \(coordCount) coords | \(intermediateCount) stops")
                }
            }

            if let alerts = response.alerts, !alerts.isEmpty {
                DebugLog.log("🗺️ [RT]   ⚠️ SERVICE ALERTS: \(alerts.count)")
                for (i, alert) in alerts.enumerated() {
                    DebugLog.log("🗺️ [RT]     [\(i+1)] [\(alert.severity.uppercased())] \(alert.lineId ?? "GENERAL")")
                    DebugLog.log("🗺️ [RT]         \(alert.message)")
                }
            } else {
                DebugLog.log("🗺️ [RT]   ℹ️ No service alerts")
            }
        } else {
            DebugLog.log("🗺️ [RT] ❌ ROUTE PLAN FAILED: \(response.message ?? "unknown error")")
        }

        return response
    }

    // MARK: - Station Accesses

    /// Fetch physical entrances (bocas de metro) for a station
    /// Returns all access points with coordinates, accessibility info, and opening hours
    func fetchAccesses(stopId: String) async throws -> AccessesResponse {
        let urlString = "\(baseURL)/stops/\(stopId)/accesses"
        DebugLog.log("🚪 [RT] Fetching accesses: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }

        let response: AccessesResponse = try await networkService.fetch(url)
        DebugLog.log("🚪 [RT] ✅ Got \(response.accesses.count) accesses for \(response.stopName)")
        return response
    }
}
