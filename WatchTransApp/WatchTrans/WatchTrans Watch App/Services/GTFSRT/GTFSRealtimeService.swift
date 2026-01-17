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

        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }

        do {
            let departures: [DepartureResponse] = try await networkService.fetch(url)
            lastFetchTime = Date()
            print("✅ [RenfeServer] Fetched \(departures.count) departures for stop \(stopId)")
            return departures
        } catch {
            print("⚠️ [RenfeServer] Failed to fetch departures: \(error)")
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

    /// Fetch stops by coordinates (returns all stops in the province)
    func fetchStopsByCoordinates(latitude: Double, longitude: Double, limit: Int = 100) async throws -> [StopResponse] {
        let urlString = "\(baseURL)/stops/by-coordinates?lat=\(latitude)&lon=\(longitude)&limit=\(limit)"

        guard let url = URL(string: urlString) else {
            throw NetworkError.badResponse
        }

        let stops: [StopResponse] = try await networkService.fetch(url)
        print("✅ [RenfeServer] Fetched \(stops.count) stops for coordinates (\(latitude), \(longitude))")
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

    // MARK: - Nucleos

    /// Fetch all nucleos (with bounding boxes for location detection)
    func fetchNucleos() async throws -> [NucleoResponse] {
        guard let url = URL(string: "\(baseURL)/nucleos") else {
            throw NetworkError.badResponse
        }

        let nucleos: [NucleoResponse] = try await networkService.fetch(url)
        return nucleos
    }

    /// Fetch a specific nucleo
    func fetchNucleo(nucleoId: Int) async throws -> NucleoResponse {
        guard let url = URL(string: "\(baseURL)/nucleos/\(nucleoId)") else {
            throw NetworkError.badResponse
        }

        let nucleo: NucleoResponse = try await networkService.fetch(url)
        return nucleo
    }

    /// Fetch stops by nucleo name
    func fetchStopsByNucleo(nucleoName: String, limit: Int = 500) async throws -> [StopResponse] {
        let encodedName = nucleoName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? nucleoName
        guard let url = URL(string: "\(baseURL)/stops/by-nucleo?nucleo_name=\(encodedName)&limit=\(limit)") else {
            throw NetworkError.badResponse
        }

        let stops: [StopResponse] = try await networkService.fetch(url)
        return stops
    }

    /// Fetch routes by nucleo name
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
        return alerts.filter { $0.isActive }
    }

    /// Fetch alerts for a specific stop
    func fetchAlertsForStop(stopId: String) async throws -> [AlertResponse] {
        guard let url = URL(string: "\(baseURL)/realtime/stops/\(stopId)/alerts") else {
            throw NetworkError.badResponse
        }

        let alerts: [AlertResponse] = try await networkService.fetch(url)
        return alerts.filter { $0.isActive }
    }

    /// Fetch alerts for a specific route
    func fetchAlertsForRoute(routeId: String) async throws -> [AlertResponse] {
        guard let url = URL(string: "\(baseURL)/realtime/routes/\(routeId)/alerts") else {
            throw NetworkError.badResponse
        }

        let alerts: [AlertResponse] = try await networkService.fetch(url)
        return alerts.filter { $0.isActive }
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

    /// Fetch estimated positions for a nucleo
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
