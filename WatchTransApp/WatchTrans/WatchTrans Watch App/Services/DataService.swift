//
//  DataService.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//
//  UPDATED: 2026-01-16 - Now loads ALL data from RenfeServer API (redcercanias.com)
//

import Foundation

@Observable
class DataService {
    var lines: [Line] = []
    var stops: [Stop] = []
    var nucleos: [NucleoResponse] = []
    var currentNucleo: NucleoResponse?  // Detected from user's location
    var isLoading = false
    var error: Error?

    // MARK: - GTFS-Realtime Services

    private let networkService = NetworkService()
    private var _gtfsRealtimeService: GTFSRealtimeService?
    private var _gtfsMapper: GTFSRealtimeMapper?

    private var gtfsRealtimeService: GTFSRealtimeService {
        if _gtfsRealtimeService == nil {
            _gtfsRealtimeService = GTFSRealtimeService(networkService: networkService)
        }
        return _gtfsRealtimeService!
    }

    private var gtfsMapper: GTFSRealtimeMapper {
        if _gtfsMapper == nil {
            _gtfsMapper = GTFSRealtimeMapper(dataService: self)
        }
        return _gtfsMapper!
    }

    // MARK: - Arrival Cache

    private struct CacheEntry {
        let arrivals: [Arrival]
        let timestamp: Date

        var isValid: Bool {
            Date().timeIntervalSince(timestamp) < 60  // 60s TTL
        }

        var isStale: Bool {
            Date().timeIntervalSince(timestamp) < 300  // 5 min grace period
        }
    }

    private var arrivalCache: [String: CacheEntry] = [:]
    private let cacheLock = NSLock()

    // MARK: - Public Methods

    /// Fetch all nucleos from API (with bounding boxes for location detection)
    func fetchNucleos() async {
        do {
            print("📡 [DataService] Fetching nucleos from API...")
            nucleos = try await gtfsRealtimeService.fetchNucleos()
            print("✅ [DataService] Loaded \(nucleos.count) nucleos")
        } catch {
            print("⚠️ [DataService] Failed to fetch nucleos: \(error)")
            self.error = error
        }
    }

    /// Detect user's nucleo from coordinates using bounding boxes
    func detectNucleo(latitude: Double, longitude: Double) -> NucleoResponse? {
        return nucleos.first { $0.contains(latitude: latitude, longitude: longitude) }
    }

    /// Initialize data - call this on app launch
    /// Pass coordinates to detect user's nucleo and load relevant data
    func fetchTransportData(latitude: Double? = nil, longitude: Double? = nil) async {
        isLoading = true
        defer { isLoading = false }

        // 1. Fetch nucleos first (for location detection via bounding boxes)
        await fetchNucleos()

        // 2. Detect user's nucleo from coordinates using bounding boxes
        if let lat = latitude, let lon = longitude {
            currentNucleo = detectNucleo(latitude: lat, longitude: lon)
            print("📍 [DataService] Detected nucleo: \(currentNucleo?.name ?? "none") for coords (\(lat), \(lon))")
        }

        // 3. Fetch stops and routes for the detected nucleo
        if let nucleo = currentNucleo {
            await fetchStopsForNucleo(nucleoName: nucleo.name)
            await fetchRoutesForNucleo(nucleoName: nucleo.name)
        } else {
            print("⚠️ [DataService] No nucleo detected - user may be outside Cercanías coverage")
        }

        print("✅ [DataService] Data load complete: \(nucleos.count) nucleos, \(lines.count) lines, \(stops.count) stops")
    }

    /// Fetch stops for a specific route
    func fetchStopsForRoute(routeId: String) async -> [Stop] {
        do {
            let stopResponses = try await gtfsRealtimeService.fetchRouteStops(routeId: routeId)
            return stopResponses.map { response in
                Stop(
                    id: response.id,
                    name: response.name,
                    latitude: response.lat,
                    longitude: response.lon,
                    connectionLineIds: response.lineIds,  // Parse from "lineas" field
                    province: response.province,
                    nucleoName: response.nucleoName,
                    accesibilidad: response.accesibilidad,
                    hasParking: response.parkingBicis != nil && response.parkingBicis != "0",
                    hasBusConnection: response.corBus != nil && response.corBus != "0",
                    hasMetroConnection: response.corMetro != nil && response.corMetro != "0"
                )
            }
        } catch {
            print("⚠️ [DataService] Failed to fetch stops for route \(routeId): \(error)")
            return []
        }
    }

    /// Fetch stops for a specific nucleo
    func fetchStopsForNucleo(nucleoName: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            print("📡 [DataService] Fetching stops for nucleo: \(nucleoName)...")
            let stopResponses = try await gtfsRealtimeService.fetchStopsByNucleo(nucleoName: nucleoName)

            stops = stopResponses.map { response in
                Stop(
                    id: response.id,
                    name: response.name,
                    latitude: response.lat,
                    longitude: response.lon,
                    connectionLineIds: response.lineIds,  // Parse from "lineas" field
                    province: response.province,
                    nucleoName: response.nucleoName,
                    accesibilidad: response.accesibilidad,
                    hasParking: response.parkingBicis != nil && response.parkingBicis != "0",
                    hasBusConnection: response.corBus != nil && response.corBus != "0",
                    hasMetroConnection: response.corMetro != nil && response.corMetro != "0"
                )
            }

            print("✅ [DataService] Loaded \(stops.count) stops for \(nucleoName)")
        } catch {
            print("⚠️ [DataService] Failed to fetch stops for nucleo: \(error)")
            self.error = error
        }
    }

    /// Fetch routes for a specific nucleo
    func fetchRoutesForNucleo(nucleoName: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            print("📡 [DataService] Fetching routes for nucleo: \(nucleoName)...")
            let routeResponses = try await gtfsRealtimeService.fetchRoutesByNucleo(nucleoName: nucleoName)

            // Group routes by short name to create lines, collecting all route IDs
            var lineDict: [String: (line: Line, routeIds: [String], longName: String)] = [:]

            // Get nucleo color for fallback (API returns "R,G,B" format)
            let nucleoColor = currentNucleo.map { nucleo -> String in
                let rgb = nucleo.color.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                if rgb.count == 3 {
                    return String(format: "#%02X%02X%02X", rgb[0], rgb[1], rgb[2])
                }
                return "#75B6E0"
            } ?? "#75B6E0"

            for route in routeResponses {
                // Create unique ID per agency to separate Metro L1 from Cercanías C1
                let transportType = TransportType.from(agencyId: route.agencyId)
                let lineId = "\(route.agencyId)_\(route.shortName.lowercased())"

                if var existing = lineDict[lineId] {
                    // Add route ID to existing line
                    existing.routeIds.append(route.id)
                    lineDict[lineId] = existing
                } else {
                    // Use route color if available, otherwise use nucleo color
                    // API now returns colors with # prefix
                    let color = route.color ?? nucleoColor

                    // Format line name: Metro lines get "L" prefix (except R ramal)
                    let displayName: String
                    if transportType == .metro && route.shortName != "R" {
                        displayName = "L\(route.shortName)"
                    } else {
                        displayName = route.shortName
                    }

                    let line = Line(
                        id: lineId,
                        name: displayName,
                        longName: route.longName,
                        type: transportType,
                        colorHex: color,
                        nucleo: nucleoName,
                        routeIds: [route.id]
                    )
                    lineDict[lineId] = (line: line, routeIds: [route.id], longName: route.longName)
                }
            }

            // Create final lines with all collected route IDs
            lines = lineDict.map { (_, value) in
                Line(
                    id: value.line.id,
                    name: value.line.name,
                    longName: value.longName,
                    type: value.line.type,
                    colorHex: value.line.colorHex,
                    nucleo: value.line.nucleo,
                    routeIds: value.routeIds
                )
            }
            print("✅ [DataService] Loaded \(lines.count) lines for \(nucleoName)")
        } catch {
            print("⚠️ [DataService] Failed to fetch routes for nucleo: \(error)")
            self.error = error
        }
    }

    // Fetch arrivals for a specific stop using RenfeServer API
    func fetchArrivals(for stopId: String) async -> [Arrival] {
        print("🔍 [DataService] Fetching arrivals for stop: \(stopId)")

        // 1. Check cache first
        if let cached = getCachedArrivals(for: stopId) {
            print("✅ [DataService] Cache hit! Returning \(cached.count) cached arrivals")
            return cached
        }

        // 2. Fetch from RenfeServer API (redcercanias.com)
        do {
            print("📡 [DataService] Cache miss, calling RenfeServer API...")
            let departures = try await gtfsRealtimeService.fetchDepartures(stopId: stopId, limit: 10)
            print("📊 [DataService] API returned \(departures.count) departures for stop \(stopId)")

            let arrivals = gtfsMapper.mapToArrivals(departures: departures, stopId: stopId)
            print("✅ [DataService] Mapped to \(arrivals.count) arrivals")

            // 3. Cache results
            cacheArrivals(arrivals, for: stopId)

            return arrivals
        } catch {
            // 4. Handle errors gracefully
            print("⚠️ [DataService] RenfeServer API Error: \(error)")

            // Try stale cache as fallback
            if let stale = getStaleCachedArrivals(for: stopId) {
                print("ℹ️ [DataService] Using stale cached data for stop \(stopId)")
                return stale
            }

            // Return empty array instead of mock data
            print("ℹ️ [DataService] No data available for stop \(stopId)")
            self.error = error
            return []
        }
    }

    // MARK: - Cache Helpers

    private func getCachedArrivals(for stopId: String) -> [Arrival]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        guard let entry = arrivalCache[stopId], entry.isValid else {
            return nil
        }
        return entry.arrivals
    }

    private func cacheArrivals(_ arrivals: [Arrival], for stopId: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        arrivalCache[stopId] = CacheEntry(arrivals: arrivals, timestamp: Date())
    }

    private func getStaleCachedArrivals(for stopId: String) -> [Arrival]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        guard let entry = arrivalCache[stopId], entry.isStale else {
            return nil
        }
        return entry.arrivals
    }

    /// Clear arrival cache (useful for pull-to-refresh)
    func clearArrivalCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        arrivalCache.removeAll()
    }

    // Get stop by ID
    func getStop(by id: String) -> Stop? {
        return stops.first { $0.id == id }
    }

    // Get line by ID or name (case-insensitive)
    // Handles API format variations: "1" -> "L1", "4" -> "L4", "ML1" -> "ML1", "C1" -> "C1"
    func getLine(by id: String) -> Line? {
        let lowerId = id.lowercased().trimmingCharacters(in: .whitespaces)

        // Try exact match first (by ID or name)
        if let exact = lines.first(where: { $0.id.lowercased() == lowerId || $0.name.lowercased() == lowerId }) {
            return exact
        }

        // For Metro: API returns "1", "2", etc. but line names are "L1", "L2"
        // Check if it's a plain number (Metro line)
        if let _ = Int(lowerId) {
            let metroName = "l\(lowerId)"
            if let metro = lines.first(where: { $0.name.lowercased() == metroName && $0.type == .metro }) {
                return metro
            }
        }

        // For Cercanías: try with "c" prefix if not already present
        if !lowerId.hasPrefix("c") && !lowerId.hasPrefix("l") && !lowerId.hasPrefix("ml") {
            let cercaniasName = "c\(lowerId)"
            if let cercanias = lines.first(where: { $0.name.lowercased() == cercaniasName }) {
                return cercanias
            }
        }

        return nil
    }

    /// Search stops by name
    func searchStops(query: String) async -> [Stop] {
        do {
            let stopResponses = try await gtfsRealtimeService.fetchStops(search: query, limit: 50)
            return stopResponses.map { response in
                Stop(
                    id: response.id,
                    name: response.name,
                    latitude: response.lat,
                    longitude: response.lon,
                    connectionLineIds: response.lineIds,  // Parse from "lineas" field
                    province: response.province,
                    nucleoName: response.nucleoName,
                    accesibilidad: response.accesibilidad,
                    hasParking: response.parkingBicis != nil && response.parkingBicis != "0",
                    hasBusConnection: response.corBus != nil && response.corBus != "0",
                    hasMetroConnection: response.corMetro != nil && response.corMetro != "0"
                )
            }
        } catch {
            print("⚠️ [DataService] Failed to search stops: \(error)")
            return []
        }
    }

    /// Get trip details
    func fetchTripDetails(tripId: String) async -> TripDetailResponse? {
        do {
            return try await gtfsRealtimeService.fetchTrip(tripId: tripId)
        } catch {
            print("⚠️ [DataService] Failed to fetch trip \(tripId): \(error)")
            return nil
        }
    }

    // MARK: - Alerts

    /// Fetch alerts for a specific stop
    func fetchAlertsForStop(stopId: String) async -> [AlertResponse] {
        do {
            let alerts = try await gtfsRealtimeService.fetchAlertsForStop(stopId: stopId)
            print("✅ [DataService] Fetched \(alerts.count) alerts for stop \(stopId)")
            return alerts
        } catch {
            print("⚠️ [DataService] Failed to fetch alerts for stop \(stopId): \(error)")
            return []
        }
    }

    /// Fetch alerts for a specific route
    func fetchAlertsForRoute(routeId: String) async -> [AlertResponse] {
        do {
            let alerts = try await gtfsRealtimeService.fetchAlertsForRoute(routeId: routeId)
            print("✅ [DataService] Fetched \(alerts.count) alerts for route \(routeId)")
            return alerts
        } catch {
            print("⚠️ [DataService] Failed to fetch alerts for route \(routeId): \(error)")
            return []
        }
    }

    /// Fetch alerts for a line (checks all route IDs)
    func fetchAlertsForLine(_ line: Line) async -> [AlertResponse] {
        var allAlerts: [AlertResponse] = []
        var seenIds = Set<String>()

        for routeId in line.routeIds {
            let alerts = await fetchAlertsForRoute(routeId: routeId)
            for alert in alerts {
                if !seenIds.contains(alert.id) {
                    seenIds.insert(alert.id)
                    allAlerts.append(alert)
                }
            }
        }

        return allAlerts
    }

    /// Fetch all alerts for the current nucleo
    func fetchAlertsForCurrentNucleo() async -> [AlertResponse] {
        do {
            let allAlerts = try await gtfsRealtimeService.fetchAlerts()

            // Filter to alerts that affect routes in our nucleo
            guard currentNucleo != nil else { return allAlerts }

            let nucleoRouteIds = Set(lines.flatMap { $0.routeIds })
            let nucleoStopIds = Set(stops.map { $0.id })

            return allAlerts.filter { alert in
                alert.informedEntities.contains { entity in
                    if let routeId = entity.routeId, nucleoRouteIds.contains(routeId) {
                        return true
                    }
                    if let stopId = entity.stopId, nucleoStopIds.contains(stopId) {
                        return true
                    }
                    return false
                }
            }
        } catch {
            print("⚠️ [DataService] Failed to fetch alerts: \(error)")
            return []
        }
    }

    // MARK: - Estimated Positions

    /// Fetch estimated train positions for current nucleo
    func fetchTrainPositions() async -> [EstimatedPositionResponse] {
        guard let nucleo = currentNucleo else { return [] }

        do {
            let positions = try await gtfsRealtimeService.fetchEstimatedPositionsForNucleo(nucleoId: nucleo.id)
            print("✅ [DataService] Fetched \(positions.count) train positions for \(nucleo.name)")
            return positions
        } catch {
            print("⚠️ [DataService] Failed to fetch train positions: \(error)")
            return []
        }
    }

    /// Fetch estimated train positions for a specific line
    func fetchTrainPositionsForLine(_ line: Line) async -> [EstimatedPositionResponse] {
        var allPositions: [EstimatedPositionResponse] = []
        var seenIds = Set<String>()

        for routeId in line.routeIds {
            do {
                let positions = try await gtfsRealtimeService.fetchEstimatedPositionsForRoute(routeId: routeId)
                for position in positions {
                    if !seenIds.contains(position.id) {
                        seenIds.insert(position.id)
                        allPositions.append(position)
                    }
                }
            } catch {
                print("⚠️ [DataService] Failed to fetch positions for route \(routeId): \(error)")
            }
        }

        return allPositions
    }

}
