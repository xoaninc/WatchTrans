//
//  GTFSRealtimeService.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//  Updated on 16/1/26 to use WatchTrans API (api.watch-trans.app)
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

    /// Fetch route detail (service_status, suspended_since, is_alternative_service)
    func fetchRouteDetail(routeId: String) async throws -> RouteResponse {
        guard let url = URL(string: "\(baseURL)/routes/\(routeId)") else {
            throw NetworkError.badResponse
        }
        return try await networkService.fetch(url)
    }

    /// Fetch stops for a route
    func fetchRouteStops(routeId: String) async throws -> [StopResponse] {
        guard let url = URL(string: "\(baseURL)/routes/\(routeId)/stops") else {
            throw NetworkError.badResponse
        }

        let stops: [StopResponse] = try await networkService.fetch(url)
        if stops.contains(where: { $0.sequence != nil }) {
            return stops.sorted { ($0.sequence ?? 0) < ($1.sequence ?? 0) }
        }
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

        DebugLog.log("📅 [API] Calling: \(url.absoluteString)")
        let hours: RouteOperatingHoursResponse = try await networkService.fetch(url)
        DebugLog.log("📅 [API] Operating hours for \(hours.routeShortName):")
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
        guard var components = URLComponents(string: "\(baseURL)/stops") else {
            throw NetworkError.badResponse
        }

        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]

        if let search = search {
            components.queryItems?.append(URLQueryItem(name: "search", value: search))
        }
        if let locationType = locationType {
            components.queryItems?.append(URLQueryItem(name: "location_type", value: String(locationType)))
        }

        guard let url = components.url else {
            throw NetworkError.badResponse
        }

        let stops: [StopResponse] = try await networkService.fetch(url)
        return stops
    }

    /// Fetch a single stop details by ID
    func fetchStop(stopId: String) async throws -> StopResponse {
        guard let url = URL(string: "\(baseURL)/stops/\(stopId)") else {
            throw NetworkError.badResponse
        }
        
        let stop: StopResponse = try await networkService.fetch(url)
        return stop
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

    /// Fetch stops by coordinates - uses PostGIS ST_DWithin calculation
    /// Returns all stops within radius (meters), ordered by distance
    func fetchStopsByCoordinates(latitude: Double, longitude: Double, radius: Int = 5000, limit: Int = 100) async throws -> [StopResponse] {
        guard var components = URLComponents(string: "\(baseURL)/stops/by-coordinates") else {
            throw NetworkError.badResponse
        }
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "radius", value: String(radius)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        guard let url = components.url else {
            throw NetworkError.badResponse
        }

        let stops: [StopResponse] = try await networkService.fetch(url)
        DebugLog.log("📍 [COORD] ✅ Got \(stops.count) stops for coordinates (\(latitude), \(longitude))")
        return stops
    }

    /// Fetch routes by coordinates - uses PostGIS proximity detection
    /// Returns all routes in the detected location's transport networks
    func fetchRoutesByCoordinates(latitude: Double, longitude: Double, radius: Int = 5000, limit: Int = 100) async throws -> [RouteResponse] {
        guard var components = URLComponents(string: "\(baseURL)/coordinates/routes") else {
            throw NetworkError.badResponse
        }
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "radius", value: String(radius)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        guard let url = components.url else {
            throw NetworkError.badResponse
        }

        let routes: [RouteResponse] = try await networkService.fetch(url)
        DebugLog.log("📍 [COORD] ✅ Got \(routes.count) routes for coordinates (\(latitude), \(longitude))")
        return routes
    }

    /// Fetch province info by coordinates with optional routes
    /// - Parameters:
    ///   - latitude: User latitude
    ///   - longitude: User longitude
    ///   - includeNetworks: Include network list in response
    ///   - includeRoutes: Include ALL routes from detected networks (NEW)
    func fetchProvinceByCoordinates(
        latitude: Double,
        longitude: Double,
        includeNetworks: Bool = true,
        includeRoutes: Bool = false
    ) async throws -> Data {
        guard var components = URLComponents(string: "\(baseURL)/province-by-coordinates") else {
            throw NetworkError.badResponse
        }
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude))
        ]
        if includeNetworks {
            components.queryItems?.append(URLQueryItem(name: "include_networks", value: "true"))
        }
        if includeRoutes {
            components.queryItems?.append(URLQueryItem(name: "include_routes", value: "true"))
        }

        guard let url = components.url else {
            throw NetworkError.badResponse
        }
        return try await networkService.fetchData(url)
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

    /// Fetch all routes for a specific province (e.g. "Sevilla")
    func fetchProvinceRoutes(provinceName: String) async throws -> [RouteResponse] {
        // Updated for Week 3 API changes: /api/gtfs/province/{province}/routes
        // Handles URL encoding for province names with spaces or special chars
        guard let encodedProvince = provinceName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/province/\(encodedProvince)/routes") else {
            throw NetworkError.badResponse
        }

        DebugLog.log("🌐 [RT] Fetching ALL routes for province: \(provinceName)")
        let routes: [RouteResponse] = try await networkService.fetch(url)
        DebugLog.log("🌐 [RT] ✅ Got \(routes.count) routes for \(provinceName)")
        return routes
    }

    /// Fetch all lines for a specific network (e.g. "30T")
    /// Returns ALL lines, not just nearby ones.
    func fetchNetworkLines(networkId: String) async throws -> [LineResponse] {
        guard let url = URL(string: "\(baseURL)/networks/\(networkId)/lines") else {
            throw NetworkError.badResponse
        }

        DebugLog.log("🌐 [RT] Fetching ALL lines for network: \(networkId)")
        let lines: [LineResponse] = try await networkService.fetch(url)
        DebugLog.log("🌐 [RT] ✅ Got \(lines.count) lines for \(networkId)")
        return lines
    }

    // MARK: - GPS & Nearby (Week 3 New Features)

    /// Fetch stops near coordinates sorted by distance (PostGIS)
    /// - Parameters:
    ///   - latitude: User latitude
    ///   - longitude: User longitude
    ///   - limit: Max number of stops (default 20)
    func fetchNearbyStops(latitude: Double, longitude: Double, limit: Int = 20) async throws -> [StopResponse] {
        guard let url = URL(string: "\(baseURL)/stops/by-coordinates?lat=\(latitude)&lon=\(longitude)&limit=\(limit)") else {
            throw NetworkError.badResponse
        }

        DebugLog.log("📍 [RT] Fetching nearby stops (GPS): \(latitude),\(longitude)")
        let stops: [StopResponse] = try await networkService.fetch(url)
        DebugLog.log("📍 [RT] ✅ Got \(stops.count) nearby stops")
        return stops
    }

    /// Fetch ALL routes near coordinates (same province) sorted by distance
    /// - Parameters:
    ///   - latitude: User latitude
    ///   - longitude: User longitude
    func fetchNearbyRoutes(latitude: Double, longitude: Double) async throws -> [RouteResponse] {
        guard let url = URL(string: "\(baseURL)/coordinates/routes?lat=\(latitude)&lon=\(longitude)") else {
            throw NetworkError.badResponse
        }

        DebugLog.log("📍 [RT] Fetching nearby routes (GPS): \(latitude),\(longitude)")
        let routes: [RouteResponse] = try await networkService.fetch(url)
        DebugLog.log("📍 [RT] ✅ Got \(routes.count) nearby routes")
        return routes
    }

    // MARK: - Alerts

    /// Fetch all active alerts from new GTFS-RT server
    func fetchAlerts() async throws -> [AlertResponse] {
        guard let url = URL(string: "\(APIConfiguration.gtfsRTBaseURL)/alerts?active_only=true") else {
            throw NetworkError.badResponse
        }

        DebugLog.log("⚠️ [RT] Fetching alerts from NEW server: \(url.absoluteString)")
        
        let rawData = try await networkService.fetchData(url)
        let decoder = JSONDecoder()
        let alerts = try decoder.decode([AlertResponse].self, from: rawData)
        
        DebugLog.log("⚠️ [RT] Got \(alerts.count) active alerts")
        return alerts
    }

    // MARK: - GTFS-RT Extras (New Endpoints)

    /// Fetch realtime stats from GTFS-RT server
    func fetchRealtimeStats() async throws -> Data {
        guard let url = URL(string: "\(APIConfiguration.gtfsRTBaseURL)/stats") else {
            throw NetworkError.badResponse
        }
        DebugLog.log("📊 [RT] Fetching stats: \(url.absoluteString)")
        return try await networkService.fetchData(url)
    }

    /// Fetch realtime trip updates (raw payload)
    func fetchTripUpdates(operatorId: String, routeId: String? = nil, minDelay: Int? = nil, limit: Int? = nil, enrich: Bool = true) async throws -> Data {
        guard var components = URLComponents(string: "\(APIConfiguration.gtfsRTBaseURL)/trip-updates") else {
            throw NetworkError.badResponse
        }
        
        components.queryItems = [URLQueryItem(name: "operator_id", value: operatorId)]
        if let routeId = routeId { components.queryItems?.append(URLQueryItem(name: "route_id", value: routeId)) }
        if let minDelay = minDelay { components.queryItems?.append(URLQueryItem(name: "min_delay", value: String(minDelay))) }
        if let limit = limit { components.queryItems?.append(URLQueryItem(name: "limit", value: String(limit))) }
        if enrich { components.queryItems?.append(URLQueryItem(name: "enrich", value: "true")) }

        guard let url = components.url else {
            throw NetworkError.badResponse
        }
        DebugLog.log("🛰️ [RT] Fetching trip updates: \(url.absoluteString)")
        return try await networkService.fetchData(url)
    }

    /// Fetch a specific vehicle by ID (raw payload)
    func fetchVehicleById(vehicleId: String, operatorId: String) async throws -> Data {
        let urlString = "\(APIConfiguration.gtfsRTBaseURL)/vehicles/\(vehicleId)?operator_id=\(operatorId)"
        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }
        DebugLog.log("🚆 [RT] Fetching vehicle: \(urlString)")
        return try await networkService.fetchData(url)
    }

    /// Trigger GTFS-RT fetch for an operator (admin action)
    func triggerRealtimeFetch(operatorId: String) async throws -> Data {
        guard let url = URL(string: "\(APIConfiguration.gtfsRTBaseURL)/fetch/\(operatorId)") else {
            throw NetworkError.badResponse
        }
        DebugLog.log("🔁 [RT] Trigger fetch: \(url.absoluteString)")
        return try await networkService.postData(url)
    }

    /// Trigger GTFS-RT cleanup (admin action)
    func triggerRealtimeCleanup() async throws -> Data {
        guard let url = URL(string: "\(APIConfiguration.gtfsRTBaseURL)/cleanup") else {
            throw NetworkError.badResponse
        }
        DebugLog.log("🧹 [RT] Trigger cleanup: \(url.absoluteString)")
        return try await networkService.postData(url)
    }

    /// Fetch alerts for a specific stop (filtered by server)
    func fetchAlertsForStop(stopId: String) async throws -> [AlertResponse] {
        guard var components = URLComponents(string: "\(APIConfiguration.gtfsRTBaseURL)/alerts") else {
            throw NetworkError.badResponse
        }
        
        components.queryItems = [
            URLQueryItem(name: "stop_id", value: stopId),
            URLQueryItem(name: "active_only", value: "true")
        ]
        
        guard let url = components.url else {
            throw NetworkError.badResponse
        }
        
        DebugLog.log("⚠️ [RT] Fetching alerts for stop: \(stopId)")
        
        let rawData = try await networkService.fetchData(url)
        let decoder = JSONDecoder()
        let alerts = try decoder.decode([AlertResponse].self, from: rawData)
        
        DebugLog.log("⚠️ [RT] Got \(alerts.count) alerts for stop \(stopId)")
        return alerts
    }

    /// Fetch alerts for a specific route (filtered by server)
    func fetchAlertsForRoute(routeId: String) async throws -> [AlertResponse] {
        guard var components = URLComponents(string: "\(APIConfiguration.gtfsRTBaseURL)/alerts") else {
            throw NetworkError.badResponse
        }
        
        components.queryItems = [
            URLQueryItem(name: "route_id", value: routeId),
            URLQueryItem(name: "active_only", value: "true")
        ]
        
        guard let url = components.url else {
            throw NetworkError.badResponse
        }
        
        DebugLog.log("⚠️ [RT] Fetching alerts for route: \(routeId)")
        
        let rawData = try await networkService.fetchData(url)
        let decoder = JSONDecoder()
        let alerts = try decoder.decode([AlertResponse].self, from: rawData)
        
        DebugLog.log("⚠️ [RT] Got \(alerts.count) alerts for route \(routeId)")
        return alerts
    }

    // MARK: - Estimated Positions (Vehicle Positions)

    /// Fetch vehicle positions for a network from new GTFS-RT server
    /// NOW USES ADAPTER to convert new format to EstimatedPositionResponse
    func fetchEstimatedPositionsForNetwork(networkId: String) async throws -> [EstimatedPositionResponse] {
        let operatorId = mapNetworkToOperator(networkId: networkId)
        
        // Use new adapter method
        return try await fetchVehiclePositionsConverted(operatorId: operatorId)
    }

    /// Fetch vehicle positions for a route
    func fetchEstimatedPositionsForRoute(routeId: String) async throws -> [EstimatedPositionResponse] {
        // Extract operator from route_id (e.g., "FGC_S1" → "fgc")
        let operatorId = routeId.split(separator: "_").first?.lowercased() ?? "fgc"
        
        // Fetch all vehicles for operator
        let allVehicles = try await fetchVehiclePositionsConverted(operatorId: operatorId)
        
        // Filter by route_id
        let filtered = allVehicles.filter { $0.routeId == routeId }
        DebugLog.log("📍 [RT] Filtered \(filtered.count)/\(allVehicles.count) vehicles for route \(routeId)")
        
        return filtered
    }
    
    /// Map network ID to operator ID for new GTFS-RT API
    /// Map network code to operator ID for vehicles API
    /// UPDATED: Now uses generic mapping based on prefixes to avoid hardcoding cities
    private func mapNetworkToOperator(networkId: String) -> String {
        // Generic cleanup: "10T" -> "renfe", "METRO_SEVILLA" -> "metro_sevilla"
        let lower = networkId.lowercased()
        
        // Renfe Cercanías codes usually end in 't' (10T, 30T...)
        if lower.hasSuffix("t") && lower.dropLast().allSatisfy({ $0.isNumber }) {
            return "renfe"
        }
        
        // For others, use the ID as is (e.g., "TUSSAM", "METRO_SEVILLA", "FGC")
        return lower
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

    /// Fetch predicted platforms for a stop based on 30-day historical data
    func fetchPlatformPredictions(stopId: String, minConfidence: Double = 0.5) async throws -> [PlatformPredictionResponse] {
        guard var components = URLComponents(string: "\(APIConfiguration.gtfsRTBaseURL)/platforms/predictions") else {
            throw NetworkError.badResponse
        }

        components.queryItems = [
            URLQueryItem(name: "stop_id", value: stopId),
            URLQueryItem(name: "min_confidence", value: String(minConfidence))
        ]

        guard let url = components.url else {
            throw NetworkError.badResponse
        }

        let predictions: [PlatformPredictionResponse] = try await networkService.fetch(url)
        DebugLog.log("🔮 [RT] Fetched \(predictions.count) platform predictions for \(stopId)")
        return predictions
    }

    /// Fetch station-level occupancy for TMB Metro stops
    func fetchStationOccupancy(stopIds: [String]) async throws -> [StationOccupancyResponse] {
        guard var components = URLComponents(string: "\(APIConfiguration.gtfsRTBaseURL)/station-occupancy") else {
            throw NetworkError.badResponse
        }

        components.queryItems = [
            URLQueryItem(name: "stop_ids", value: stopIds.joined(separator: ","))
        ]

        guard let url = components.url else {
            throw NetworkError.badResponse
        }

        let response: [StationOccupancyResponse] = try await networkService.fetch(url)
        DebugLog.log("🏢 [RT] Fetched \(response.count) station occupancy records")
        return response
    }

    /// Fetch all RT data for a stop in one call (departures + alerts)
    func fetchStopRealtime(stopId: String, limit: Int = 20) async throws -> StopRealtimeResponse {
        guard var components = URLComponents(string: "\(APIConfiguration.gtfsRTBaseURL)/stops/\(stopId)/realtime") else {
            throw NetworkError.badResponse
        }

        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components.url else {
            throw NetworkError.badResponse
        }

        let response: StopRealtimeResponse = try await networkService.fetch(url)
        DebugLog.log("⚡ [RT] Fetched realtime for \(stopId): \(response.upcomingArrivals?.count ?? 0) arrivals, \(response.alerts?.count ?? 0) alerts")
        return response
    }

    /// Fetch station interior: pathways, accesses, vestibules, levels
    func fetchStationInterior(stopId: String) async throws -> StationInteriorResponse {
        guard let url = URL(string: "\(baseURL)/stops/\(stopId)/station-interior") else {
            throw NetworkError.badResponse
        }

        let response: StationInteriorResponse = try await networkService.fetch(url)
        DebugLog.log("🏛️ [RT] Interior for \(stopId): \(response.pathways?.count ?? 0) pathways, \(response.accesses?.count ?? 0) accesses, \(response.levels?.count ?? 0) levels")
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
        let count = response.correspondences?.count ?? 0
        DebugLog.log("🚶 [RT] Fetched \(count) correspondences for \(stopId)\(includeShape ? " (with shapes)" : "")")
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
        guard var components = URLComponents(string: "\(baseURL)/route-planner") else {
            throw NetworkError.badResponse
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let departureTime = formatter.string(from: Date())

        components.queryItems = [
            URLQueryItem(name: "from", value: fromStopId),
            URLQueryItem(name: "to", value: toStopId),
            URLQueryItem(name: "departure_time", value: departureTime)
        ]
        if compact {
            components.queryItems?.append(URLQueryItem(name: "compact", value: "true"))
        }

        guard let url = components.url else {
            throw NetworkError.badResponse
        }

        DebugLog.log("🗺️ [RT] ▶️ ROUTE PLAN REQUEST")
        DebugLog.log("🗺️ [RT]   From: \(fromStopId)")
        DebugLog.log("🗺️ [RT]   To: \(toStopId)")
        DebugLog.log("🗺️ [RT]   Departure: \(departureTime)")
        DebugLog.log("🗺️ [RT]   Compact Mode: \(compact) (Size optimization)")
        DebugLog.log("🗺️ [RT]   URL: \(url.absoluteString)")

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

    /// Fetch route plan for a time range (rRAPTOR)
    /// Returns multiple journey alternatives across the specified time window
    func fetchRoutePlanRange(fromStopId: String, toStopId: String, startTime: String, endTime: String, interval: Int = 15) async throws -> RoutePlanResponse {
        guard var components = URLComponents(string: "\(baseURL)/route-planner/range") else {
            throw NetworkError.badResponse
        }

        components.queryItems = [
            URLQueryItem(name: "from", value: fromStopId),
            URLQueryItem(name: "to", value: toStopId),
            URLQueryItem(name: "start_time", value: startTime),
            URLQueryItem(name: "end_time", value: endTime),
            URLQueryItem(name: "interval", value: String(interval))
        ]

        guard let url = components.url else {
            throw NetworkError.badResponse
        }

        DebugLog.log("🗺️ [RT] ▶️ ROUTE PLAN RANGE: \(startTime)-\(endTime)")

        let response: RoutePlanResponse = try await networkService.fetch(url)

        DebugLog.log("🗺️ [RT] ✅ Range search: \(response.allJourneys.count) journeys")
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
    
    // MARK: - Equipment Status

    /// Fetch elevator/escalator status for a station (Metro Sevilla)
    func fetchEquipmentStatus(stopId: String) async throws -> [EquipmentStatusResponse] {
        guard let url = URL(string: "\(APIConfiguration.gtfsRTBaseURL)/equipment-status/\(stopId)") else {
            throw NetworkError.badResponse
        }

        let response: [EquipmentStatusResponse] = try await networkService.fetch(url)
        DebugLog.log("🛗 [RT] Fetched \(response.count) equipment devices for \(stopId)")
        for device in response {
            DebugLog.log("🛗 [RT]   \(device.deviceId ?? "?") \(device.deviceType ?? "?") operational=\(device.isOperational.map { String($0) } ?? "nil") direction=\(device.direction ?? "nil") isBroken=\(device.isBroken)")
        }
        return response
    }

    // MARK: - Week 3 Optimizations
    
    /// Fetch child stops (platforms) for a parent station
    /// Used for aggregation when parent station departures are incomplete
    func fetchChildren(stopId: String) async throws -> [StopResponse] {
        guard let url = URL(string: "\(baseURL)/stops/\(stopId)/children") else {
            throw NetworkError.badResponse
        }
        
        DebugLog.log("👨‍👧‍👦 [RT] Fetching children for: \(stopId)")
        
        // Define specific response structure for children endpoint
        struct ChildrenResponse: Decodable {
            let children: [StopResponse]
        }
        
        let response: ChildrenResponse = try await networkService.fetch(url)
        DebugLog.log("👨‍👧‍👦 [RT] ✅ Got \(response.children.count) children for \(stopId)")
        return response.children
    }
    
    /// Fetch FULL stop details in a single request (routes, correspondences, platforms, accesses)
    func fetchStopFullDetails(stopId: String) async throws -> StopFullDetailResponse {
        guard let url = URL(string: "\(baseURL)/stops/\(stopId)/full") else {
            throw NetworkError.badResponse
        }
        
        DebugLog.log("🏢 [RT] Fetching FULL details for stop: \(stopId)")
        let response: StopFullDetailResponse = try await networkService.fetch(url)
        DebugLog.log("🏢 [RT] ✅ Got full details for \(response.name) (Hub: \(response.isHub ?? false))")
        return response
    }
}
