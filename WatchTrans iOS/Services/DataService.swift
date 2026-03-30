//
//  DataService.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//
//  UPDATED: 2026-01-16 - Now loads ALL data from WatchTrans API (api.watch-trans.app)
//  UPDATED: 2026-01-27 - Added API route planner integration
//  UPDATED: 2026-01-31 - Performance optimization with persistent caching
//
//  CACHING STRATEGY:
//  -----------------
//  • Stops/Lines/Colors: 24h TTL via Storage (file mod-date)
//  • Shapes/Location: persisted indefinitely
//  • Arrivals: 45s in-memory TTL (no persistent cache)
//
//  LOADING FLOW:
//  -------------
//  1. App start → Load stops from Storage (instant) → Show UI immediately
//  2. Background: Prefetch arrivals for favorites + frequent stops
//  3. User enters Lines tab → Lazy load lines from Storage or API
//

import Foundation
import CoreLocation

/// Current location context - holds network/province info for the user's location
struct LocationContext: Codable {
    let provinceName: String
    let networks: [NetworkInfo]
    let primaryNetworkName: String?  // e.g., "Rodalies de Catalunya", "Cercanías Madrid"

    /// Display name for the title bar
    var displayName: String {
        // Use province name as display (e.g., "Barcelona", "Madrid", "Sevilla")
        provinceName
    }

    /// Check if this is a specific city
    func isCity(_ city: String) -> Bool {
        provinceName.lowercased() == city.lowercased()
    }
}

/// Result from fetchOperatingHours - contains hours string and suspension info
struct OperatingHoursResult {
    let hoursString: String?
    let isSuspended: Bool
    let suspensionMessage: String?

    /// For normal operating hours
    static func hours(_ hours: String?) -> OperatingHoursResult {
        OperatingHoursResult(hoursString: hours, isSuspended: false, suspensionMessage: nil)
    }

    /// For suspended service
    static func suspended(message: String?) -> OperatingHoursResult {
        OperatingHoursResult(hoursString: nil, isSuspended: true, suspensionMessage: message)
    }
}

@Observable
class DataService {
    var lines: [Line] = []
    var stops: [Stop] = []
    var networks: [NetworkResponse] = []
    var currentLocation: LocationContext?
    var isLoading = false
    var isLoadingLines = false
    var error: Error?

    // MARK: - Persistent Cache

    private let storage = Storage(folder: "WatchTransCache")
    private static let cacheTTL: TimeInterval = 24 * 60 * 60  // 24 hours

    private var linesLoaded = false

    /// In-memory cache of line colors: lineName -> colorHex (e.g., "C1" -> "#75B2E0")
    private var lineColorsCache: [String: String] = [:]

    /// In-memory platforms cache (per stop, populated on demand)
    private var platformsCache: [String: [PlatformInfo]] = [:]

    /// Get filtered lines based on user's transport type preferences
    var filteredLines: [Line] {
        let enabledTypes = Self.getEnabledTransportTypes()
        // If empty set, show all lines
        if enabledTypes.isEmpty {
            return lines
        }
        return lines.filter { enabledTypes.contains($0.type) }
    }

    /// Get enabled transport types from UserDefaults
    static func getEnabledTransportTypes() -> Set<TransportType> {
        guard let data = UserDefaults.standard.data(forKey: "enabledTransportTypes"),
              let types = try? JSONDecoder().decode([TransportType].self, from: data) else {
            return [] // Empty means all enabled
        }
        return Set(types)
    }

    // MARK: - GTFS-Realtime Services

    private let networkService: NetworkService
    let gtfsRealtimeService: GTFSRealtimeService  // Internal for OfflineScheduleService access
    @ObservationIgnored private lazy var gtfsMapper = GTFSRealtimeMapper(dataService: self)

    // MARK: - Initialization

    init() {
        self.networkService = NetworkService()
        self.gtfsRealtimeService = GTFSRealtimeService(networkService: networkService)
        loadFromDisk()
    }

    // MARK: - Persistent Cache Methods

    /// Load all caches from disk on init
    private func loadFromDisk() {
        if let cached = try? storage.load(forKey: "stops", as: [Stop].self, maxAge: Self.cacheTTL) {
            self.stops = cached
            DebugLog.log("📦 [Cache] Loaded \(cached.count) stops from disk")
        }

        if let cached = try? storage.load(forKey: "location", as: LocationContext.self, maxAge: .infinity) {
            self.currentLocation = cached
            DebugLog.log("📦 [Cache] Loaded location: \(cached.provinceName)")
        }

        if let cached = try? storage.load(forKey: "colors", as: [String: String].self, maxAge: Self.cacheTTL) {
            self.lineColorsCache = cached
            DebugLog.log("📦 [Cache] Loaded \(cached.count) line colors from disk")
        }

        if let cached = try? storage.load(forKey: "shapes", as: [String: [ShapePoint]].self, maxAge: .infinity) {
            self.shapeCache = cached
            DebugLog.log("📦 [Cache] Loaded shapes for \(cached.count) routes")
        }
    }

    /// Save line colors to disk (builds color dictionary from loaded lines)
    private func saveLineColors() {
        var colors: [String: String] = lineColorsCache
        for line in lines {
            let name = line.name.lowercased()
            colors[name] = line.colorHex
            colors[line.name] = line.colorHex
            if name.hasPrefix("l") || name.hasPrefix("c") {
                colors[String(name.dropFirst())] = line.colorHex
            }
        }
        lineColorsCache = colors
        try? storage.save(object: colors, forKey: "colors")
        DebugLog.log("📦 [Cache] Saved \(colors.count) line colors")
    }

    /// Save shape cache to disk
    private func saveShapeCache() {
        try? storage.save(object: shapeCache, forKey: "shapes")
    }

    /// Generate hash from coordinates for cache validation
    private func coordinatesHash(lat: Double, lon: Double) -> String {
        // Round to 2 decimals (~1km precision) to avoid cache invalidation on small GPS drift
        let roundedLat = (lat * 100).rounded() / 100
        let roundedLon = (lon * 100).rounded() / 100
        return "\(roundedLat),\(roundedLon)"
    }

    // MARK: - Arrival Cache

    private struct CacheEntry {
        let arrivals: [Arrival]
        let timestamp: Date

        var isValid: Bool {
            Date.now.timeIntervalSince(timestamp) < APIConfiguration.arrivalCacheTTL
        }

        /// Cache entry is old but still within grace period (can be used as fallback)
        var isWithinGracePeriod: Bool {
            Date.now.timeIntervalSince(timestamp) < APIConfiguration.staleCacheGracePeriod
        }
    }

    private var arrivalCache: [String: CacheEntry] = [:]

    /// In-flight arrival requests to deduplicate concurrent fetches for the same stop
    private var inFlightArrivals: [String: Task<[Arrival], Never>] = [:]

    // MARK: - Route Shape Cache

    /// Cache of route shapes - shapes don't change often, so cache indefinitely during session
    private var shapeCache: [String: [ShapePoint]] = [:]

    // MARK: - Public Methods

    /// Initialize data - call this on app launch
    /// Loads stops from cache or API, then eagerly loads lines for Map and correspondences.
    private var isFetchingStops = false
    private var lastStopsLoadTime: Date?

    func fetchTransportData(latitude: Double? = nil, longitude: Double? = nil) async {
        // Debounce: skip if stops were loaded very recently
        if let lastLoad = lastStopsLoadTime, Date.now.timeIntervalSince(lastLoad) < 10, !stops.isEmpty {
            DebugLog.log("📍 [DataService] Skipping fetchTransportData (loaded \(Int(Date.now.timeIntervalSince(lastLoad)))s ago)")
            return
        }

        guard !isFetchingStops else {
            DebugLog.log("📍 [DataService] Skipping duplicate fetchTransportData (already in progress)")
            return
        }
        isFetchingStops = true
        defer { isFetchingStops = false }

        isLoading = true
        defer { isLoading = false }

        guard let lat = latitude, let lon = longitude else {
            DebugLog.log("⚠️ [DataService] No coordinates provided - cannot load data")
            return
        }

        let coordHash = coordinatesHash(lat: lat, lon: lon)
        DebugLog.log("📍 [DataService] ========== LOADING STOPS ==========")
        DebugLog.log("📍 [DataService] Coordinates provided (redacted) hash: \(coordHash)")

        let totalStart = Date.now

        // Check if we have valid cached stops (loaded from disk on init)
        let cacheValid = !stops.isEmpty && storage.exists(forKey: "stops")

        if cacheValid {
            DebugLog.log("📦 [DataService] Using cached stops (\(stops.count) stops)")
            await setLocationContextFromStops()
            DebugLog.log("📍 [DataService] ========== LOAD COMPLETE (cached) ==========")
            lastStopsLoadTime = Date.now
            // Eagerly load lines so Map and correspondences work without visiting Lines tab
            await fetchLinesIfNeeded(latitude: lat, longitude: lon)
            return
        }

        // Need to fetch from API (no cache or expired)
        do {
            DebugLog.log("📍 [DataService] Fetching stops from API...")
            let stopsStart = Date.now
            let stopResponses = try await gtfsRealtimeService.fetchStopsByCoordinates(latitude: lat, longitude: lon)
            let stopsTime = Date.now.timeIntervalSince(stopsStart)
            DebugLog.log("📍 [DataService] ✅ Got \(stopResponses.count) stops in \(String(format: "%.2f", stopsTime))s")

            // Map and save new stops
            stops = stopResponses.map { response in
                Stop(
                    id: response.id,
                    name: response.name,
                    latitude: response.lat,
                    longitude: response.lon,
                    province: response.province,
                    accesibilidad: response.accesibilidad,
                    hasParking: response.parkingBicis != nil && response.parkingBicis != "0",
                    hasBusConnection: response.corBus != nil && response.corBus != "0",
                    hasMetroConnection: response.corMetro != nil && response.corMetro != "0",
                    isHub: response.isHub ?? false,
                    corMetro: response.corMetro,
                    corTren: response.corTren,
                    corTranvia: response.corTranvia,
                    corBus: response.corBus,
                    corFunicular: response.corFunicular,
                    correspondences: response.correspondences,
                    wheelchairBoarding: response.wheelchairBoarding,
                    acercaService: response.acercaService,
                    serviceStatus: response.serviceStatus,
                    suspendedSince: response.suspendedSince
                )
            }
            DebugLog.log("📍 [DataService] ✅ Mapped \(stops.count) stops")

            // Save to cache
            try? storage.save(object: stops, forKey: "stops")
            DebugLog.log("📦 [Cache] Saved \(stops.count) stops")

            // Save hub stops for widget
            let hubStops = stops.filter { $0.isHub }.map {
                SharedStorage.SharedHubStop(stopId: $0.id, stopName: $0.name)
            }
            if !hubStops.isEmpty {
                SharedStorage.shared.saveHubStops(hubStops)
            }

            // Invalidate lines cache since location changed
            linesLoaded = false

            // Set location context
            await setLocationContextFromStops()

            // Check if currentLocation was actually set. If not, force API call.
            if currentLocation == nil {
                DebugLog.log("📍 [DataService] Retrying province context fetch from API...")
                await fallbackFetchProvinceAndSetContext(latitude: lat, longitude: lon)
            }

            let totalTime = Date.now.timeIntervalSince(totalStart)
            DebugLog.log("📍 [DataService] ========== LOAD COMPLETE ==========")
            DebugLog.log("⏱️ [DataService] Total: \(stops.count) stops in \(String(format: "%.2f", totalTime))s")
            lastStopsLoadTime = Date.now

            // Eagerly load lines so Map and correspondences work without visiting Lines tab
            await fetchLinesIfNeeded(latitude: lat, longitude: lon)

        } catch {
            DebugLog.log("⚠️ [DataService] Failed to load stops: \(error)")
            self.error = error
        }
    }

    /// Fetch details for a specific stop ID (e.g. for navigation from correspondences)
    func fetchStopDetails(stopId: String, forceRefresh: Bool = false) async -> Stop? {
        // Check cache first (skip if force refresh for full details)
        if !forceRefresh, let cached = getStop(by: stopId) {
            return cached
        }
        
        do {
            let response = try await gtfsRealtimeService.fetchStop(stopId: stopId)
            let stop = Stop(
                id: response.id,
                name: response.name,
                latitude: response.lat,
                longitude: response.lon,
                province: response.province,
                accesibilidad: response.accesibilidad,
                hasParking: response.parkingBicis != nil && response.parkingBicis != "0",
                hasBusConnection: response.corBus != nil && response.corBus != "0",
                hasMetroConnection: response.corMetro != nil && response.corMetro != "0",
                isHub: response.isHub ?? false,
                corMetro: response.corMetro,
                corTren: response.corTren,
                corTranvia: response.corTranvia,
                corBus: response.corBus,
                corFunicular: response.corFunicular,
                wheelchairBoarding: response.wheelchairBoarding,
                acercaService: response.acercaService,
                serviceStatus: response.serviceStatus,
                suspendedSince: response.suspendedSince
            )
            return stop
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch stop details for \(stopId): \(error)")
            return nil
        }
    }

    /// Set location context from loaded stops (without loading routes)
    private func setLocationContextFromStops() async {
        // 1. Try to find province in loaded stops
        if let firstStopWithProvince = stops.first(where: { $0.province != nil }),
           let province = firstStopWithProvince.province {
            
            if currentLocation?.provinceName == province { return }

            currentLocation = LocationContext(
                provinceName: province,
                networks: [],
                primaryNetworkName: nil
            )
            if let loc = currentLocation { try? storage.save(object: loc, forKey: "location") }
            DebugLog.log("📍 [DataService] ✅ Location set from stops: \(province)")
            return
        }
        
        // If stops are loaded but none have province, we don't set currentLocation yet
        // The fallback fetch will be called later by fetchTransportData if needed
        DebugLog.log("📍 [DataService] No province found in stops, checking API fallback...")
    }

    /// Fallback to fetch province via API and set context if missing
    private func fallbackFetchProvinceAndSetContext(latitude: Double, longitude: Double) async {
        guard !stops.isEmpty else { return } // Need at least one stop to update
        
        do {
            DebugLog.log("📍 [DataService] ⚠️ Stops missing province, asking API...")
            let data = try await gtfsRealtimeService.fetchProvinceByCoordinates(
                latitude: latitude,
                longitude: longitude
            )
            
            // Decode simple response: {"province_name": "Sevilla", "networks": [...]}
            struct ProvinceResponse: Decodable {
                let province: String
                
                enum CodingKeys: String, CodingKey {
                    case province = "province_name"
                }
            }
            
            let response = try JSONDecoder().decode(ProvinceResponse.self, from: data)
            let province = response.province
            
            currentLocation = LocationContext(
                provinceName: province,
                networks: [],
                primaryNetworkName: nil
            )
            if let loc = currentLocation { try? storage.save(object: loc, forKey: "location") }
            DebugLog.log("📍 [DataService] ✅ Location set from API: \(province)")
            
            // Inject into stops so UI works
            for i in stops.indices {
                // Structs are value types, need to recreate
                let s = stops[i]
                stops[i] = Stop(
                    id: s.id, name: s.name, latitude: s.latitude, longitude: s.longitude,
                    province: province,
                    accesibilidad: s.accesibilidad, hasParking: s.hasParking,
                    hasBusConnection: s.hasBusConnection, hasMetroConnection: s.hasMetroConnection,
                    isHub: s.isHub, corMetro: s.corMetro,
                    corTren: s.corTren, corTranvia: s.corTranvia,
                    corBus: s.corBus, corFunicular: s.corFunicular,
                    wheelchairBoarding: s.wheelchairBoarding
                )
            }
            
        } catch {
            DebugLog.log("📍 [DataService] ❌ Failed to fetch province from API: \(error)")
        }
    }

    /// Load lines on demand (lazy loading) - call when user enters Lines tab
    private var isLoadingLinesTask = false
    func fetchLinesIfNeeded(latitude: Double, longitude: Double) async {
        // Already loaded or in-flight
        if linesLoaded && !lines.isEmpty {
            DebugLog.log("📦 [DataService] Lines already loaded (\(lines.count) lines)")
            return
        }
        if isLoadingLinesTask {
            DebugLog.log("🔄 [DataService] Lines fetch already in progress, skipping")
            return
        }
        isLoadingLinesTask = true
        defer { isLoadingLinesTask = false }

        // Network-first: always fetch from API, cache is offline fallback only

        // No cache, fetch from API with loading indicator
        isLoadingLines = true
        defer { isLoadingLines = false }

        DebugLog.log("📍 [DataService] ========== LOADING LINES ==========")
        let totalStart = Date.now

        do {
            // Fetch networks if not yet loaded
            if networks.isEmpty {
                DebugLog.log("📍 [DataService] Fetching networks...")
                do {
                    self.networks = try await gtfsRealtimeService.fetchNetworks()
                    DebugLog.log("📍 [DataService] ✅ Loaded \(networks.count) networks")
                } catch {
                    DebugLog.log("⚠️ [DataService] Failed to fetch networks: \(error)")
                }
            }

            // NEW: Single API call to get province + ALL routes from ALL networks
            DebugLog.log("📍 [DataService] Fetching province with routes: (\(latitude), \(longitude))...")
            let fetchStart = Date.now
            
            struct ProvinceWithRoutesResponse: Decodable {
                let provinceName: String
                let networks: [NetworkInfo]
                let routes: [RouteResponse]?  // Optional for backwards compatibility
                
                enum CodingKeys: String, CodingKey {
                    case provinceName = "province_name"
                    case networks
                    case routes
                }
                
                struct NetworkInfo: Decodable {
                    let code: String
                    let name: String

                    enum CodingKeys: String, CodingKey {
                        case code = "id"
                        case name
                    }
                }
            }
            
            let provinceData = try await gtfsRealtimeService.fetchProvinceByCoordinates(
                latitude: latitude,
                longitude: longitude,
                includeNetworks: true,
                includeRoutes: true  // NEW: Get routes in same call
            )
            let provinceInfo = try JSONDecoder().decode(ProvinceWithRoutesResponse.self, from: provinceData)
            DebugLog.log("📍 [DataService] ✅ Province: \(provinceInfo.provinceName), Networks: \(provinceInfo.networks.count)")
            
            let allRoutes: [RouteResponse]
            
            // If backend returns routes directly, use them (NEW)
            if let routes = provinceInfo.routes {
                DebugLog.log("📍 [DataService] ✅ Got \(routes.count) routes from province endpoint")
                allRoutes = routes
            } else {
                // Fallback: Use hybrid approach if endpoint doesn't return routes yet
                DebugLog.log("📍 [DataService] ⚠️ Routes not in response, using fallback approach...")
                
                // Load routes from province
                let provinceRoutes = try await gtfsRealtimeService.fetchProvinceRoutes(provinceName: provinceInfo.provinceName)
                DebugLog.log("📍 [DataService] ✅ Got \(provinceRoutes.count) routes from province")
                
                var tempRoutes = provinceRoutes
                
                // Detect missing networks
                let provinceNetworkCodes = Set(provinceRoutes.compactMap { route -> String? in
                    if let match = route.id.range(of: #"_(\d+T)_"#, options: .regularExpression) {
                        return String(route.id[match]).replacingOccurrences(of: "_", with: "")
                    }
                    return nil
                })
                
                let missingNetworks = provinceInfo.networks.filter { !provinceNetworkCodes.contains($0.code) }
                
                // Fetch missing networks
                if !missingNetworks.isEmpty {
                    DebugLog.log("📍 [DataService] Fetching \(missingNetworks.count) missing networks...")
                    await withTaskGroup(of: [RouteResponse].self) { group in
                        for network in missingNetworks {
                            group.addTask {
                                do {
                                    let lines = try await self.gtfsRealtimeService.fetchNetworkLines(networkId: network.code)
                                    return lines.flatMap { line in
                                        line.routes.map { route in
                                            RouteResponse(
                                                id: route.id,
                                                shortName: line.lineCode,
                                                longName: route.longName,
                                                routeType: 0,
                                                color: route.color,
                                                textColor: line.textColor,
                                                agencyId: route.agencyId ?? "unknown",
                                                agencyName: route.agencyName,
                                                networkId: network.code,
                                                description: nil,
                                                isCircular: false
                                            )
                                        }
                                    }
                                } catch {
                                    DebugLog.log("⚠️ [DataService] Failed to fetch \(network.code): \(error)")
                                    return []
                                }
                            }
                        }
                        
                        for await routes in group {
                            tempRoutes.append(contentsOf: routes)
                        }
                    }
                }
                
                allRoutes = tempRoutes
            }
            
            let fetchTime = Date.now.timeIntervalSince(fetchStart)
            DebugLog.log("📍 [DataService] ✅ Got \(allRoutes.count) total routes in \(String(format: "%.2f", fetchTime))s")

            // Process routes
            let processStart = Date.now
            await processRoutes(allRoutes, provinceName: provinceInfo.provinceName)
            let processTime = Date.now.timeIntervalSince(processStart)
            DebugLog.log("📍 [DataService] ✅ Processed \(lines.count) lines in \(String(format: "%.2f", processTime))s")

            // Save to cache
            try? storage.save(object: lines, forKey: "lines")
            saveLineColors()
            linesLoaded = true
            DebugLog.log("📦 [Cache] Saved \(lines.count) lines")

            // Update location with network info
            await updateLocationWithNetworks()

            let totalTime = Date.now.timeIntervalSince(totalStart)
            DebugLog.log("📍 [DataService] ========== LINES LOADED ==========")
            DebugLog.log("⏱️ [DataService] Total: \(lines.count) lines in \(String(format: "%.2f", totalTime))s")

        } catch {
            DebugLog.log("⚠️ [DataService] Failed to load lines: \(error)")
            // Offline fallback: use cache if available
            if let cached = try? storage.load(forKey: "lines", as: [Line].self, maxAge: .infinity) {
                self.lines = cached
                self.linesLoaded = true
                saveLineColors()
                DebugLog.log("📦 [Cache] Offline fallback: loaded \(cached.count) lines from cache")
                await updateLocationWithNetworks()
            } else {
                self.error = error
            }
        }
    }

    /// Update location context with full network information
    private func updateLocationWithNetworks() async {
        guard let province = currentLocation?.provinceName else { return }

        // Do not hardcode any network/province mappings here.
        // The UI can still use provinceName, and we only populate networks once we have a reliable API source.
        currentLocation = LocationContext(provinceName: province, networks: [], primaryNetworkName: nil)
        if let loc = currentLocation { try? storage.save(object: loc, forKey: "location") }
        DebugLog.log("📍 [DataService] ✅ Location updated")
    }

    /// Process route responses into Line models
    private func processRoutes(_ routeResponses: [RouteResponse], provinceName: String) async {
        DebugLog.log("🚃 [ProcessRoutes] Processing \(routeResponses.count) routes for province: \(provinceName)")

        // Debug: Log all incoming routes
        for route in routeResponses {
            DebugLog.log("   -> Procesando ruta: \(route.shortName) (\(route.id)) - Agency: \(route.agencyId)")
        }

        // Group routes by short name to create lines, collecting all route IDs
        var lineDict: [String: (line: Line, routeIds: [String], longName: String, isCircular: Bool)] = [:]

        // Default color
        let defaultColor = "#75B6E0"

        for route in routeResponses {
            // Create unique ID per agency to separate Metro L1 from Cercanías C1
            let transportType = TransportType.from(routeType: route.routeType)
            let lineId = "\(route.agencyId)_\(route.shortName.lowercased())"

            // Debug: Log longName for Cercanías routes (to diagnose RENFE issue)
            if transportType == .tren {
                DebugLog.log("🚃 [API] Route \(route.shortName) longName: \"\(route.longName)\"")
            }

            if var existing = lineDict[lineId] {
                existing.routeIds.append(route.id)
                // If any route is circular, mark the line as circular
                if route.isCircular == true {
                    existing.isCircular = true
                }
                // Prefer more descriptive long names when multiple route variants exist
                let preferredLongName = choosePreferredLongName(
                    current: existing.longName,
                    candidate: route.longName,
                    shortName: route.shortName,
                    transportType: transportType
                )
                let displayLongName = circularDisplayName(from: preferredLongName)
                if displayLongName != existing.longName {
                    existing.longName = displayLongName
                }
                lineDict[lineId] = existing
            } else {
                let color = route.color ?? defaultColor

                // Format line name: Metro lines get "L" prefix (except R ramal)
                let displayName: String
                if transportType == .metro && route.shortName != "R" && !route.shortName.uppercased().hasPrefix("L") {
                    displayName = "L\(route.shortName)"
                } else {
                    displayName = route.shortName
                }

                let preferredLongName = choosePreferredLongName(
                    current: nil,
                    candidate: route.longName,
                    shortName: route.shortName,
                    transportType: transportType
                )
                let displayLongName = circularDisplayName(from: preferredLongName)

                let line = Line(
                    id: lineId,
                    name: displayName,
                    longName: displayLongName,
                    type: transportType,
                    colorHex: color,
                    nucleo: provinceName,
                    agencyId: route.agencyId,
                    agencyName: route.agencyName ?? "",
                    routeIds: [route.id],
                    isCircular: route.isCircular ?? false,
                    serviceStatus: route.serviceStatus,
                    suspendedSince: route.suspendedSince,
                    isAlternativeService: route.isAlternativeService,
                    alternativeForShortName: route.alternativeForShortName
                )
                lineDict[lineId] = (
                    line: line,
                    routeIds: [route.id],
                    longName: displayLongName,
                    isCircular: route.isCircular ?? false
                )
            }
        }

        // Create final lines with all collected route IDs
        var createdLines = lineDict.map { (_, value) in
            Line(
                id: value.line.id,
                name: value.line.name,
                longName: value.longName,
                type: value.line.type,
                colorHex: value.line.colorHex,
                nucleo: value.line.nucleo,
                agencyId: value.line.agencyId,
                agencyName: value.line.agencyName,
                routeIds: value.routeIds,
                isCircular: value.isCircular,
                suspensionAlert: nil,  // Will be populated below
                serviceStatus: value.line.serviceStatus,
                suspendedSince: value.line.suspendedSince,
                isAlternativeService: value.line.isAlternativeService,
                alternativeForShortName: value.line.alternativeForShortName
            )
        }

        // Check for suspension alerts for each line
        await withTaskGroup(of: (Int, String?).self) { group in
            for (index, line) in createdLines.enumerated() {
                // Only check first routeId for each line
                guard let routeId = line.routeIds.first else { continue }
                
                group.addTask {
                    do {
                        let alerts = try await self.gtfsRealtimeService.fetchAlertsForRoute(routeId: routeId)
                        // Find the most severe disruption alert
                        for alert in alerts {
                            if alert.effect == "NO_SERVICE" || alert.aiStatus == "FULL_SUSPENSION" || alert.aiCategory?.contains("FULL_SUSPENSION") == true {
                                return (index, "Servicio interrumpido")
                            }
                        }
                        for alert in alerts {
                            switch alert.effect {
                            case "REDUCED_SERVICE": return (index, "Servicio reducido")
                            case "MODIFIED_SERVICE": return (index, "Servicio modificado")
                            case "SIGNIFICANT_DELAYS": return (index, "Retrasos significativos")
                            case "DETOUR": return (index, "Desvío de ruta")
                            default: continue
                            }
                        }
                        return (index, nil)
                    } catch {
                        return (index, nil)
                    }
                }
            }
            
            for await (index, alertMessage) in group {
                if let message = alertMessage {
                    createdLines[index].suspensionAlert = message
                }
            }
        }
        
        lines = createdLines

        // Debug: Show lines by type
        let byType = Dictionary(grouping: lines, by: { $0.type })
        DebugLog.log("🚃 [ProcessRoutes] ✅ Created \(lines.count) lines:")
        for (type, typeLines) in byType.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let names = typeLines.map { $0.name }.sorted().joined(separator: ", ")
            let suspended = typeLines.filter { $0.suspensionAlert != nil }.map { $0.name }
            DebugLog.log("🚃 [ProcessRoutes]   \(type.rawValue): \(typeLines.count) lines (\(names))")
            if !suspended.isEmpty {
                DebugLog.log("🚃 [ProcessRoutes]   🚨 Suspended: \(suspended.joined(separator: ", "))")
            }
        }
    }

    /// Choose the most descriptive long name among route variants.
    private func choosePreferredLongName(
        current: String?,
        candidate: String,
        shortName: String,
        transportType: TransportType
    ) -> String {
        let trimmedCandidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCandidate.isEmpty else { return current ?? "" }
        guard let current = current else { return trimmedCandidate }

        let currentScore = longNameScore(
            current,
            shortName: shortName,
            transportType: transportType
        )
        let candidateScore = longNameScore(
            trimmedCandidate,
            shortName: shortName,
            transportType: transportType
        )

        return candidateScore > currentScore ? trimmedCandidate : current
    }

    private func longNameScore(
        _ value: String,
        shortName: String,
        transportType: TransportType
    ) -> Int {
        let normalizedValue = normalizeForMatching(value)
        let normalizedShort = normalizeForMatching(shortName)
        if normalizedValue.isEmpty { return -10 }

        var score = 0
        if value.contains(" - ") { score += 2 }
        if isGenericCercaniasName(
            normalizedValue: normalizedValue,
            normalizedShortName: normalizedShort,
            transportType: transportType
        ) {
            score -= 3
        }
        if normalizedValue.count >= 6 { score += 1 }
        return score
    }

    private func isGenericCercaniasName(
        normalizedValue: String,
        normalizedShortName: String,
        transportType: TransportType
    ) -> Bool {
        guard transportType == .tren else { return false }
        return normalizedValue.contains("cercan")
            && normalizedValue.contains("linea")
            && normalizedValue.contains(normalizedShortName)
    }

    private func normalizeForMatching(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Refresh line long names using cached itineraries (A - B endpoints)
    func refreshLineLongNamesFromItineraries() async {
        guard !lines.isEmpty else { return }

        var updatedLines = lines
        var didUpdate = false

        for index in updatedLines.indices {
            let line = updatedLines[index]
            
            // Always try to improve Cercanías names if they don't look like "A - B"
            let needsImprovement = shouldDeriveLongNameForEndpoints(line) || 
                                  (line.type == .tren && !line.longName.contains(" - "))
            
            guard needsImprovement else { continue }
            guard let routeId = line.routeIds.first else { continue }

            if let endpoints = await OfflineLineService.shared.getRouteEndpoints(for: routeId) {
                let isCircularByStops = endpoints.start.caseInsensitiveCompare(endpoints.end) == .orderedSame
                let derived: String
                if line.isCircular || isCircularByStops {
                    derived = "Circular"
                } else {
                    derived = "\(endpoints.start) - \(endpoints.end)"
                }
                
                // Update if different, or if current is just "C1" but we have "A - B"
                if derived != line.longName {
                    updatedLines[index] = Line(
                        id: line.id,
                        name: line.name,
                        longName: derived,
                        type: line.type,
                        colorHex: line.colorHex,
                        nucleo: line.nucleo,
                        agencyId: line.agencyId,
                        agencyName: line.agencyName,
                        routeIds: line.routeIds,
                        isCircular: line.isCircular,
                        serviceStatus: line.serviceStatus,
                        suspendedSince: line.suspendedSince,
                        isAlternativeService: line.isAlternativeService,
                        alternativeForShortName: line.alternativeForShortName
                    )
                    didUpdate = true
                    DebugLog.log("🏷️ [DataService] Improved line name: \(line.name) -> \(derived)")
                }
            }
        }

        if didUpdate {
            lines = updatedLines
            // Save improved names to cache so we don't have to re-calculate next time
            try? storage.save(object: lines, forKey: "lines")
            saveLineColors()
        }
    }

    private func shouldDeriveLongNameForEndpoints(_ line: Line) -> Bool {
        if line.isCircular { return true }
        if line.longName.contains(" - ") { return false }
        if line.longName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }

        // Metro/Tram: if API doesn't provide A - B, derive from endpoints
        if line.type == .metro || line.type == .tram {
            return true
        }

        return isGenericLongName(line.longName, line: line)
    }

    private func isGenericLongName(_ value: String, line: Line) -> Bool {
        let normalizedLong = normalizeForMatching(value)
        let normalizedName = normalizeForMatching(line.name)
        if normalizedLong == normalizedName { return true }
        if normalizedLong.contains("linea") && normalizedLong.contains(normalizedName) { return true }
        if line.type == .tren {
            return normalizedLong.contains("cercan") && normalizedLong.contains("linea")
        }
        return false
    }

    private func circularDisplayName(from value: String) -> String {
        isCircularLongName(value) ? "Circular" : value
    }

    private func isCircularLongName(_ value: String) -> Bool {
        let parts = value.split(separator: "-", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2 else { return false }
        let left = normalizeForMatching(parts[0])
        let right = normalizeForMatching(parts[1])
        return !left.isEmpty && left == right
    }

    /// Fetch stops for a specific route
    func fetchStopsForRoute(routeId: String) async -> [Stop] {
        do {
            let stopResponses = try await gtfsRealtimeService.fetchRouteStops(routeId: routeId)
            DebugLog.log("🚏 [DataService] Fetched \(stopResponses.count) stops for route \(routeId)")
            return stopResponses.map { response in
                // Per-stop correspondence logging removed for production
                
                // ENRICHMENT: If API response lacks connection info, try to find it in our global stops cache
                var metro = response.corMetro
                var cerc = response.corTren
                var tram = response.corTranvia
                var bus = response.corBus
                var funicular = response.corFunicular

                if (metro?.isEmpty ?? true) && (cerc?.isEmpty ?? true) && (tram?.isEmpty ?? true) && (bus?.isEmpty ?? true) && (funicular?.isEmpty ?? true) {
                    if let cached = self.getStop(by: response.id) {
                        metro = cached.corMetro
                        cerc = cached.corTren
                        tram = cached.corTranvia
                        bus = cached.corBus
                        funicular = cached.corFunicular
                        if metro != nil || cerc != nil || tram != nil || bus != nil || funicular != nil {
                            DebugLog.log("🔗 [DataService] ✅ Enriched connections for '\(response.name)' from cache")
                        }
                    }
                }
                
                return Stop(
                    id: response.id,
                    name: response.name,
                    latitude: response.lat,
                    longitude: response.lon,
                    province: response.province,
                    accesibilidad: response.accesibilidad,
                    hasParking: response.parkingBicis != nil && response.parkingBicis != "0",
                    hasBusConnection: response.corBus != nil && response.corBus != "0",
                    hasMetroConnection: response.corMetro != nil && response.corMetro != "0",
                    isHub: response.isHub ?? false,
                    corMetro: metro,
                    corTren: cerc,
                    corTranvia: tram,
                    corBus: bus,
                    corFunicular: funicular,
                    correspondences: response.correspondences,
                    wheelchairBoarding: response.wheelchairBoarding,
                    acercaService: response.acercaService,
                    serviceStatus: response.serviceStatus,
                    suspendedSince: response.suspendedSince
                )
            }
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch stops for route \(routeId): \(error)")
            return []
        }
    }

    /// Fetch route detail to get service_status, suspended_since, is_alternative_service
    func fetchRouteDetail(routeId: String) async -> RouteResponse? {
        do {
            return try await gtfsRealtimeService.fetchRouteDetail(routeId: routeId)
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch route detail for \(routeId): \(error)")
            return nil
        }
    }

    /// Fetch operating hours for a route (calculated from stop_times)
    func fetchOperatingHours(routeId: String) async -> OperatingHoursResult {
        // Determine current day type (weekday=L-J, friday=V, saturday=S, sunday=D)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date.now)
        let dayType: String
        let dayName: String
        switch weekday {
        case 1:  // Sunday
            dayType = "sunday"
            dayName = "Domingo"
        case 6:  // Friday
            dayType = "friday"
            dayName = "Viernes"
        case 7:  // Saturday
            dayType = "saturday"
            dayName = "Sábado"
        default:  // Monday-Thursday
            dayType = "weekday"
            dayName = "L-J"
        }
        
        DebugLog.log("📅 [HOURS] Fetching for \(routeId), dayType=\(dayType) (\(dayName))")

        do {
            let hours = try await gtfsRealtimeService.fetchRouteOperatingHours(routeId: routeId)

            // Check for suspended service
            if hours.isSuspended == true {
                DebugLog.log("📅 [HOURS] ⚠️ Service SUSPENDED for \(routeId): \(hours.suspensionMessage ?? "No message")")
                return .suspended(message: hours.suspensionMessage)
            }

            // Select the appropriate day based on current weekday
            let dayHours: DayOperatingHours?
            switch dayType {
            case "sunday":
                dayHours = hours.sunday ?? hours.weekday
            case "saturday":
                dayHours = hours.saturday ?? hours.weekday
            case "friday":
                dayHours = hours.friday ?? hours.weekday
            default:
                dayHours = hours.weekday
            }

            if let dh = dayHours {
                let result = dh.displayString
                DebugLog.log("📅 [HOURS] ✅ Result (\(dayType)): \(result)")
                return .hours(result)
            }
        } catch {
            DebugLog.log("📅 [HOURS] ❌ API call failed for \(routeId): \(error)")
        }

        DebugLog.log("📅 [HOURS] ❌ No hours found for \(routeId)")
        return .hours(nil)
    }

    /// Calculate operating hours string from frequency responses
    private func calculateOperatingHours(from frequencies: [FrequencyResponse]) -> String {
        // Separate morning service from late-night service
        // Late-night service (e.g., 00:00-01:30) runs AFTER midnight, not at opening
        let morningStarts = frequencies.compactMap { parseTimeToMinutes($0.startTime) }
            .filter { $0 >= APIConfiguration.morningThresholdMinutes }
        let allEndTimes = frequencies.compactMap { parseTimeToMinutes($0.endTime) }

        // Opening = earliest morning start (ignore 00:00 late-night entries)
        // Closing = latest end time (could be 24:00, 25:30, or 01:30)
        guard let openingTime = morningStarts.min(), let maxEnd = allEndTimes.max() else {
            // Fallback to simple min/max if no morning entries
            let startTimes = frequencies.compactMap { parseTimeToMinutes($0.startTime) }
            guard let minStart = startTimes.min(), let maxEnd = allEndTimes.max() else {
                return "?"
            }
            return "\(formatMinutesToTime(minStart)) - \(formatMinutesToTime(maxEnd % (24 * 60)))"
        }

        // DEBUG: Log raw times
        let rawStartTimes = frequencies.map { $0.startTime }
        let rawEndTimes = frequencies.map { $0.endTime }
        DebugLog.log("📅 [HOURS] Raw start times: \(rawStartTimes)")
        DebugLog.log("📅 [HOURS] Raw end times: \(rawEndTimes)")
        DebugLog.log("📅 [HOURS] Opening (morning): \(openingTime / 60):\(String(format: "%02d", openingTime % 60))")
        DebugLog.log("📅 [HOURS] maxEnd (minutes): \(maxEnd) = \(maxEnd / 60)h \(maxEnd % 60)m")

        let startStr = formatMinutesToTime(openingTime)
        // Handle times > 24:00 (e.g., 25:30:00 = 01:30 next day)
        let endStr = formatMinutesToTime(maxEnd % (24 * 60))

        // DEBUG: Log conversion if time was > 24:00
        if maxEnd >= 24 * 60 {
            DebugLog.log("📅 [HOURS] GTFS time >24h: \(maxEnd / 60):\(String(format: "%02d", maxEnd % 60)) → \(endStr)")
        }

        DebugLog.log("📅 [DataService] Operating hours: \(startStr) - \(endStr)")
        return "\(startStr) - \(endStr)"
    }

    /// Parse time string "HH:MM:SS" to minutes since midnight
    private func parseTimeToMinutes(_ timeStr: String) -> Int? {
        let parts = timeStr.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        return hour * 60 + minute
    }

    /// Format minutes to "HH:MM" string
    private func formatMinutesToTime(_ minutes: Int) -> String {
        let hour = minutes / 60
        let min = minutes % 60
        return String(format: "%02d:%02d", hour, min)
    }

    // Fetch arrivals for a specific stop using WatchTrans API
    // Falls back to offline cached schedules when there's no network
    func fetchArrivals(for stopId: String) async -> [Arrival] {
        DebugLog.log("🔍 [DataService] Fetching arrivals for stop: \(stopId)")

        // 1. Check cache first
        if let cached = getCachedArrivals(for: stopId) {
            DebugLog.log("✅ [DataService] Cache hit! Returning \(cached.count) cached arrivals")
            let enriched = await enrichArrivalsWithPlatforms(cached, stopId: stopId)
            // Refresh cache so subsequent UI refreshes show platform immediately.
            cacheArrivals(enriched, for: stopId)
            return enriched
        }

        // 2. Deduplicate: if there's already an in-flight request for this stop, await it
        if let existingTask = inFlightArrivals[stopId] {
            DebugLog.log("🔄 [DataService] In-flight request exists for \(stopId), awaiting...")
            return await existingTask.value
        }

        // 3. Create and track the fetch task
        let task = Task<[Arrival], Never> { [self] in
            defer { inFlightArrivals[stopId] = nil }

            // Check if we're offline - use offline schedule cache
            if !NetworkMonitor.shared.isConnected {
                DebugLog.log("📴 [DataService] Offline - checking offline schedule cache...")
                if let offlineDepartures = await OfflineScheduleService.shared.getCachedDepartures(for: stopId) {
                    let arrivals = mapOfflineDeparturesToArrivals(offlineDepartures, stopId: stopId)
                    DebugLog.log("📦 [DataService] Returning \(arrivals.count) offline arrivals")
                    return arrivals
                }
            }

            // Fetch from WatchTrans API (api.watch-trans.app)
            do {
                DebugLog.log("📡 [DataService] Cache miss, calling WatchTrans API...")
                var departures = try await gtfsRealtimeService.fetchDepartures(stopId: stopId, limit: 40)

                // Fallback: If empty and ID is numeric, try prefixes (Legacy & Future support)
                if departures.isEmpty && stopId.allSatisfy({ $0.isNumber }) {
                    let prefixes = ["RENFE_C_", "RENFE_CERCANIAS_", "RENFE_F_", "RENFE_P_"]
                    for prefix in prefixes {
                        let altId = "\(prefix)\(stopId)"
                        DebugLog.log("📡 [DataService] Retry with: \(altId)")
                        let retryDeps = try await gtfsRealtimeService.fetchDepartures(stopId: altId, limit: 40)
                        if !retryDeps.isEmpty {
                            departures = retryDeps
                            break
                        }
                    }
                }

                DebugLog.log("📊 [DataService] API returned \(departures.count) departures for stop \(stopId)")

                var arrivals = gtfsMapper.mapToArrivals(departures: departures, stopId: stopId)
                DebugLog.log("✅ [DataService] Mapped to \(arrivals.count) arrivals")

                arrivals = await enrichArrivalsWithPlatforms(arrivals, stopId: stopId)
                arrivals = await enrichWithPlatformPredictions(arrivals, stopId: stopId)

                // Cache results
                cacheArrivals(arrivals, for: stopId)

                // Also cache for offline use
                let stopName = getStop(by: stopId)?.name ?? stopId
                await OfflineScheduleService.shared.cacheSchedules(for: stopId, stopName: stopName, departures: departures)

                return arrivals
            } catch {
                DebugLog.log("⚠️ [DataService] WatchTrans API Error: \(error)")

                // Try offline schedule cache as fallback
                if let offlineDepartures = await OfflineScheduleService.shared.getCachedDepartures(for: stopId) {
                    let arrivals = mapOfflineDeparturesToArrivals(offlineDepartures, stopId: stopId)
                    DebugLog.log("📦 [DataService] API failed, returning \(arrivals.count) offline arrivals")
                    return arrivals
                }

                // Try stale cache as fallback
                if let stale = getStaleCachedArrivals(for: stopId) {
                    DebugLog.log("ℹ️ [DataService] Using stale cached data for stop \(stopId)")
                    return stale
                }

                DebugLog.log("ℹ️ [DataService] No data available for stop \(stopId)")
                self.error = error
                return []
            }
        }

        inFlightArrivals[stopId] = task
        return await task.value
    }

    private func enrichArrivalsWithPlatforms(_ arrivals: [Arrival], stopId: String) async -> [Arrival] {
        let needs = arrivals.contains { ($0.platform ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard needs else { return arrivals }

        let missingCount = arrivals.filter { ($0.platform ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        DebugLog.log("🚏 [Platforms] Enrichment needed for \(stopId): \(missingCount)/\(arrivals.count) missing platform")

        let platforms = await platformsForEnrichment(stopId: stopId)
        guard !platforms.isEmpty else { return arrivals }

        // Map each line to the best platform code we have.
        // Prefer real-time sources over static/estimated sources so the UI can color accordingly.
        var lineToPlatform: [String: (code: String, estimated: Bool)] = [:]
        for platform in platforms {
            let rawCode = platform.platformCode ?? platform.description ?? ""
            let normalizedCode = normalizePlatformCode(rawCode)
            guard !normalizedCode.isEmpty else { continue }

            // Use explicit field from API (default to estimated if missing)
            // platform_estimated: false -> Realtime
            // platform_estimated: true -> Historical
            let estimated = platform.platformEstimated ?? true

            for line in platform.linesList {
                let key = normalizeLineCodeForPlatformMatch(line)
                guard !key.isEmpty else { continue }
                if let existing = lineToPlatform[key] {
                    // Prefer confirmed (non-estimated) over estimated.
                    if existing.estimated && !estimated {
                        lineToPlatform[key] = (normalizedCode, estimated)
                    }
                } else {
                    lineToPlatform[key] = (normalizedCode, estimated)
                }
            }
        }

        guard !lineToPlatform.isEmpty else { return arrivals }

        return arrivals.map { arrival in
            let existing = (arrival.platform ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !existing.isEmpty { return arrival }

            let key = normalizeLineCodeForPlatformMatch(arrival.lineName)
            guard let mapped = lineToPlatform[key] else { return arrival }
            return arrival.withPlatform(mapped.code, estimated: mapped.estimated)
        }
    }

    private func platformsForEnrichment(stopId: String) async -> [PlatformInfo] {
        if let cached = platformsCache[stopId] {
            DebugLog.log("🚏 [Platforms] Cache hit for \(stopId): \(cached.count) platforms")
            return cached
        }

        let platforms = await fetchPlatforms(stopId: stopId)
        DebugLog.log("🚏 [Platforms] Fetched for enrichment \(stopId): \(platforms.count) platforms")

        // Always cache in memory (even empty results) to avoid repeated network calls
        // for stops that genuinely have no platforms (e.g. Metro Sevilla)
        platformsCache[stopId] = platforms
        
        return platforms
    }

    /// Second-pass enrichment: fill remaining empty platforms using historical predictions
    private func enrichWithPlatformPredictions(_ arrivals: [Arrival], stopId: String) async -> [Arrival] {
        guard arrivals.contains(where: { ($0.platform ?? "").isEmpty }) else { return arrivals }

        guard let predictions = try? await gtfsRealtimeService.fetchPlatformPredictions(stopId: stopId) else {
            return arrivals
        }
        guard !predictions.isEmpty else { return arrivals }

        DebugLog.log("🔮 [Platforms] Enriching with \(predictions.count) predictions for \(stopId)")

        return arrivals.map { arrival in
            guard (arrival.platform ?? "").isEmpty else { return arrival }

            let match = predictions.first { p in
                let lineMatch = p.routeShortName?.lowercased() == arrival.lineName.lowercased()
                let headsignMatch = p.headsign == nil ||
                    arrival.destination.lowercased().contains(p.headsign?.lowercased() ?? "")
                return lineMatch && headsignMatch
            }

            guard let match = match else { return arrival }
            return arrival.withPlatform(match.predictedPlatform, estimated: true)
        }
    }

    private func normalizeLineCodeForPlatformMatch(_ value: String) -> String {
        var s = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("LÍNEA ") { s = String(s.dropFirst("LÍNEA ".count)) }
        if s.hasPrefix("LINEA ") { s = String(s.dropFirst("LINEA ".count)) }
        s = s.replacingOccurrences(of: " ", with: "")
        return s
    }

    private func normalizePlatformCode(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let lower = trimmed.lowercased()
        let prefixes = ["vía", "via", "andén", "anden", "plataforma", "platform"]
        var result = trimmed
        for p in prefixes {
            if lower.hasPrefix(p) {
                result = trimmed.dropFirst(p.count).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        // If it's like "1-3" or "1/2", keep as-is; if it's empty, fall back.
        return result.isEmpty ? trimmed : result
    }

    /// Map offline departures to Arrival model
    private func mapOfflineDeparturesToArrivals(_ departures: [OfflineDeparture], stopId: String) -> [Arrival] {
        let now = Date.now
        return departures.map { dep in
            let expectedTime = now.addingTimeInterval(TimeInterval(dep.minutesUntil * 60))
            return Arrival(
                id: UUID().uuidString,
                lineId: dep.routeId,
                lineName: dep.routeShortName,
                destination: dep.headsign,
                scheduledTime: expectedTime,  // For offline, scheduled = expected
                expectedTime: expectedTime,
                platform: nil,
                platformEstimated: false,
                trainCurrentStop: nil,
                trainProgressPercent: nil,
                trainLatitude: nil,
                trainLongitude: nil,
                trainStatus: nil,
                trainEstimated: nil,
                delaySeconds: nil,
                routeColor: dep.routeColor,
                routeId: dep.routeId,
                isSuspended: false,  // Offline data doesn't have suspension info
                wheelchairAccessible: false,  // Offline data doesn't have accessibility info
                wheelchairInaccessible: false,
                frequencyBased: false,
                headwayMinutes: nil,
                isOfflineData: true,  // Mark as offline data
                occupancyStatus: nil,
                occupancyPercentage: nil,
                routeTextColor: nil,
                isSkipped: nil,
                vehicleLat: nil,
                vehicleLon: nil,
                vehicleLabel: nil
            )
        }
    }

    /// Cache offline schedules for all favorite stops (call when online)
    func cacheOfflineSchedulesForFavorites() async {
        guard NetworkMonitor.shared.isConnected else {
            DebugLog.log("📴 [DataService] Cannot cache offline - no network")
            return
        }

        let allFavorites = SharedStorage.shared.getFavorites().map { $0.stopId }
        // Only cache favorites that are in the current location's stops
        let loadedStopIds = Set(stops.map { $0.id })
        let favorites = allFavorites.filter { loadedStopIds.contains($0) }
        DebugLog.log("📦 [DataService] Caching offline schedules for \(favorites.count)/\(allFavorites.count) favorites (current location)")

        for stopId in favorites {
            do {
                let departures = try await gtfsRealtimeService.fetchDepartures(stopId: stopId, limit: 50)
                let stopName = getStop(by: stopId)?.name ?? stopId
                await OfflineScheduleService.shared.cacheSchedules(for: stopId, stopName: stopName, departures: departures)
            } catch {
                DebugLog.log("⚠️ [DataService] Failed to cache \(stopId): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cache Helpers

    private func getCachedArrivals(for stopId: String) -> [Arrival]? {
        guard let entry = arrivalCache[stopId], entry.isValid else {
            return nil
        }
        return entry.arrivals
    }

    private func cacheArrivals(_ arrivals: [Arrival], for stopId: String) {
        arrivalCache[stopId] = CacheEntry(arrivals: arrivals, timestamp: Date.now)
    }

    /// Get stale cached arrivals (within grace period) - useful for showing data immediately while refreshing
    func getStaleCachedArrivals(for stopId: String) -> [Arrival]? {
        guard let entry = arrivalCache[stopId], entry.isWithinGracePeriod else {
            return nil
        }
        return entry.arrivals
    }

    /// Clear arrival cache (useful for pull-to-refresh)
    func clearArrivalCache() {
        arrivalCache.removeAll()
    }

    /// Clear all persistent caches (stops, lines, colors, platforms, shapes)
    /// Call this from Settings when user wants to force refresh all data
    func clearAllPersistentCaches() {
        DebugLog.log("🗑️ [DataService] Clearing all persistent caches...")

        // Clear disk caches
        try? storage.removeAll()

        // Clear in-memory caches
        arrivalCache.removeAll()
        platformsCache.removeAll()
        shapeCache.removeAll()
        lineColorsCache.removeAll()

        DebugLog.log("✅ [DataService] All caches cleared successfully")
    }

    // Get stop by ID (robust matching)
    func getStop(by id: String) -> Stop? {
        let lowerId = id.lowercased().trimmingCharacters(in: .whitespaces)
        
        // 1. Exact match
        if let exact = stops.first(where: { $0.id.lowercased() == lowerId }) {
            return exact
        }
        
        // 2. Try with common prefixes if ID is numeric
        if lowerId.allSatisfy({ $0.isNumber }) {
            let prefixes = ["renfe_c_", "renfe_cercanias_", "metro_", "fgc_"]
            for prefix in prefixes {
                let altId = "\(prefix)\(lowerId)"
                if let match = stops.first(where: { $0.id.lowercased() == altId }) {
                    return match
                }
            }
        }
        
        return nil
    }

    // Get line by ID or name (case-insensitive)
    // Handles API format variations: "1" -> "L1", "4" -> "L4", "ML1" -> "ML1", "C1" -> "C1"
    // Also handles branch lines: "7b" -> "L7B", "9b" -> "L9B", "10b" -> "L10B"
    func getLine(by id: String) -> Line? {
        let lowerId = id.lowercased().trimmingCharacters(in: .whitespaces)

        // Try exact match first (by ID or name)
        if let exact = lines.first(where: { $0.id.lowercased() == lowerId || $0.name.lowercased() == lowerId }) {
            return exact
        }

        // Match by route IDs (if API returns full route_id instead of line name)
        if let byRoute = lines.first(where: { line in
            line.routeIds.contains { $0.lowercased().trimmingCharacters(in: .whitespaces) == lowerId }
        }) {
            return byRoute
        }

        // For Metro: API returns "1", "2", etc. but line names are "L1", "L2"
        // Check if it's a plain number (Metro line)
        if let _ = Int(lowerId) {
            let metroName = "l\(lowerId)"
            if let metro = lines.first(where: { $0.name.lowercased() == metroName && $0.type == .metro }) {
                return metro
            }
        }

        // For Metro branch lines: "7a" -> "L7a", "7b" -> "L7b", "9A" -> "L9A", "10b" -> "L10b"
        // Check if it ends with a letter and starts with a number
        if lowerId.count >= 2 && lowerId.last?.isLetter == true && lowerId.first?.isNumber == true {
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
        
        // Final fallback: Match by exact short name (e.g. "T1" matches line with name "T1" even if ID is "TRAM_SEVILLA_60")
        if let byShortName = lines.first(where: { $0.name.lowercased() == lowerId }) {
            return byShortName
        }

        // Debug: log only when we actually have lines loaded (otherwise it spams during cold start).
        if !lines.isEmpty {
            DebugLog.log("❌ [getLine] NOT FOUND '\(id)'. Available: \(lines.map { $0.name }.sorted().joined(separator: ", "))")
        }
        return nil
    }

    /// Build UI stop entries per transport type (no hardcoded logic).
    func makeStopDisplays(for stop: Stop) -> [StopDisplay] {
        // cor_* fields are correspondences (walking connections), not lines at this stop.
        // Each stop produces ONE display with its own transport type.
        // Correspondences are shown as badges in the UI, not as separate displays.
        return [StopDisplay(stop: stop, transportType: stop.transportType, allowedLineIds: [])]
    }

    private func parseCorLines(_ value: String?) -> [String] {
        guard let value = value, !value.isEmpty else { return [] }
        return value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func inferTransportType(from lineId: String) -> TransportType? {
        let trimmed = lineId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let upper = trimmed.uppercased()

        if upper.hasPrefix("ML") {
            return .metro
        }
        if upper.hasPrefix("L"), upper.count > 1 {
            return .metro
        }
        // Handle plain numbers as Metro (e.g., "1", "6", "10")
        if Int(upper) != nil {
            return .metro
        }
        if upper.hasPrefix("T"), upper.count > 1 {
            return .tram
        }
        if upper.hasPrefix("C"), upper.count > 1 {
            return .tren
        }
        if upper.hasPrefix("FGC") {
            return .tren
        }
        return nil
    }

    /// Filter arrivals to match a StopDisplay's transport type and line IDs
    func filterArrivals(_ arrivals: [Arrival], for display: StopDisplay?) -> [Arrival] {
        guard let display = display else { return arrivals }

        let allowed = display.normalizedLineIds
        if !allowed.isEmpty {
            return arrivals.filter { arrival in
                // Match by short name from API (e.g., "C1", "L1", "T1")
                if allowed.contains(arrival.lineName.lowercased()) {
                    return true
                }
                // Match by lineId if it's already a short name
                if allowed.contains(arrival.lineId.lowercased()) {
                    return true
                }
                // Match by full route_id -> line name
                if let routeId = arrival.routeId, let line = getLine(by: routeId) {
                    return allowed.contains(line.name.lowercased())
                }
                // Match by lineId -> line name
                if let line = getLine(by: arrival.lineId) {
                    return allowed.contains(line.name.lowercased())
                }
                return false
            }
        }

        return arrivals.filter { arrival in
            if let line = getLine(by: arrival.lineId) {
                return line.type == display.transportType
            }
            if let routeId = arrival.routeId, let line = getLine(by: routeId) {
                return line.type == display.transportType
            }
            return display.stop.transportType == display.transportType
        }
    }

    /// Get line color from cache or loaded lines
    /// This is useful for correspondences where we need colors but might not have loaded all line data
    /// Returns nil if color not found in cache
    func getLineColor(by lineName: String) -> String? {
        let lowerName = lineName.lowercased().trimmingCharacters(in: .whitespaces)

        // 1. Check color cache first (fastest, persisted)
        if let cachedColor = lineColorsCache[lowerName] {
            return cachedColor
        }
        if let cachedColor = lineColorsCache[lineName] {
            return cachedColor
        }

        // 2. Try loaded lines
        if let line = getLine(by: lineName) {
            // Found in loaded lines - also add to color cache for next time
            lineColorsCache[lowerName] = line.colorHex
            lineColorsCache[lineName] = line.colorHex
            return line.colorHex
        }

        // 3. Not found anywhere
        return nil
    }

    /// Build RENFE-prefixed fallback stop IDs for platform/correspondence lookups.
    private func fallbackRenfeStopId(for stopId: String) -> String? {
        let trimmed = stopId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("RENFE_") {
            let withoutPrefix = String(trimmed.dropFirst("RENFE_".count))
            return withoutPrefix.isEmpty ? nil : withoutPrefix
        }
        // Only add RENFE_ for numeric stop IDs (RENFE station codes).
        // This avoids incorrect fallbacks like "RENFE_L1-21" for Metro/Tram IDs.
        guard trimmed.allSatisfy({ $0.isNumber }) else { return nil }
        return "RENFE_\(trimmed)"
    }

    /// Search stops by name (filtered to current province/network)
    func searchStops(query: String) async -> [Stop] {
        do {
            let stopResponses = try await gtfsRealtimeService.fetchStops(search: query, limit: 100)

            // Get current province for filtering
            let currentProvince = currentLocation?.provinceName

            // Convert to Stop objects
            let allStops = stopResponses.map { response in
                Stop(
                    id: response.id,
                    name: response.name,
                    latitude: response.lat,
                    longitude: response.lon,
                    province: response.province,
                    accesibilidad: response.accesibilidad,
                    hasParking: response.parkingBicis != nil && response.parkingBicis != "0",
                    hasBusConnection: response.corBus != nil && response.corBus != "0",
                    hasMetroConnection: response.corMetro != nil && response.corMetro != "0",
                    isHub: response.isHub ?? false,
                    corMetro: response.corMetro,
                    corTren: response.corTren,
                    corTranvia: response.corTranvia,
                    corBus: response.corBus,
                    corFunicular: response.corFunicular,
                    serviceStatus: response.serviceStatus,
                    suspendedSince: response.suspendedSince
                )
            }

            // Filter by current province if we have location context
            guard let province = currentProvince else {
                DebugLog.log("🔍 [DataService] searchStops: No province filter (no location context)")
                return Array(allStops.prefix(50))
            }

            // Get provinces that belong to the same network region
            let relatedProvinces = getRelatedProvinces(for: province)

            let filteredStops = allStops.filter { stop in
                guard let stopProvince = stop.province else { return false }
                return relatedProvinces.contains(stopProvince)
            }

            DebugLog.log("🔍 [DataService] searchStops '\(query)': \(allStops.count) total -> \(filteredStops.count) in \(province) region")
            return Array(filteredStops.prefix(50))
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to search stops: \(error)")
            return []
        }
    }

    /// Get provinces that belong to the same transport network region
    private func getRelatedProvinces(for province: String) -> Set<String> {
        return Set([province])
    }

    /// Get trip details
    func fetchTripDetails(tripId: String) async -> TripDetailResponse? {
        do {
            return try await gtfsRealtimeService.fetchTrip(tripId: tripId)
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch trip \(tripId): \(error)")
            return nil
        }
    }

    // MARK: - Alerts

    /// Fetch alerts for a specific stop (uses direct endpoint for efficiency)
    func fetchAlertsForStop(stopId: String) async -> [AlertResponse] {
        // Don't check NetworkMonitor here - let the request fail naturally if offline
        do {
            // Use direct endpoint instead of fetching all + filtering
            let alerts = try await gtfsRealtimeService.fetchAlertsForStop(stopId: stopId)
            if !alerts.isEmpty {
                // Filter out alerts where stop-level entities exist but don't include this stop
                // (e.g., partial suspension affecting only Santa Justa → Jardines, not San Jerónimo)
                let stopVariants = AlertFilterHelper.alertStopIdVariants(for: stopId)
                let filtered = alerts.filter { alert in
                    let entities = alert.informedEntities ?? []
                    let stopEntities = entities.filter { $0.stopId != nil }
                    // If alert has stop-level entities, only show if this stop is among them
                    if !stopEntities.isEmpty {
                        return stopEntities.contains { stopVariants.contains($0.stopId ?? "") }
                    }
                    // Route-level only: show for all stops on the route
                    return true
                }
                DebugLog.log("✅ [DataService] Fetched \(alerts.count) alerts for stop \(stopId), \(filtered.count) applicable")
                return filtered
            }

            // Only fallback for RENFE stops where ID prefix mismatch is possible
            let shouldFallback = stopId.hasPrefix("RENFE_") || stopId.allSatisfy({ $0.isNumber })
            guard shouldFallback else {
                DebugLog.log("✅ [DataService] No alerts for stop \(stopId) (no fallback needed)")
                return []
            }

            // Fallback: fetch active alerts and filter locally (handles RENFE_ prefixed IDs)
            let allAlerts = try await gtfsRealtimeService.fetchAlerts()
            let stopIds = AlertFilterHelper.alertStopIdVariants(for: stopId)
            let filtered = allAlerts.filter { alert in
                let entities = alert.informedEntities ?? []
                return entities.contains { entity in
                    if let entityStopId = entity.stopId, stopIds.contains(entityStopId) {
                        return true
                    }
                    return false
                }
            }
            DebugLog.log("✅ [DataService] Fetched \(filtered.count) alerts for stop \(stopId) (fallback)")
            return filtered
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch alerts for stop \(stopId): \(error)")
            return []
        }
    }

    /// Fetch alerts for a specific route
    func fetchAlertsForRoute(routeId: String, routeShortName: String? = nil) async -> [AlertResponse] {
        do {
            let alerts = try await gtfsRealtimeService.fetchAlertsForRoute(routeId: routeId)
            if !alerts.isEmpty {
                return alerts
            }

            // Fallback: only for RENFE routes where ID prefix mismatches are possible
            let shouldFallback = routeId.hasPrefix("RENFE_") || routeId.allSatisfy({ $0.isNumber })
            guard shouldFallback else { return [] }

            let allAlerts = try await gtfsRealtimeService.fetchAlerts()
            let routeIds = AlertFilterHelper.alertRouteIdVariants(for: routeId)
            let routePrefixes = AlertFilterHelper.alertRoutePrefixes(for: [routeId])
            let normalizedShortName = AlertFilterHelper.normalizeForMatching(routeShortName ?? "")
            let filtered = allAlerts.filter { alert in
                let entities = alert.informedEntities ?? []
                return entities.contains { entity in
                    if let entityRouteId = entity.routeId, routeIds.contains(entityRouteId) {
                        return true
                    }
                    if !normalizedShortName.isEmpty,
                       let entityShort = entity.routeShortName,
                       AlertFilterHelper.normalizeForMatching(entityShort) == normalizedShortName {
                        // Require RENFE-style prefix match to avoid cross-city collisions
                        if let entityRouteId = entity.routeId,
                           let entityPrefix = AlertFilterHelper.alertRoutePrefix(from: entityRouteId),
                           !routePrefixes.isEmpty {
                            return routePrefixes.contains(entityPrefix)
                        }
                        // When we can't disambiguate by prefix, don't match
                        return false
                    }
                    return false
                }
            }
            return filtered
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch alerts for route \(routeId): \(error)")
            return []
        }
    }

    /// Fetch alerts for a line using the route-specific endpoint
    func fetchAlertsForLine(_ line: Line) async -> [AlertResponse] {
        guard let routeId = line.routeIds.first else {
            return []
        }
        let alerts = await fetchAlertsForRoute(routeId: routeId, routeShortName: line.name)
        if !alerts.isEmpty {
            return alerts
        }

        // Extra fallback: use route short name + inferred RENFE prefix from line route IDs
        let allAlerts = (try? await gtfsRealtimeService.fetchAlerts()) ?? []
        return AlertFilterHelper.filterAlertsByRoute(
            alerts: allAlerts,
            lineRouteIds: line.routeIds,
            lineName: line.name
        )
    }

    // MARK: - Platforms & Correspondences

    /// Fetch platform coordinates for a station
    /// Returns the exact position of each platform/line within the station
    func fetchPlatforms(stopId: String) async -> [PlatformInfo] {
        do {
            let response = try await gtfsRealtimeService.fetchPlatforms(stopId: stopId)
            if !response.platforms.isEmpty {
                DebugLog.log("🚏 [DataService] Fetched \(response.platforms.count) platforms for \(stopId)")
                return response.platforms
            }
            
            // Fallback: If empty and ID is numeric, try prefixes (Legacy & Future support)
            if stopId.allSatisfy({ $0.isNumber }) {
                // Try all standardized prefixes in order of probability
                let prefixes = ["RENFE_C_", "RENFE_CERCANIAS_", "RENFE_F_", "RENFE_P_"]
                for prefix in prefixes {
                    let altId = "\(prefix)\(stopId)"
                    let fallbackRes = try await gtfsRealtimeService.fetchPlatforms(stopId: altId)
                    if !fallbackRes.platforms.isEmpty {
                        DebugLog.log("🚏 [DataService] Fetched \(fallbackRes.platforms.count) platforms for \(altId) (fallback)")
                        return fallbackRes.platforms
                    }
                }
            }
            
            return []
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch platforms for \(stopId): \(error)")
            return []
        }
    }

    /// Fetch walking correspondences from a station
    /// Returns nearby stations connected by walking passages (e.g., underground tunnels)
    /// - Parameters:
    ///   - stopId: The station ID
    ///   - includeShape: If true, includes walking route coordinates (for map display)
    func fetchCorrespondences(stopId: String, includeShape: Bool = false) async -> [CorrespondenceInfo] {
        // Don't check NetworkMonitor here - let the request fail naturally if offline
        do {
            let response = try await gtfsRealtimeService.fetchCorrespondences(stopId: stopId, includeShape: includeShape)
            var rawCorrespondences = response.correspondences ?? []
            if rawCorrespondences.isEmpty {
                if let fallbackId = fallbackRenfeStopId(for: stopId) {
                    let fallback = try await gtfsRealtimeService.fetchCorrespondences(stopId: fallbackId, includeShape: includeShape)
                    rawCorrespondences = fallback.correspondences ?? []
                    DebugLog.log("🚶 [DataService] Fetched \(rawCorrespondences.count) correspondences for \(fallbackId) (fallback)")
                }
            }
            
            // DEDUPLICATION & NAME RESOLUTION
            // Group multiple stops of the same target station into a single correspondence entry (the closest one)
            var uniqueCorrespondences: [String: CorrespondenceInfo] = [:]
            
            for var corr in rawCorrespondences {
                // 1. Try to resolve missing name from global cache
                if (corr.toStopName ?? "").isEmpty {
                    if let cached = self.getStop(by: corr.toStopId) {
                        corr = corr.withResolvedName(cached.name)
                    }
                }
                
                // 2. Filter out "junk" entries (no name AND no lines)
                // These are usually internal nodes or platform definitions without useful info
                if (corr.toStopName ?? "").isEmpty && 
                   (corr.toLines ?? "").isEmpty {
                    continue
                }
                
                // 3. Create a key for grouping
                // If name is available, group by Name.
                // If not, group by Lines (e.g. all "T1" stops group together).
                // We IGNORE toStopId for grouping because the API returns unique IDs for platforms of the same station.
                let namePart = corr.toStopName ?? ""
                let linesPart = corr.toLines ?? ""
                
                let key: String
                if !namePart.isEmpty {
                    key = namePart // Group by station name (e.g. "San Bernardo")
                } else {
                    key = "LINES:\(linesPart)" // Group by line list (e.g. "T1")
                }
                
                // 4. Keep only the closest entry for this group
                if let existing = uniqueCorrespondences[key] {
                    if (corr.distanceM ?? Int.max) < (existing.distanceM ?? Int.max) {
                        uniqueCorrespondences[key] = corr
                    }
                } else {
                    uniqueCorrespondences[key] = corr
                }
            }
            
            // Convert back to array and sort by distance
            let result = Array(uniqueCorrespondences.values).sorted {
                ($0.distanceM ?? Int.max) < ($1.distanceM ?? Int.max)
            }
            
            DebugLog.log("🚶 [DataService] Optimized correspondences: \(rawCorrespondences.count) -> \(result.count) unique hubs for \(stopId)")
            return result
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch correspondences for \(stopId): \(error)")
            return []
        }
    }

    /// Fetch transport mode connections for a station (e.g., metro/tram lines)
    func fetchTransportModes(stopId: String) async -> [TransportModeInfo] {
        do {
            let response = try await gtfsRealtimeService.fetchCorrespondences(stopId: stopId)
            let modes = response.transportModes ?? []
            if modes.isEmpty, let fallbackId = fallbackRenfeStopId(for: stopId) {
                let fallback = try await gtfsRealtimeService.fetchCorrespondences(stopId: fallbackId)
                let fallbackModes = fallback.transportModes ?? []
                DebugLog.log("🔗 [DataService] Fetched \(fallbackModes.count) transport modes for \(fallbackId) (fallback)")
                return fallbackModes
            }
            DebugLog.log("🔗 [DataService] Fetched \(modes.count) transport modes for \(stopId)")
            return modes
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch transport modes for \(stopId): \(error)")
            return []
        }
    }

    /// Fetch physical entrances (accesses) for a station
    /// Returns all access points with coordinates, accessibility info, and opening hours
    func fetchAccesses(stopId: String) async -> [StationAccess] {
        // Don't check NetworkMonitor here - let the request fail naturally if offline
        // The guard was causing false negatives due to MainActor isolation race conditions
        do {
            let response = try await gtfsRealtimeService.fetchAccesses(stopId: stopId)
            DebugLog.log("🚪 [DataService] Fetched \(response.accesses.count) accesses for \(stopId)")
            return response.accesses
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch accesses for \(stopId): \(error)")
            return []
        }
    }

    // MARK: - Route Shapes

    /// Fetch shape (polyline) for a route
    /// Returns array of shape points to draw the route on a map
    /// Uses cache to avoid redundant API calls - shapes don't change during a session
    /// - Parameter maxGap: If provided, normalizes coordinates to have no gaps > maxGap meters
    func fetchRouteShape(routeId: String, maxGap: Int? = nil) async -> [ShapePoint] {
        // Create cache key including maxGap to differentiate normalized vs raw shapes
        let cacheKey = maxGap.map { "\(routeId)_gap\($0)" } ?? routeId

        // Check cache first (thread-safe)
        let cached: [ShapePoint]? = shapeCache[cacheKey]
        if let cached = cached {
            DebugLog.log("🗺️ [DataService] ✅ Shape CACHE HIT for \(routeId) (\(cached.count) points)")
            return cached
        }

        // Fetch from API
        do {
            let response = try await gtfsRealtimeService.fetchRouteShape(routeId: routeId, maxGap: maxGap)
            let sorted = response.shape.sorted { $0.sequence < $1.sequence }
            DebugLog.log("🗺️ [DataService] Fetched \(sorted.count) shape points for \(routeId)\(maxGap.map { " (normalized max_gap=\($0))" } ?? "")")

            // Store in cache (thread-safe)
            shapeCache[cacheKey] = sorted
            
            // Save to disk (background)
            Task(priority: .background) {
                saveShapeCache()
            }

            // Debug: Show first 5 and last 2 coordinates to verify shape data
            if sorted.count >= 5 {
                DebugLog.log("🗺️ [DataService]   First 5 coords:")
                for (i, pt) in sorted.prefix(5).enumerated() {
                    DebugLog.log("🗺️ [DataService]     [\(i)] (\(pt.lat), \(pt.lon))")
                }
                DebugLog.log("🗺️ [DataService]   Last 2 coords:")
                for (i, pt) in sorted.suffix(2).enumerated() {
                    DebugLog.log("🗺️ [DataService]     [\(sorted.count - 2 + i)] (\(pt.lat), \(pt.lon))")
                }
            }
            return sorted
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch shape for \(routeId): \(error)")
            return []
        }
    }

    /// Result type for shape with stops (on_shape coordinates for map markers)
    struct ShapeWithStops {
        let shapePoints: [ShapePoint]
        let stopCoordinates: [String: CLLocationCoordinate2D]  // stopId -> on_shape coordinate
    }

    /// Fetch route shape with stop coordinates projected onto the line
    /// Use this for maps to place stop markers exactly on the line shape
    func fetchRouteShapeWithStops(routeId: String, maxGap: Int? = nil) async -> ShapeWithStops {
        // Fetch shape with include_stops=true
        do {
            let response = try await gtfsRealtimeService.fetchRouteShape(
                routeId: routeId,
                maxGap: maxGap,
                includeStops: true // API 500 fixed
            )
            let sortedShape = response.shape.sorted { $0.sequence < $1.sequence }

            // Build mapping of stop_id -> on_shape coordinate
            var stopCoords: [String: CLLocationCoordinate2D] = [:]
            if let stops = response.stops {
                for stop in stops {
                    stopCoords[stop.stopId] = CLLocationCoordinate2D(
                        latitude: stop.onShape.lat,
                        longitude: stop.onShape.lon
                    )
                }
                DebugLog.log("🗺️ [DataService] Fetched shape with \(sortedShape.count) points and \(stops.count) stop coordinates for \(routeId)")
            } else {
                DebugLog.log("🗺️ [DataService] Fetched shape with \(sortedShape.count) points (no stop coords) for \(routeId)")
            }

            // Fallback: if API returns an empty shape, build a basic polyline from route stops.
            // This keeps maps usable even when GTFS shapes are missing server-side.
            if sortedShape.isEmpty {
                DebugLog.log("🗺️ [DataService] ⚠️ Shape empty for \(routeId). Building fallback polyline from route stops...")
                let routeStops = try await gtfsRealtimeService.fetchRouteStops(routeId: routeId)
                let fallbackPoints: [ShapePoint] = routeStops.enumerated().map { idx, stop in
                    ShapePoint(lat: stop.lat, lon: stop.lon, sequence: idx)
                }
                var fallbackStopCoords: [String: CLLocationCoordinate2D] = [:]
                for stop in routeStops {
                    fallbackStopCoords[stop.id] = CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon)
                }

                let cacheKey = maxGap.map { "\(routeId)_gap\($0)" } ?? routeId
                shapeCache[cacheKey] = fallbackPoints
                Task(priority: .background) { saveShapeCache() }
                return ShapeWithStops(shapePoints: fallbackPoints, stopCoordinates: fallbackStopCoords)
            }

            // Also cache the shape points for the regular fetchRouteShape function
            let cacheKey = maxGap.map { "\(routeId)_gap\($0)" } ?? routeId
            shapeCache[cacheKey] = sortedShape
            Task(priority: .background) { saveShapeCache() }

            return ShapeWithStops(shapePoints: sortedShape, stopCoordinates: stopCoords)
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch shape with stops for \(routeId): \(error)")
            return ShapeWithStops(shapePoints: [], stopCoordinates: [:])
        }
    }

    // MARK: - Route Planner

    /// Result of route planning including alternatives and alerts
    struct RoutePlanResult {
        let journeys: [Journey]       // All alternatives (best first)
        let alerts: [RouteAlert]      // Service alerts affecting the route

        var bestJourney: Journey? { journeys.first }
        var alternativeJourneys: [Journey] { Array(journeys.dropFirst()) }
    }

    /// Plan a journey between two stops using the API route planner
    /// Returns all Pareto-optimal alternatives and any service alerts
    func planJourneys(fromStopId: String, toStopId: String, arriveBy: Bool = false) async -> RoutePlanResult? {
        DebugLog.log("🗺️ [DataService] Planning journey: \(fromStopId) → \(toStopId) \(arriveBy ? "(arrive by)" : "(depart at)")")

        do {
            // NOTE: Using compact=false for main app to get full shapes
            // Widgets use a different path via GTFSRealtimeService with compact=true
            let response = try await gtfsRealtimeService.fetchRoutePlan(fromStopId: fromStopId, toStopId: toStopId, arriveBy: arriveBy)

            guard response.success else {
                DebugLog.log("⚠️ [DataService] Route plan failed: \(response.message ?? "unknown error")")
                return nil
            }
            
            // Log response size/type for debugging
            if let count = response.journeys?.count {
                DebugLog.log("🗺️ [DataService] API returned \(count) journey options")
            } else if response.journey != nil {
                DebugLog.log("🗺️ [DataService] API returned single journey")
            } else {
                DebugLog.log("⚠️ [DataService] API returned success but NO journeys")
            }

            let apiJourneys = response.allJourneys
            guard !apiJourneys.isEmpty else {
                DebugLog.log("⚠️ [DataService] No journeys returned")
                return nil
            }

            // Convert all API journeys to Journey models (async)
            var journeys: [Journey] = []
            for apiJourney in apiJourneys {
                if let journey = await convertToJourney(from: apiJourney) {
                    journeys.append(journey)
                }
            }

            guard !journeys.isEmpty else {
                DebugLog.log("⚠️ [DataService] Failed to convert any journeys")
                return nil
            }

            // Enrich transit segments with full shape coordinates
            // The route planner only returns 2 coords per segment (start/end)
            // We fetch the actual route shapes for smoother map display
            journeys = await enrichJourneysWithShapes(journeys, apiJourneys: apiJourneys)

            DebugLog.log("🗺️ [DataService] ✅ Found \(journeys.count) route(s). Best: \(journeys[0].segments.count) segments, \(journeys[0].totalDurationMinutes) min")

            return RoutePlanResult(
                journeys: journeys,
                alerts: response.alerts ?? []
            )
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to plan journey: \(error)")
            return nil
        }
    }

    /// Plan journeys across a time range using the range endpoint (rRAPTOR)
    /// Returns all journey alternatives within the specified time window
    func planJourneysRange(fromStopId: String, toStopId: String, startTime: String, endTime: String, interval: Int = 15) async -> RoutePlanResult? {
        DebugLog.log("🗺️ [DataService] Planning range journey: \(fromStopId) → \(toStopId) [\(startTime)-\(endTime)]")

        do {
            let response = try await gtfsRealtimeService.fetchRoutePlanRange(
                fromStopId: fromStopId,
                toStopId: toStopId,
                startTime: startTime,
                endTime: endTime,
                interval: interval
            )

            guard response.success else {
                DebugLog.log("⚠️ [DataService] Range route plan failed: \(response.message ?? "unknown error")")
                return nil
            }

            let apiJourneys = response.allJourneys
            guard !apiJourneys.isEmpty else {
                DebugLog.log("⚠️ [DataService] No journeys returned for range")
                return nil
            }

            DebugLog.log("🗺️ [DataService] API returned \(apiJourneys.count) journeys for time range")

            // Convert all API journeys to Journey models (async)
            var journeys: [Journey] = []
            for apiJourney in apiJourneys {
                if let journey = await convertToJourney(from: apiJourney) {
                    journeys.append(journey)
                }
            }

            guard !journeys.isEmpty else {
                DebugLog.log("⚠️ [DataService] Failed to convert any range journeys")
                return nil
            }

            // Enrich transit segments with full shape coordinates
            journeys = await enrichJourneysWithShapes(journeys, apiJourneys: apiJourneys)

            DebugLog.log("🗺️ [DataService] ✅ Range search found \(journeys.count) route(s)")

            return RoutePlanResult(
                journeys: journeys,
                alerts: response.alerts ?? []
            )
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to plan range journey: \(error)")
            return nil
        }
    }

    /// Convenience: Plan journey and return only the best route
    func planJourney(fromStopId: String, toStopId: String) async -> Journey? {
        let result = await planJourneys(fromStopId: fromStopId, toStopId: toStopId)
        return result?.bestJourney
    }

    /// Convert API route plan response to Journey model
    private func convertToJourney(from apiJourney: RoutePlanJourney) async -> Journey? {
        // API v2: origin/destination are computed from segments
        guard let apiOrigin = apiJourney.origin,
              let apiDestination = apiJourney.destination else {
            DebugLog.log("⚠️ [DataService] Journey has no origin/destination")
            return nil
        }

        // Convert origin stop
        let origin = Stop(
            id: apiOrigin.id,
            name: apiOrigin.name,
            latitude: apiOrigin.lat,
            longitude: apiOrigin.lon
        )

        // Convert destination stop
        let destination = Stop(
            id: apiDestination.id,
            name: apiDestination.name,
            latitude: apiDestination.lat,
            longitude: apiDestination.lon
        )

        // Convert segments with platform information
        var segments: [JourneySegment] = []
        for apiSegment in apiJourney.segments {
            let segmentOrigin = Stop(
                id: apiSegment.origin.id,
                name: apiSegment.origin.name,
                latitude: apiSegment.origin.lat,
                longitude: apiSegment.origin.lon
            )

            let segmentDestination = Stop(
                id: apiSegment.destination.id,
                name: apiSegment.destination.name,
                latitude: apiSegment.destination.lat,
                longitude: apiSegment.destination.lon
            )

            let intermediateStops = (apiSegment.intermediateStops ?? []).map { apiStop in
                Stop(
                    id: apiStop.id,
                    name: apiStop.name,
                    latitude: apiStop.lat,
                    longitude: apiStop.lon
                )
            }

            // Convert coordinates
            let coordinates = apiSegment.coordinates.map { coord in
                CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lon)
            }

            // Determine segment type and transport mode
            let segmentType: SegmentType = apiSegment.type == "walking" ? .walking : .transit
            let transportMode = TransportMode(rawValue: apiSegment.transportMode) ?? .metro

            // Parse departure and arrival times
            // API returns format: "2026-01-28T06:30:00" (no timezone)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            let departureTime = apiSegment.departure.flatMap { dateFormatter.date(from: $0) }
            let arrivalTime = apiSegment.arrival.flatMap { dateFormatter.date(from: $0) }
            
            // Fetch platform information from departures API for transit segments
            var platform: String? = nil
            var platformEstimated: Bool = false
            
            if segmentType == .transit, 
               let lineName = apiSegment.lineName,
               let departureTime = departureTime {
                // Fetch arrivals for origin stop
                let arrivals = await fetchArrivals(for: segmentOrigin.id)
                
                // Find matching departure by line name and approximate time (within 2 minutes)
                let matchingArrival = arrivals.first { arrival in
                    arrival.lineName == lineName &&
                    abs(arrival.expectedTime.timeIntervalSince(departureTime)) < 120
                }
                
                if let match = matchingArrival {
                    platform = match.platform
                    platformEstimated = match.platformEstimated
                }
            }

            let segment = JourneySegment(
                type: segmentType,
                transportMode: transportMode,
                lineName: apiSegment.lineName,
                lineColor: apiSegment.lineColor,
                origin: segmentOrigin,
                destination: segmentDestination,
                intermediateStops: intermediateStops,
                durationMinutes: apiSegment.durationMinutes,
                coordinates: coordinates,
                suggestedHeading: apiSegment.suggestedHeading,
                departureTime: departureTime,
                arrivalTime: arrivalTime,
                instructions: apiSegment.instructions,
                entranceName: apiSegment.entranceName,
                exitName: apiSegment.exitName,
                platform: platform,
                platformEstimated: platformEstimated
            )
            segments.append(segment)
        }

        return Journey(
            origin: origin,
            destination: destination,
            segments: segments,
            totalDurationMinutes: apiJourney.totalDurationMinutes,
            totalWalkingMinutes: apiJourney.totalWalkingMinutes,
            transferCount: apiJourney.transferCount
        )
    }

    /// Enrich journeys with full shape coordinates for transit segments
    /// The route planner only returns 2 coords per segment, this fetches the full shapes
    private func enrichJourneysWithShapes(_ journeys: [Journey], apiJourneys: [RoutePlanJourney]) async -> [Journey] {
        var enrichedJourneys: [Journey] = []

        for (journeyIndex, journey) in journeys.enumerated() {
            let apiJourney = apiJourneys[journeyIndex]
            var enrichedSegments: [JourneySegment] = []

            for (segmentIndex, segment) in journey.segments.enumerated() {
                let apiSegment = apiJourney.segments[segmentIndex]

                // Only fetch shapes for transit segments with a lineId
                if segment.type == .transit, let routeId = apiSegment.lineId {
                    // Fetch full shape for this route (use maxGap=100 for better compatibility)
                    var shapePoints = await fetchRouteShape(routeId: routeId, maxGap: 100)

                    // Debug: log what we have before fallback check
                    DebugLog.log("🗺️ [DataService] SHAPE CHECK: routeId=\(routeId), shapePoints.count=\(shapePoints.count), isEmpty=\(shapePoints.isEmpty), lineName=\(segment.lineName ?? "NIL")")

                    // Fallback: if no shapes returned, try finding the line in loaded data
                    // The route planner might return a different routeId variant than what has shapes
                    if shapePoints.isEmpty, let lineName = segment.lineName, !lineName.isEmpty {
                        DebugLog.log("🗺️ [DataService] Looking for fallback shape for '\(lineName)' (loaded lines: \(lines.count))")
                        let lineNames = lines.map { "\($0.name) [\($0.type.rawValue)]" }
                        DebugLog.log("🗺️ [DataService]   Available lines: \(lineNames.joined(separator: ", "))")

                        // Try multiple matching strategies:
                        // 1. Exact match (case-insensitive)
                        // 2. Without L prefix for Metro (e.g., "L1" -> "1")
                        // 3. With L prefix for Metro (e.g., "1" -> "L1")
                        let lineNameLower = lineName.lowercased()
                        let lineNameNoL = lineNameLower.hasPrefix("l") ? String(lineNameLower.dropFirst()) : lineNameLower
                        let lineNameWithL = lineNameLower.hasPrefix("l") ? lineNameLower : "l\(lineNameLower)"

                        let matchingLine = lines.first(where: { line in
                            let name = line.name.lowercased()
                            return name == lineNameLower ||
                                   name == lineNameNoL ||
                                   name == lineNameWithL
                        })

                        if let matchingLine = matchingLine,
                           let fallbackRouteId = matchingLine.routeIds.first {
                            DebugLog.log("🗺️ [DataService] Found matching line: \(matchingLine.name) with routeIds: \(matchingLine.routeIds)")
                            if fallbackRouteId != routeId {
                                DebugLog.log("🗺️ [DataService] Fallback: trying \(fallbackRouteId) instead of \(routeId)")
                                shapePoints = await fetchRouteShape(routeId: fallbackRouteId, maxGap: 100)
                            } else {
                                // Try other routeIds if available
                                if matchingLine.routeIds.count > 1 {
                                    for altRouteId in matchingLine.routeIds.dropFirst() {
                                        DebugLog.log("🗺️ [DataService] Fallback: trying alternate routeId \(altRouteId)")
                                        shapePoints = await fetchRouteShape(routeId: altRouteId, maxGap: 100)
                                        if !shapePoints.isEmpty {
                                            break
                                        }
                                    }
                                } else {
                                    DebugLog.log("🗺️ [DataService] Fallback routeId is same as original and no alternatives: \(routeId)")
                                }
                            }
                        } else {
                            DebugLog.log("🗺️ [DataService] No matching line found for '\(lineName)' (tried: \(lineNameLower), \(lineNameNoL), \(lineNameWithL))")
                        }
                    } else if shapePoints.isEmpty {
                        DebugLog.log("🗺️ [DataService] Cannot fallback: lineName is nil or empty")
                    }

                    if shapePoints.count > 2 {
                        // Convert to CLLocationCoordinate2D
                        let fullCoordinates = shapePoints.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                        }

                        // Extract only the portion between origin and destination stops
                        let segmentCoords = extractSegmentCoordinates(
                            from: fullCoordinates,
                            origin: segment.origin,
                            destination: segment.destination
                        )

                        DebugLog.log("🗺️ [DataService] Enriched segment \(segment.lineName ?? "?"): \(segment.coordinates.count) → \(segmentCoords.count) coords")

                        // Create new segment with enriched coordinates
                        let enrichedSegment = JourneySegment(
                            type: segment.type,
                            transportMode: segment.transportMode,
                            lineName: segment.lineName,
                            lineColor: segment.lineColor,
                            origin: segment.origin,
                            destination: segment.destination,
                            intermediateStops: segment.intermediateStops,
                            durationMinutes: segment.durationMinutes,
                            coordinates: segmentCoords,
                            suggestedHeading: segment.suggestedHeading,
                            departureTime: segment.departureTime,
                            arrivalTime: segment.arrivalTime,
                            instructions: segment.instructions,
                            entranceName: segment.entranceName,
                            exitName: segment.exitName,
                            platform: segment.platform,
                            platformEstimated: segment.platformEstimated
                        )
                        enrichedSegments.append(enrichedSegment)
                        continue
                    }
                }

                // For walking segments (transfers/correspondences), try to get walking shape
                if segment.type == .walking {
                    // Fetch correspondences from origin with shapes
                    let correspondences = await fetchCorrespondences(stopId: segment.origin.id, includeShape: true)

                    // Find correspondence that matches the destination
                    // Match by stop ID or by name (some stops have different IDs across systems)
                    let matchingCorrespondence = correspondences.first { corr in
                        corr.toStopId == segment.destination.id ||
                        (corr.toStopName?.lowercased() ?? "") == segment.destination.name.lowercased()
                    }

                    if let correspondence = matchingCorrespondence,
                       let walkingShape = correspondence.walkingShape,
                       walkingShape.count > 2 {
                        // Convert to CLLocationCoordinate2D
                        let walkingCoords = walkingShape.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                        }

                        DebugLog.log("🚶 [DataService] Enriched walking segment: \(segment.origin.name) → \(segment.destination.name): \(segment.coordinates.count) → \(walkingCoords.count) coords")

                        // Create new segment with walking shape coordinates
                        let enrichedSegment = JourneySegment(
                            type: segment.type,
                            transportMode: segment.transportMode,
                            lineName: segment.lineName,
                            lineColor: segment.lineColor,
                            origin: segment.origin,
                            destination: segment.destination,
                            intermediateStops: segment.intermediateStops,
                            durationMinutes: segment.durationMinutes,
                            coordinates: walkingCoords,
                            suggestedHeading: segment.suggestedHeading,
                            departureTime: segment.departureTime,
                            arrivalTime: segment.arrivalTime,
                            instructions: segment.instructions,
                            entranceName: segment.entranceName,
                            exitName: segment.exitName,
                            platform: segment.platform,
                            platformEstimated: segment.platformEstimated
                        )
                        enrichedSegments.append(enrichedSegment)
                        continue
                    } else {
                        DebugLog.log("🚶 [DataService] No walking shape for: \(segment.origin.name) → \(segment.destination.name)")
                    }
                }

                // Keep original segment (no shape available)
                enrichedSegments.append(segment)
            }

            let enrichedJourney = Journey(
                origin: journey.origin,
                destination: journey.destination,
                segments: enrichedSegments,
                totalDurationMinutes: journey.totalDurationMinutes,
                totalWalkingMinutes: journey.totalWalkingMinutes,
                transferCount: journey.transferCount
            )
            enrichedJourneys.append(enrichedJourney)
        }

        return enrichedJourneys
    }

    /// Extract the portion of route coordinates between two stops
    /// Finds the closest points to origin and destination, then returns the segment between them
    private func extractSegmentCoordinates(
        from coordinates: [CLLocationCoordinate2D],
        origin: Stop,
        destination: Stop
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 2 else { return coordinates }

        let originCoord = CLLocationCoordinate2D(latitude: origin.latitude, longitude: origin.longitude)
        let destCoord = CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)

        // Find index of closest point to origin
        var originIndex = 0
        var minOriginDist = Double.greatestFiniteMagnitude
        for (i, coord) in coordinates.enumerated() {
            let dist = distanceSquared(from: coord, to: originCoord)
            if dist < minOriginDist {
                minOriginDist = dist
                originIndex = i
            }
        }

        // Find index of closest point to destination
        var destIndex = coordinates.count - 1
        var minDestDist = Double.greatestFiniteMagnitude
        for (i, coord) in coordinates.enumerated() {
            let dist = distanceSquared(from: coord, to: destCoord)
            if dist < minDestDist {
                minDestDist = dist
                destIndex = i
            }
        }

        // Extract segment and preserve travel direction
        // If origin comes before destination in shape array, use normal order
        // If origin comes after destination, reverse the coordinates
        if originIndex <= destIndex {
            // Travel direction matches shape direction
            DebugLog.log("🗺️ [DataService] Segment direction: normal (origin idx \(originIndex) → dest idx \(destIndex))")
            return Array(coordinates[originIndex...destIndex])
        } else {
            // Travel direction is opposite to shape direction - reverse it
            DebugLog.log("🗺️ [DataService] Segment direction: REVERSED (origin idx \(originIndex) → dest idx \(destIndex))")
            return Array(coordinates[destIndex...originIndex].reversed())
        }
    }

    /// Calculate squared distance between two coordinates (faster than actual distance)
    private func distanceSquared(from c1: CLLocationCoordinate2D, to c2: CLLocationCoordinate2D) -> Double {
        let dLat = c1.latitude - c2.latitude
        let dLon = c1.longitude - c2.longitude
        return dLat * dLat + dLon * dLon
    }

    // MARK: - Network Lines Conversion

    /// Convert nested LineResponse (from /networks/{id}/lines) to flat RouteResponse
    private func convertNetworkLinesToRouteResponses(_ lines: [LineResponse], networkId: String) -> [RouteResponse] {
        var routes: [RouteResponse] = []
        
        for line in lines {
            for route in line.routes {
                let agencyId = route.agencyId ?? ""

                routes.append(RouteResponse(
                    id: route.id,
                    shortName: line.lineCode,
                    longName: route.longName,
                    routeType: 0, // Default to tram/rail (doesn't matter much for display)
                    color: route.color ?? line.color,
                    textColor: line.textColor,
                    agencyId: agencyId,
                    agencyName: route.agencyName,
                    networkId: networkId,
                    description: nil,
                    isCircular: false // Assume false for list view
                ))
            }
        }
        return routes
    }
    
}
