//
//  DataService.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//
//  UPDATED: 2026-01-16 - Now loads ALL data from RenfeServer API (redcercanias.com)
//

import Foundation

/// Current location context - holds network/province info for the user's location
struct LocationContext {
    let provinceName: String
    let networks: [NetworkInfo]
    let primaryNetworkName: String?  // e.g., "Rodalies de Catalunya", "Cercanías Madrid"

    /// Display name for the title bar
    var displayName: String {
        // Use province name as display (e.g., "Barcelona", "Madrid", "Sevilla")
        provinceName
    }

    /// Check if this is a Rodalies de Catalunya network
    var isRodalies: Bool {
        primaryNetworkName?.lowercased().contains("rodalies") == true ||
        networks.contains { $0.code == "51T" }
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
    var currentLocation: LocationContext?
    var isLoading = false
    var error: Error?

    // MARK: - GTFS-Realtime Services

    private let networkService: NetworkService
    private let gtfsRealtimeService: GTFSRealtimeService
    @ObservationIgnored private lazy var gtfsMapper = GTFSRealtimeMapper(dataService: self)

    // MARK: - Initialization

    init() {
        self.networkService = NetworkService()
        self.gtfsRealtimeService = GTFSRealtimeService(networkService: networkService)
    }

    // MARK: - Arrival Cache

    private struct CacheEntry {
        let arrivals: [Arrival]
        let timestamp: Date

        var isValid: Bool {
            Date().timeIntervalSince(timestamp) < APIConfiguration.arrivalCacheTTL
        }

        var isStale: Bool {
            Date().timeIntervalSince(timestamp) < APIConfiguration.staleCacheGracePeriod
        }
    }

    private var arrivalCache: [String: CacheEntry] = [:]
    private let cacheLock = NSLock()

    // MARK: - Public Methods

    /// Initialize data - call this on app launch
    /// Pass coordinates to detect user's location and load relevant data
    func fetchTransportData(latitude: Double? = nil, longitude: Double? = nil) async {
        isLoading = true
        defer { isLoading = false }

        guard let lat = latitude, let lon = longitude else {
            print("⚠️ [DataService] No coordinates provided - cannot load data")
            return
        }

        print("📍 [DataService] ========== LOADING DATA ==========")
        print("📍 [DataService] Coordinates: (\(lat), \(lon))")

        // Try new coordinate-based API first, fall back to nucleo-based if needed
        do {
            // 1. Fetch stops by coordinates (includes province detection)
            print("📍 [DataService] Step 1: Fetching stops by coordinates...")
            let stopResponses = try await gtfsRealtimeService.fetchStopsByCoordinates(latitude: lat, longitude: lon)
            print("📍 [DataService] ✅ Got \(stopResponses.count) stops")

            // Debug: Show first 3 stops with province info
            for (i, stop) in stopResponses.prefix(3).enumerated() {
                print("📍 [DataService]   [\(i)] \(stop.name) - province: \(stop.province ?? "nil")")
            }

            stops = stopResponses.map { response in
                Stop(
                    id: response.id,
                    name: response.name,
                    latitude: response.lat,
                    longitude: response.lon,
                    connectionLineIds: response.lineIds,
                    province: response.province,
                    accesibilidad: response.accesibilidad,
                    hasParking: response.parkingBicis != nil && response.parkingBicis != "0",
                    hasBusConnection: response.corBus != nil && response.corBus != "0",
                    hasMetroConnection: response.corMetro != nil && response.corMetro != "0",
                    corMetro: response.corMetro,
                    corMl: response.corMl,
                    corCercanias: response.corCercanias,
                    corTranvia: response.corTranvia
                )
            }
            print("📍 [DataService] ✅ Mapped \(stops.count) stops to Stop model")

            // 2. Fetch routes by coordinates
            print("📍 [DataService] Step 2: Fetching routes by coordinates...")
            let routeResponses = try await gtfsRealtimeService.fetchRoutesByCoordinates(latitude: lat, longitude: lon)
            print("📍 [DataService] ✅ Got \(routeResponses.count) routes")

            // Debug: Show networks found in routes
            let networkIds = Set(routeResponses.compactMap { $0.networkId })
            print("📍 [DataService] Networks in routes: \(networkIds.sorted().joined(separator: ", "))")

            // Debug: Show route breakdown by agency
            let byAgency = Dictionary(grouping: routeResponses, by: { $0.agencyId })
            for (agency, routes) in byAgency.sorted(by: { $0.key < $1.key }) {
                let shortNames = routes.map { $0.shortName }.sorted().joined(separator: ", ")
                print("📍 [DataService]   \(agency): \(routes.count) routes (\(shortNames.prefix(50))...)")
            }

            // Determine province name - from stops if available, otherwise detect from coordinates
            var provinceName = stopResponses.first?.province

            // If no stops returned but we have routes, try to determine province from network
            if provinceName == nil && !routeResponses.isEmpty {
                // Use network to infer province (this is a fallback)
                let networkIds = Set(routeResponses.compactMap { $0.networkId })
                provinceName = inferProvinceFromNetworks(networkIds)
                print("📍 [DataService] ⚠️ No stops returned, inferred province from networks: \(provinceName ?? "unknown")")
            }

            let finalProvinceName = provinceName ?? "WatchTrans"
            print("📍 [DataService] Step 3: Processing routes with province: \(finalProvinceName)")
            await processRoutes(routeResponses, provinceName: finalProvinceName)

            // 3. Set current location context
            let networkCodes = Set(routeResponses.compactMap { $0.networkId })
            let networks = networkCodes.map { NetworkInfo(code: $0, name: getNetworkName(for: $0)) }
            let primaryNetworkName = getPrimaryNetworkName(from: networkCodes)

            if let province = provinceName {
                currentLocation = LocationContext(
                    provinceName: province,
                    networks: networks,
                    primaryNetworkName: primaryNetworkName
                )
                print("📍 [DataService] ✅ Location context set:")
                print("📍 [DataService]   Province: \(province)")
                print("📍 [DataService]   Primary network: \(primaryNetworkName ?? "none")")
                print("📍 [DataService]   Networks: \(networkCodes.sorted().joined(separator: ", "))")
            } else {
                print("📍 [DataService] ⚠️ Could not determine province - currentLocation is nil")
            }

            print("📍 [DataService] ========== LOAD COMPLETE ==========")
            print("📍 [DataService] Total: \(lines.count) lines, \(stops.count) stops")

        } catch {
            print("⚠️ [DataService] Failed to load transport data: \(error)")
            self.error = error
        }
    }

    /// Infer province name from network IDs (fallback when stops don't return province)
    private func inferProvinceFromNetworks(_ networkIds: Set<String>) -> String? {
        // Map network IDs to provinces
        for networkId in networkIds {
            switch networkId {
            case "51T": return "Barcelona"  // Rodalies de Catalunya
            case "TMB_METRO": return "Barcelona"
            case "FGC": return "Barcelona"
            case "TRAM_BCN", "TRAM_BARCELONA_1", "TRAM_BARCELONA_BESOS_2": return "Barcelona"
            case "10T": return "Madrid"  // Cercanías Madrid
            case "11T": return "Madrid"  // Metro Madrid
            case "12T": return "Madrid"  // Metro Ligero
            case "30T": return "Sevilla"
            case "32T": return "Sevilla"  // Metro Sevilla
            case "40T": return "Valencia"
            case "METRO_VALENCIA": return "Valencia"
            case "60T": return "Vizcaya"  // Bilbao
            case "METRO_BILBAO": return "Vizcaya"
            case "EUSKOTREN": return "Vizcaya"
            case "70T": return "Zaragoza"
            case "TRANVIA_ZARAGOZA": return "Zaragoza"
            default: continue
            }
        }
        return nil
    }

    /// Get human-readable network name from network ID
    /// This mapping matches the API /networks endpoint
    private func getNetworkName(for networkId: String) -> String {
        switch networkId {
        // Cercanías RENFE networks
        case "10T": return "Cercanías Madrid"
        case "20T": return "Cercanías Asturias"
        case "30T": return "Cercanías Sevilla"
        case "31T": return "Cercanías Cádiz"
        case "40T": return "Cercanías Valencia"
        case "41T": return "Cercanías Murcia/Alicante"
        case "50T": return "Cercanías Málaga"
        case "51T": return "Rodalies de Catalunya"
        case "60T": return "Cercanías Bilbao"
        case "61T": return "Cercanías San Sebastián"
        case "62T": return "Cercanías Santander"
        case "70T": return "Cercanías Zaragoza"
        // Metro networks
        case "11T", "METRO_MADRID": return "Metro Madrid"
        case "12T", "METRO_LIGERO": return "Metro Ligero Madrid"
        case "32T", "METRO_SEVILLA": return "Metro Sevilla"
        case "TMB_METRO": return "Metro Barcelona"
        case "METRO_VALENCIA": return "Metrovalencia"
        case "METRO_BILBAO": return "Metro Bilbao"
        case "METRO_MALAGA": return "Metro Málaga"
        case "METRO_GRANADA": return "Metro Granada"
        // Other networks
        case "FGC": return "Ferrocarrils de la Generalitat"
        case "EUSKOTREN": return "Euskotren"
        case "SFM_MALLORCA": return "Serveis Ferroviaris de Mallorca"
        case "TRAM_BCN", "TRAM_BARCELONA_1", "TRAM_BARCELONA_BESOS_2": return "Tram Barcelona"
        case "TRANVIA_ZARAGOZA": return "Tranvía Zaragoza"
        case "TRANVIA_TENERIFE": return "Tranvía Tenerife"
        case "TRAM_ALICANTE": return "TRAM Alicante"
        case "TRANVIA_MURCIA": return "Tranvía Murcia"
        default: return networkId
        }
    }

    /// Get the primary (most relevant) network name from a set of network IDs
    /// Prioritizes Cercanías/Rodalies over Metro over Tram
    private func getPrimaryNetworkName(from networkIds: Set<String>) -> String? {
        // Priority order: Cercanías/Rodalies first (most important for commuters)
        let cercaniasIds = networkIds.filter { $0.hasSuffix("T") && !["11T", "12T", "32T"].contains($0) }
        if let primaryId = cercaniasIds.first {
            return getNetworkName(for: primaryId)
        }
        // Then Metro
        let metroIds = networkIds.filter { $0.contains("METRO") || ["11T", "12T", "32T"].contains($0) || $0 == "TMB_METRO" }
        if let metroId = metroIds.first {
            return getNetworkName(for: metroId)
        }
        // Then FGC/Euskotren
        if networkIds.contains("FGC") { return getNetworkName(for: "FGC") }
        if networkIds.contains("EUSKOTREN") { return getNetworkName(for: "EUSKOTREN") }
        // Finally any other
        if let firstId = networkIds.first {
            return getNetworkName(for: firstId)
        }
        return nil
    }

    /// Process route responses into Line models
    private func processRoutes(_ routeResponses: [RouteResponse], provinceName: String) async {
        print("🚃 [ProcessRoutes] Processing \(routeResponses.count) routes for province: \(provinceName)")

        // Group routes by short name to create lines, collecting all route IDs
        var lineDict: [String: (line: Line, routeIds: [String], longName: String)] = [:]

        // Default color
        let defaultColor = "#75B6E0"

        for route in routeResponses {
            // Create unique ID per agency to separate Metro L1 from Cercanías C1
            let transportType = TransportType.from(agencyId: route.agencyId)
            let lineId = "\(route.agencyId)_\(route.shortName.lowercased())"

            if var existing = lineDict[lineId] {
                existing.routeIds.append(route.id)
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

                let line = Line(
                    id: lineId,
                    name: displayName,
                    longName: route.longName,
                    type: transportType,
                    colorHex: color,
                    nucleo: provinceName,
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

        // Debug: Show lines by type
        let byType = Dictionary(grouping: lines, by: { $0.type })
        print("🚃 [ProcessRoutes] ✅ Created \(lines.count) lines:")
        for (type, typeLines) in byType.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let names = typeLines.map { $0.name }.sorted().joined(separator: ", ")
            print("🚃 [ProcessRoutes]   \(type.rawValue): \(typeLines.count) lines (\(names))")
        }
    }

    /// Fetch stops for a specific route
    func fetchStopsForRoute(routeId: String) async -> [Stop] {
        do {
            let stopResponses = try await gtfsRealtimeService.fetchRouteStops(routeId: routeId)
            print("🚏 [DataService] Fetched \(stopResponses.count) stops for route \(routeId)")
            return stopResponses.map { response in
                // DEBUG: Log correspondences - especially branch junction stations
                let isBranchJunction = response.name.lowercased().contains("metropolitano") ||
                                       response.name.lowercased().contains("arganda") ||
                                       response.name.lowercased().contains("tres olivos")
                if isBranchJunction || (response.corMetro != nil && response.corMetro!.contains("B")) {
                    print("🔗 [BRANCH] Stop '\(response.name)' correspondences:")
                    print("🔗 [BRANCH]   metro=\(response.corMetro ?? "nil")")
                    print("🔗 [BRANCH]   ml=\(response.corMl ?? "nil")")
                    print("🔗 [BRANCH]   cerc=\(response.corCercanias ?? "nil")")
                } else if response.corMetro != nil || response.corCercanias != nil || response.corTranvia != nil || response.corMl != nil {
                    print("🔗 [DataService] Stop '\(response.name)' has correspondences: metro=\(response.corMetro ?? "nil"), cerc=\(response.corCercanias ?? "nil"), tram=\(response.corTranvia ?? "nil"), ml=\(response.corMl ?? "nil")")
                }
                return Stop(
                    id: response.id,
                    name: response.name,
                    latitude: response.lat,
                    longitude: response.lon,
                    connectionLineIds: response.lineIds,  // Parse from "lineas" field
                    province: response.province,
                    accesibilidad: response.accesibilidad,
                    hasParking: response.parkingBicis != nil && response.parkingBicis != "0",
                    hasBusConnection: response.corBus != nil && response.corBus != "0",
                    hasMetroConnection: response.corMetro != nil && response.corMetro != "0",
                    corMetro: response.corMetro,
                    corMl: response.corMl,
                    corCercanias: response.corCercanias,
                    corTranvia: response.corTranvia
                )
            }
        } catch {
            print("⚠️ [DataService] Failed to fetch stops for route \(routeId): \(error)")
            return []
        }
    }

    /// Fetch operating hours for a route (all types)
    /// - Metro/ML/Tranvía: uses /frequencies endpoint
    /// - Cercanías: uses /operating-hours endpoint (from stop_times)
    func fetchOperatingHours(routeId: String) async -> OperatingHoursResult {
        // Determine current day type (weekday=L-J, friday=V, saturday=S, sunday=D)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
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
            dayName = "L-J (weekday \(weekday))"
        }
        print("📅 [HOURS] Fetching for \(routeId), dayType=\(dayType) (\(dayName))")

        // Try frequencies first (Metro/ML/Tranvía)
        do {
            let frequencies = try await gtfsRealtimeService.fetchFrequencies(routeId: routeId)

            if !frequencies.isEmpty {
                // DEBUG: Log all day types returned by API
                let dayTypes = Set(frequencies.map { $0.dayType })
                print("📅 [HOURS] API returned day types: \(dayTypes.sorted())")

                // Filter by current day type
                let todayFrequencies = frequencies.filter { $0.dayType == dayType }
                print("📅 [HOURS] Matched \(todayFrequencies.count) frequencies for '\(dayType)'")

                if !todayFrequencies.isEmpty {
                    let result = calculateOperatingHours(from: todayFrequencies)
                    print("📅 [HOURS] ✅ From frequencies (\(dayType)): \(result)")
                    return .hours(result)
                }

                // Fallback chain: friday → weekday → any
                let fallbackOrder = ["friday", "weekday", "saturday", "sunday"]
                for fallback in fallbackOrder where fallback != dayType {
                    let fallbackFrequencies = frequencies.filter { $0.dayType == fallback }
                    if !fallbackFrequencies.isEmpty {
                        let result = calculateOperatingHours(from: fallbackFrequencies)
                        print("📅 [HOURS] ✅ From frequencies (\(fallback) fallback): \(result)")
                        return .hours(result)
                    }
                }
            }
        } catch {
            print("📅 [HOURS] Frequencies failed, trying operating-hours...")
        }

        // Try operating-hours (Cercanías - from stop_times)
        do {
            let hours = try await gtfsRealtimeService.fetchRouteOperatingHours(routeId: routeId)

            // Check for suspended service first
            if hours.isSuspended == true {
                print("📅 [HOURS] ⚠️ Service SUSPENDED for \(routeId): \(hours.suspensionMessage ?? "No message")")
                return .suspended(message: hours.suspensionMessage)
            }

            // DEBUG: Log RAW API response
            print("📅 [HOURS] RAW API response for \(routeId):")
            if let wd = hours.weekday {
                print("📅 [HOURS]   weekday: first=\(wd.firstDeparture), last=\(wd.lastDeparture), trips=\(wd.totalTrips)")
            }
            if let sat = hours.saturday {
                print("📅 [HOURS]   saturday: first=\(sat.firstDeparture), last=\(sat.lastDeparture)")
            }
            if let sun = hours.sunday {
                print("📅 [HOURS]   sunday: first=\(sun.firstDeparture), last=\(sun.lastDeparture)")
            }

            // Select the appropriate day
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
                print("📅 [HOURS] ✅ From operating-hours (\(dayType)): \(result)")
                return .hours(result)
            }
        } catch {
            print("📅 [HOURS] ❌ Both endpoints failed for \(routeId): \(error)")
        }

        print("📅 [HOURS] ❌ No hours found for \(routeId)")
        return .hours(nil)
    }

    /// Calculate operating hours string from frequency responses
    private func calculateOperatingHours(from frequencies: [FrequencyResponse]) -> String {
        // Separate morning service (starts >= 04:00) from late-night service (starts < 04:00)
        // Late-night service (e.g., 00:00-01:30) runs AFTER midnight, not at opening
        let morningThreshold = 4 * 60  // 04:00 in minutes

        let morningStarts = frequencies.compactMap { parseTimeToMinutes($0.startTime) }
            .filter { $0 >= morningThreshold }
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
        print("📅 [HOURS] Raw start times: \(rawStartTimes)")
        print("📅 [HOURS] Raw end times: \(rawEndTimes)")
        print("📅 [HOURS] Opening (morning): \(openingTime / 60):\(String(format: "%02d", openingTime % 60))")
        print("📅 [HOURS] maxEnd (minutes): \(maxEnd) = \(maxEnd / 60)h \(maxEnd % 60)m")

        let startStr = formatMinutesToTime(openingTime)
        // Handle times > 24:00 (e.g., 25:30:00 = 01:30 next day)
        let endStr = formatMinutesToTime(maxEnd % (24 * 60))

        // DEBUG: Log conversion if time was > 24:00
        if maxEnd >= 24 * 60 {
            print("📅 [HOURS] GTFS time >24h: \(maxEnd / 60):\(String(format: "%02d", maxEnd % 60)) → \(endStr)")
        }

        print("📅 [DataService] Operating hours: \(startStr) - \(endStr)")
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
    // Also handles branch lines: "7b" -> "L7B", "9b" -> "L9B", "10b" -> "L10B"
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

        // For Metro branch lines: "7b" -> "L7B", "9b" -> "L9B", "10b" -> "L10B"
        // Check if it ends with 'b' and starts with a number
        if lowerId.hasSuffix("b") && lowerId.first?.isNumber == true {
            let metroName = "l\(lowerId)"  // "7b" -> "l7b"
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

        // Debug: log only when not found
        print("❌ [getLine] NOT FOUND '\(id)'. Available: \(lines.map { $0.name }.sorted().joined(separator: ", "))")
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
                    accesibilidad: response.accesibilidad,
                    hasParking: response.parkingBicis != nil && response.parkingBicis != "0",
                    hasBusConnection: response.corBus != nil && response.corBus != "0",
                    hasMetroConnection: response.corMetro != nil && response.corMetro != "0",
                    corMetro: response.corMetro,
                    corMl: response.corMl,
                    corCercanias: response.corCercanias,
                    corTranvia: response.corTranvia
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

    /// Fetch alerts for a specific stop (uses direct endpoint for efficiency)
    func fetchAlertsForStop(stopId: String) async -> [AlertResponse] {
        do {
            // Use direct endpoint instead of fetching all + filtering
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

    /// Fetch alerts for a line using the route-specific endpoint
    func fetchAlertsForLine(_ line: Line) async -> [AlertResponse] {
        // Use the first routeId to fetch alerts via the new endpoint
        guard let routeId = line.routeIds.first else {
            print("⚠️ [Alerts] No routeId for line \(line.name)")
            return []
        }

        print("🔔 [Alerts] Fetching alerts for line \(line.name) via route \(routeId)")
        return await fetchAlertsForRoute(routeId: routeId)
    }

}
