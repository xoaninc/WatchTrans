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
    func fetchDepartures(stopId: String, routeId: String? = nil, limit: Int = 20) async throws -> [DepartureResponse] {
        isLoading = true
        defer { isLoading = false }

        var urlString = "\(baseURL)/stops/\(stopId)/departures?limit=\(limit)"
        if let routeId = routeId {
            urlString += "&route_id=\(routeId)"
        }

        print("🚉 [DEP] Fetching: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }

        do {
            // DEBUG: Fetch raw data first to see what API returns
            let rawData = try await networkService.fetchData(url)
            let rawString = String(data: rawData, encoding: .utf8) ?? "nil"
            print("🚉 [DEP] 📦 RAW response (\(rawData.count) bytes): \(rawString.prefix(500))")

            // Now decode
            let decoder = JSONDecoder()
            let departures = try decoder.decode([DepartureResponse].self, from: rawData)

            lastFetchTime = Date()
            print("🚉 [DEP] ✅ Got \(departures.count) departures for \(stopId)")

            // Debug: show first 3 departures
            for (i, dep) in departures.prefix(3).enumerated() {
                let platformInfo = dep.platform.map { "vía \($0)\(dep.platformEstimated == true ? "?" : "")" } ?? ""
                print("🚉 [DEP]   [\(i)] \(dep.routeShortName) → \(dep.headsign ?? "?") in \(dep.minutesUntil)min \(platformInfo) (freq:\(dep.frequencyBased ?? false))")
            }

            return departures
        } catch {
            print("🚉 [DEP] ❌ FAILED for \(stopId): \(error)")
            throw error
        }
    }

    // MARK: - ETAs (Enhanced arrival times with delay info)

    /// Fetch ETAs for a stop with delay information
    func fetchETAs(stopId: String, limit: Int = 10) async throws -> [ETAResponse] {
        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: "\(baseURL)/eta/stops/\(stopId)?limit=\(limit)") else {
            throw NetworkError.badResponse
        }

        do {
            let etas: [ETAResponse] = try await networkService.fetch(url)
            lastFetchTime = Date()
            print("✅ [RenfeServer] Fetched \(etas.count) ETAs for stop \(stopId)")
            return etas
        } catch {
            print("⚠️ [RenfeServer] Failed to fetch ETAs: \(error)")
            throw error
        }
    }

    /// Fetch ETA for a specific trip at a stop
    func fetchETA(tripId: String, stopId: String) async throws -> ETAResponse {
        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: "\(baseURL)/eta/trips/\(tripId)/stops/\(stopId)") else {
            throw NetworkError.badResponse
        }

        let eta: ETAResponse = try await networkService.fetch(url)
        lastFetchTime = Date()
        return eta
    }

    // MARK: - Delays

    /// Fetch delays for a specific stop
    func fetchDelays(stopId: String) async throws -> [StopDelayResponse] {
        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: "\(baseURL)/realtime/stops/\(stopId)/delays") else {
            throw NetworkError.badResponse
        }

        do {
            let delays: [StopDelayResponse] = try await networkService.fetch(url)
            lastFetchTime = Date()
            return delays
        } catch {
            print("⚠️ [RenfeServer] Failed to fetch delays: \(error)")
            throw error
        }
    }

    /// Fetch all trip delays (optionally filtered by minimum delay)
    func fetchTripDelays(minDelay: Int? = nil, tripId: String? = nil) async throws -> [TripUpdateResponse] {
        isLoading = true
        defer { isLoading = false }

        var urlString = "\(baseURL)/realtime/delays"
        var queryParams: [String] = []

        if let minDelay = minDelay {
            queryParams.append("min_delay=\(minDelay)")
        }
        if let tripId = tripId {
            queryParams.append("trip_id=\(tripId)")
        }

        if !queryParams.isEmpty {
            urlString += "?" + queryParams.joined(separator: "&")
        }

        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }

        let delays: [TripUpdateResponse] = try await networkService.fetch(url)
        lastFetchTime = Date()
        return delays
    }

    // MARK: - Vehicle Positions

    /// Fetch vehicle positions
    func fetchVehiclePositions(stopId: String? = nil, tripId: String? = nil) async throws -> [VehiclePositionResponse] {
        isLoading = true
        defer { isLoading = false }

        var urlString = "\(baseURL)/realtime/vehicles"
        var queryParams: [String] = []

        if let stopId = stopId {
            queryParams.append("stop_id=\(stopId)")
        }
        if let tripId = tripId {
            queryParams.append("trip_id=\(tripId)")
        }

        if !queryParams.isEmpty {
            urlString += "?" + queryParams.joined(separator: "&")
        }

        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }

        let positions: [VehiclePositionResponse] = try await networkService.fetch(url)
        lastFetchTime = Date()
        return positions
    }

    /// Fetch position for a specific vehicle
    func fetchVehiclePosition(vehicleId: String) async throws -> VehiclePositionResponse {
        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: "\(baseURL)/realtime/vehicles/\(vehicleId)") else {
            throw NetworkError.badResponse
        }

        let position: VehiclePositionResponse = try await networkService.fetch(url)
        lastFetchTime = Date()
        return position
    }

    // MARK: - Networks & Routes

    /// Fetch all networks (Madrid, Sevilla, Barcelona, etc.)
    func fetchNetworks() async throws -> [NetworkResponse] {
        guard let url = URL(string: "\(baseURL)/networks") else {
            throw NetworkError.badResponse
        }

        let networks: [NetworkResponse] = try await networkService.fetch(url)
        return networks
    }

    /// Fetch network details with lines
    func fetchNetwork(code: String) async throws -> NetworkDetailResponse {
        guard let url = URL(string: "\(baseURL)/networks/\(code)") else {
            throw NetworkError.badResponse
        }

        let network: NetworkDetailResponse = try await networkService.fetch(url)
        return network
    }

    /// Fetch lines for a network
    func fetchNetworkLines(code: String) async throws -> [LineResponse] {
        guard let url = URL(string: "\(baseURL)/networks/\(code)/lines") else {
            throw NetworkError.badResponse
        }

        let lines: [LineResponse] = try await networkService.fetch(url)
        return lines
    }

    // MARK: - Routes & Stops

    /// Fetch all routes
    func fetchRoutes(agencyId: String? = nil, search: String? = nil) async throws -> [RouteResponse] {
        var urlString = "\(baseURL)/routes"
        var queryParams: [String] = []

        if let agencyId = agencyId {
            queryParams.append("agency_id=\(agencyId)")
        }
        if let search = search {
            queryParams.append("search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)")
        }

        if !queryParams.isEmpty {
            urlString += "?" + queryParams.joined(separator: "&")
        }

        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }

        let routes: [RouteResponse] = try await networkService.fetch(url)
        return routes
    }

    /// Fetch a specific route
    func fetchRoute(routeId: String) async throws -> RouteResponse {
        guard let url = URL(string: "\(baseURL)/routes/\(routeId)") else {
            throw NetworkError.badResponse
        }

        let route: RouteResponse = try await networkService.fetch(url)
        return route
    }

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
        print("📅 [FREQ] Fetching: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }

        // First fetch raw data to debug if decoding fails
        let data = try await networkService.fetchData(url)

        // Log raw JSON first (always, for debugging)
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📅 [FREQ] Raw JSON (first 300 chars): \(String(jsonString.prefix(300)))")
        }

        // Try to decode
        let decoder = JSONDecoder()
        do {
            let frequencies = try decoder.decode([FrequencyResponse].self, from: data)
            print("📅 [FREQ] ✅ Decoded \(frequencies.count) entries for \(routeId)")

            // Debug: print all day types and time ranges
            let byDayType = Dictionary(grouping: frequencies, by: { $0.dayType })
            for (dayType, freqs) in byDayType {
                let starts = freqs.map { $0.startTime }.sorted()
                let ends = freqs.map { $0.endTime }.sorted()
                print("📅 [FREQ]   \(dayType): \(freqs.count) entries, \(starts.first ?? "?") - \(ends.last ?? "?")")
            }

            return frequencies
        } catch {
            print("📅 [FREQ] ❌ Decode FAILED: \(error)")
            throw NetworkError.decodingError(error)
        }
    }

    /// Fetch operating hours for a route (Cercanías - schedule-based from stop_times)
    func fetchRouteOperatingHours(routeId: String) async throws -> RouteOperatingHoursResponse {
        guard let url = URL(string: "\(baseURL)/routes/\(routeId)/operating-hours") else {
            throw NetworkError.badResponse
        }

        print("📅 [RenfeServer] Calling: \(url.absoluteString)")
        let hours: RouteOperatingHoursResponse = try await networkService.fetch(url)
        print("📅 [RenfeServer] Operating hours for \(hours.routeShortName):")
        if let wd = hours.weekday {
            print("   📅 weekday: \(wd.firstDeparture) - \(wd.lastDeparture) (\(wd.totalTrips) trips)")
        }
        if let sat = hours.saturday {
            print("   📅 saturday: \(sat.firstDeparture) - \(sat.lastDeparture) (\(sat.totalTrips) trips)")
        }
        if let sun = hours.sunday {
            print("   📅 sunday: \(sun.firstDeparture) - \(sun.lastDeparture) (\(sun.totalTrips) trips)")
        }
        return hours
    }

    /// Fetch stops (with optional filters)
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

    /// Fetch a specific stop
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

    // MARK: - Coordinate-based Location Detection (NEW API)

    /// Fetch stops by coordinates - uses Haversine distance calculation
    /// Returns all stops within radius_km, ordered by distance
    func fetchStopsByCoordinates(latitude: Double, longitude: Double, radiusKm: Int = 50, limit: Int = 600) async throws -> [StopResponse] {
        let urlString = "\(baseURL)/stops/by-coordinates?lat=\(latitude)&lon=\(longitude)&radius_km=\(radiusKm)&limit=\(limit)"
        print("📍 [COORD] Fetching stops: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }

        let stops: [StopResponse] = try await networkService.fetch(url)
        print("📍 [COORD] ✅ Got \(stops.count) stops for coordinates (\(latitude), \(longitude))")
        return stops
    }

    /// Fetch routes by coordinates - uses PostGIS province detection
    /// Returns all routes in the detected province's transport networks
    func fetchRoutesByCoordinates(latitude: Double, longitude: Double, limit: Int = 600) async throws -> [RouteResponse] {
        let urlString = "\(baseURL)/coordinates/routes?lat=\(latitude)&lon=\(longitude)&limit=\(limit)"
        print("📍 [COORD] Fetching routes: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }

        let routes: [RouteResponse] = try await networkService.fetch(url)
        print("📍 [COORD] ✅ Got \(routes.count) routes for coordinates (\(latitude), \(longitude))")
        return routes
    }

    // MARK: - Networks

    /// Fetch all networks
    func fetchAllNetworks() async throws -> [NetworkResponse] {
        guard let url = URL(string: "\(baseURL)/networks") else {
            throw NetworkError.badResponse
        }

        let networks: [NetworkResponse] = try await networkService.fetch(url)
        print("🌐 [NET] Fetched \(networks.count) networks")
        return networks
    }

    /// Fetch network details with lines
    func fetchNetworkDetails(code: String) async throws -> NetworkDetailResponse {
        guard let url = URL(string: "\(baseURL)/networks/\(code)") else {
            throw NetworkError.badResponse
        }

        let network: NetworkDetailResponse = try await networkService.fetch(url)
        return network
    }

    // MARK: - Nucleos (DEPRECATED - use coordinate-based methods)

    /// Fetch all nucleos (with bounding boxes for location detection)
    /// NOTE: This endpoint is being deprecated. Use fetchStopsByCoordinates instead.
    @available(*, deprecated, message: "Use fetchStopsByCoordinates instead")
    func fetchNucleos() async throws -> [NucleoResponse] {
        guard let url = URL(string: "\(baseURL)/nucleos") else {
            throw NetworkError.badResponse
        }

        let nucleos: [NucleoResponse] = try await networkService.fetch(url)
        return nucleos
    }

    /// Fetch a specific nucleo
    @available(*, deprecated, message: "Use fetchNetworkDetails instead")
    func fetchNucleo(nucleoId: Int) async throws -> NucleoResponse {
        guard let url = URL(string: "\(baseURL)/nucleos/\(nucleoId)") else {
            throw NetworkError.badResponse
        }

        let nucleo: NucleoResponse = try await networkService.fetch(url)
        return nucleo
    }

    /// Fetch stops by network ID
    func fetchStopsByNetwork(networkId: String, limit: Int = 500) async throws -> [StopResponse] {
        guard let url = URL(string: "\(baseURL)/stops/by-network?network_id=\(networkId)&limit=\(limit)") else {
            throw NetworkError.badResponse
        }

        let stops: [StopResponse] = try await networkService.fetch(url)
        print("📍 [NET] Fetched \(stops.count) stops for network \(networkId)")
        return stops
    }

    /// Fetch stops by nucleo name (DEPRECATED - use fetchStopsByNetwork)
    @available(*, deprecated, message: "Use fetchStopsByNetwork instead")
    func fetchStopsByNucleo(nucleoName: String, limit: Int = 500) async throws -> [StopResponse] {
        let encodedName = nucleoName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? nucleoName
        guard let url = URL(string: "\(baseURL)/stops?search=\(encodedName)&limit=\(limit)") else {
            throw NetworkError.badResponse
        }

        let stops: [StopResponse] = try await networkService.fetch(url)
        return stops
    }

    /// Fetch routes by network ID
    func fetchRoutesByNetwork(networkId: String) async throws -> [RouteResponse] {
        guard let url = URL(string: "\(baseURL)/routes?network_id=\(networkId)") else {
            throw NetworkError.badResponse
        }

        let routes: [RouteResponse] = try await networkService.fetch(url)
        return routes
    }

    /// Fetch routes by nucleo name (DEPRECATED - may not work after migration)
    @available(*, deprecated, message: "Use fetchRoutesByNetwork or fetchRoutesByCoordinates instead")
    func fetchRoutesByNucleo(nucleoName: String) async throws -> [RouteResponse] {
        let encodedName = nucleoName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? nucleoName
        guard let url = URL(string: "\(baseURL)/routes?nucleo_name=\(encodedName)") else {
            throw NetworkError.badResponse
        }

        let routes: [RouteResponse] = try await networkService.fetch(url)
        return routes
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

    /// Fetch alerts for a specific stop
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

    /// Fetch estimated train positions (all)
    func fetchEstimatedPositions(limit: Int = 100) async throws -> [EstimatedPositionResponse] {
        guard let url = URL(string: "\(baseURL)/realtime/estimated?limit=\(limit)") else {
            throw NetworkError.badResponse
        }

        let positions: [EstimatedPositionResponse] = try await networkService.fetch(url)
        return positions
    }

    /// Fetch estimated positions for a network
    func fetchEstimatedPositionsForNetwork(networkId: String) async throws -> [EstimatedPositionResponse] {
        guard let url = URL(string: "\(baseURL)/realtime/networks/\(networkId)/estimated") else {
            throw NetworkError.badResponse
        }

        let positions: [EstimatedPositionResponse] = try await networkService.fetch(url)
        print("📍 [RT] Fetched \(positions.count) estimated positions for network \(networkId)")
        return positions
    }

    /// Fetch estimated positions for a nucleo (DEPRECATED - use fetchEstimatedPositionsForNetwork)
    @available(*, deprecated, message: "Use fetchEstimatedPositionsForNetwork instead")
    func fetchEstimatedPositionsForNucleo(nucleoId: Int) async throws -> [EstimatedPositionResponse] {
        guard let url = URL(string: "\(baseURL)/realtime/nucleos/\(nucleoId)/estimated") else {
            throw NetworkError.badResponse
        }

        let positions: [EstimatedPositionResponse] = try await networkService.fetch(url)
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

    // MARK: - Trigger Realtime Fetch

    /// Trigger a fetch of realtime data from Renfe API
    /// This tells the server to refresh its cache
    func triggerRealtimeFetch() async throws {
        guard let url = URL(string: "\(baseURL)/realtime/fetch") else {
            throw NetworkError.badResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.badResponse
        }

        print("✅ [RenfeServer] Triggered realtime data fetch")
    }
}

// MARK: - Legacy Compatibility

extension GTFSRealtimeService {
    /// Legacy method for compatibility with existing code
    /// Converts DepartureResponse to the format expected by the mapper
    @available(*, deprecated, message: "Use fetchDepartures directly")
    func fetchTripUpdates() async throws -> GTFSRealtimeFeed {
        // This would require the old Renfe API format
        // For now, throw an error to indicate migration is needed
        throw NetworkError.badResponse
    }

    @available(*, deprecated, message: "Use fetchDepartures directly")
    func fetchTripUpdates(for stopId: String) async throws -> GTFSRealtimeFeed {
        throw NetworkError.badResponse
    }
}
