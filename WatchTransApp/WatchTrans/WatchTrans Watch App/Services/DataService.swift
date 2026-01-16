//
//  DataService.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//
//  UPDATED: 2026-01-16 - Now loads ALL data from RenfeServer API (juanmacias.com:8002)
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
                    connectionLineIds: [],
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
                    connectionLineIds: [],
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

            // Group routes by short name to create lines
            var lineDict: [String: Line] = [:]

            for route in routeResponses {
                let lineId = route.shortName.lowercased()

                if lineDict[lineId] == nil {
                    lineDict[lineId] = Line(
                        id: lineId,
                        name: route.shortName,
                        type: .cercanias,
                        colorHex: route.color.map { "#\($0)" } ?? "#75B6E0",
                        nucleo: nucleoName
                    )
                }
            }

            lines = Array(lineDict.values)
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

        // 2. Fetch from RenfeServer API (juanmacias.com:8002)
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

    // Get line by ID
    func getLine(by id: String) -> Line? {
        return lines.first { $0.id == id }
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
                    connectionLineIds: [],
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
}
