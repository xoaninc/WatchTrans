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

        /// Cache entry is fresh and can be used directly
        var isValid: Bool {
            Date().timeIntervalSince(timestamp) < APIConfiguration.arrivalCacheTTL
        }

        /// Cache entry is old but still within grace period (can be used as fallback)
        var isWithinGracePeriod: Bool {
            Date().timeIntervalSince(timestamp) < APIConfiguration.staleCacheGracePeriod
        }
    }

    private var arrivalCache: [String: CacheEntry] = [:]
    private let cacheLock = NSLock()

    // MARK: - Network Transport Types Cache

    /// Cache of network code -> transport type (fetched from /networks endpoint)
    /// Used to determine primary network without hardcoded ID lists
    private var networkTransportTypes: [String: String] = [:]

    // MARK: - Public Methods

    /// Initialize data - call this on app launch
    /// Pass coordinates to detect user's location and load relevant data
    func fetchTransportData(latitude: Double? = nil, longitude: Double? = nil) async {
        isLoading = true
        defer { isLoading = false }

        guard let lat = latitude, let lon = longitude else {
            DebugLog.log("⚠️ [DataService] No coordinates provided - cannot load data")
            return
        }

        DebugLog.log("📍 [DataService] ========== LOADING DATA ==========")
        DebugLog.log("📍 [DataService] Coordinates: (\(lat), \(lon))")

        // Try new coordinate-based API first, fall back to nucleo-based if needed
        do {
            // 0. Fetch networks to get transport types (only if not cached)
            // This is non-critical - if it fails, we continue without transport type info
            if networkTransportTypes.isEmpty {
                DebugLog.log("📍 [DataService] Step 0: Fetching networks for transport types...")
                do {
                    let networks = try await gtfsRealtimeService.fetchNetworks()
                    for network in networks {
                        if let transportType = network.transportType {
                            networkTransportTypes[network.code] = transportType
                        }
                    }
                    DebugLog.log("📍 [DataService] ✅ Cached \(networkTransportTypes.count) network transport types")
                } catch {
                    DebugLog.log("⚠️ [DataService] Failed to fetch networks (non-critical): \(error)")
                }
            }

            // 1. Fetch stops by coordinates (includes province detection)
            DebugLog.log("📍 [DataService] Step 1: Fetching stops by coordinates...")
            let stopResponses = try await gtfsRealtimeService.fetchStopsByCoordinates(latitude: lat, longitude: lon)
            DebugLog.log("📍 [DataService] ✅ Got \(stopResponses.count) stops")

            // Debug: Show first 3 stops with province info
            for (i, stop) in stopResponses.prefix(3).enumerated() {
                DebugLog.log("📍 [DataService]   [\(i)] \(stop.name) - province: \(stop.province ?? "nil")")
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
                    isHub: response.isHub ?? false,
                    corMetro: response.corMetro,
                    corMl: response.corMl,
                    corCercanias: response.corCercanias,
                    corTranvia: response.corTranvia
                )
            }
            DebugLog.log("📍 [DataService] ✅ Mapped \(stops.count) stops to Stop model")

            // Save hub stops for widget recommendations
            let hubStops = stops.filter { $0.isHub }.map {
                SharedStorage.SharedHubStop(stopId: $0.id, stopName: $0.name)
            }
            if !hubStops.isEmpty {
                SharedStorage.shared.saveHubStops(hubStops)
            }

            // 2. Fetch routes by coordinates
            DebugLog.log("📍 [DataService] Step 2: Fetching routes by coordinates...")
            let routeResponses = try await gtfsRealtimeService.fetchRoutesByCoordinates(latitude: lat, longitude: lon)
            DebugLog.log("📍 [DataService] ✅ Got \(routeResponses.count) routes")

            // Debug: Show networks found in routes
            let networkIds = Set(routeResponses.compactMap { $0.networkId })
            DebugLog.log("📍 [DataService] Networks in routes: \(networkIds.sorted().joined(separator: ", "))")

            // Debug: Show route breakdown by agency
            let byAgency = Dictionary(grouping: routeResponses, by: { $0.agencyId })
            for (agency, routes) in byAgency.sorted(by: { $0.key < $1.key }) {
                let shortNames = routes.map { $0.shortName }.sorted().joined(separator: ", ")
                DebugLog.log("📍 [DataService]   \(agency): \(routes.count) routes (\(shortNames.prefix(50))...)")
            }

            // Determine province name - from stops if available, otherwise detect from coordinates
            var provinceName = stopResponses.first?.province

            // If no stops returned but we have routes, try to determine province from network
            if provinceName == nil && !routeResponses.isEmpty {
                // Use network to infer province (this is a fallback)
                let networkIds = Set(routeResponses.compactMap { $0.networkId })
                provinceName = inferProvinceFromNetworks(networkIds)
                DebugLog.log("📍 [DataService] ⚠️ No stops returned, inferred province from networks: \(provinceName ?? "unknown")")
            }

            let finalProvinceName = provinceName ?? "WatchTrans"
            DebugLog.log("📍 [DataService] Step 3: Processing routes with province: \(finalProvinceName)")
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
                DebugLog.log("📍 [DataService] ✅ Location context set:")
                DebugLog.log("📍 [DataService]   Province: \(province)")
                DebugLog.log("📍 [DataService]   Primary network: \(primaryNetworkName ?? "none")")
                DebugLog.log("📍 [DataService]   Networks: \(networkCodes.sorted().joined(separator: ", "))")
            } else {
                DebugLog.log("📍 [DataService] ⚠️ Could not determine province - currentLocation is nil")
            }

            DebugLog.log("📍 [DataService] ========== LOAD COMPLETE ==========")
            DebugLog.log("📍 [DataService] Total: \(lines.count) lines, \(stops.count) stops")

        } catch {
            DebugLog.log("⚠️ [DataService] Failed to load transport data: \(error)")
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
    /// Prioritizes Cercanías/Rodalies over Metro over Tram using API transport types
    private func getPrimaryNetworkName(from networkIds: Set<String>) -> String? {
        // Use cached transport types from API to categorize networks
        let cercaniasIds = networkIds.filter { networkTransportTypes[$0] == "cercanias" }
        if let primaryId = cercaniasIds.first {
            return getNetworkName(for: primaryId)
        }
        // Then Metro/Metro Ligero
        let metroIds = networkIds.filter {
            let type = networkTransportTypes[$0]
            return type == "metro" || type == "metro_ligero"
        }
        if let metroId = metroIds.first {
            return getNetworkName(for: metroId)
        }
        // Then FGC/Euskotren
        let fgcIds = networkIds.filter {
            let type = networkTransportTypes[$0]
            return type == "fgc" || type == "euskotren"
        }
        if let fgcId = fgcIds.first {
            return getNetworkName(for: fgcId)
        }
        // Then Tram
        let tramIds = networkIds.filter { networkTransportTypes[$0] == "tranvia" }
        if let tramId = tramIds.first {
            return getNetworkName(for: tramId)
        }
        // Finally any other
        if let firstId = networkIds.first {
            return getNetworkName(for: firstId)
        }
        return nil
    }

    /// Process route responses into Line models
    private func processRoutes(_ routeResponses: [RouteResponse], provinceName: String) async {
        DebugLog.log("🚃 [ProcessRoutes] Processing \(routeResponses.count) routes for province: \(provinceName)")

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
        DebugLog.log("🚃 [ProcessRoutes] ✅ Created \(lines.count) lines:")
        for (type, typeLines) in byType.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let names = typeLines.map { $0.name }.sorted().joined(separator: ", ")
            DebugLog.log("🚃 [ProcessRoutes]   \(type.rawValue): \(typeLines.count) lines (\(names))")
        }
    }

    /// Fetch stops for a specific route
    func fetchStopsForRoute(routeId: String) async -> [Stop] {
        do {
            let stopResponses = try await gtfsRealtimeService.fetchRouteStops(routeId: routeId)
            DebugLog.log("🚏 [DataService] Fetched \(stopResponses.count) stops for route \(routeId)")
            return stopResponses.map { response in
                // DEBUG: Log correspondences - especially branch junction stations
                let isBranchJunction = response.name.lowercased().contains("metropolitano") ||
                                       response.name.lowercased().contains("arganda") ||
                                       response.name.lowercased().contains("tres olivos")
                if isBranchJunction || (response.corMetro != nil && response.corMetro!.contains("B")) {
                    DebugLog.log("🔗 [BRANCH] Stop '\(response.name)' correspondences:")
                    DebugLog.log("🔗 [BRANCH]   metro=\(response.corMetro ?? "nil")")
                    DebugLog.log("🔗 [BRANCH]   ml=\(response.corMl ?? "nil")")
                    DebugLog.log("🔗 [BRANCH]   cerc=\(response.corCercanias ?? "nil")")
                } else if response.corMetro != nil || response.corCercanias != nil || response.corTranvia != nil || response.corMl != nil {
                    DebugLog.log("🔗 [DataService] Stop '\(response.name)' has correspondences: metro=\(response.corMetro ?? "nil"), cerc=\(response.corCercanias ?? "nil"), tram=\(response.corTranvia ?? "nil"), ml=\(response.corMl ?? "nil")")
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
                    isHub: response.isHub ?? false,
                    corMetro: response.corMetro,
                    corMl: response.corMl,
                    corCercanias: response.corCercanias,
                    corTranvia: response.corTranvia
                )
            }
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch stops for route \(routeId): \(error)")
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
        DebugLog.log("📅 [HOURS] Fetching for \(routeId), dayType=\(dayType) (\(dayName))")

        // Try frequencies first (Metro/ML/Tranvía)
        do {
            let frequencies = try await gtfsRealtimeService.fetchFrequencies(routeId: routeId)

            if !frequencies.isEmpty {
                // DEBUG: Log all day types returned by API
                let dayTypes = Set(frequencies.map { $0.dayType })
                DebugLog.log("📅 [HOURS] API returned day types: \(dayTypes.sorted())")

                // Filter by current day type
                let todayFrequencies = frequencies.filter { $0.dayType == dayType }
                DebugLog.log("📅 [HOURS] Matched \(todayFrequencies.count) frequencies for '\(dayType)'")

                if !todayFrequencies.isEmpty {
                    let result = calculateOperatingHours(from: todayFrequencies)
                    DebugLog.log("📅 [HOURS] ✅ From frequencies (\(dayType)): \(result)")
                    return .hours(result)
                }

                // Fallback chain: friday → weekday → any
                let fallbackOrder = ["friday", "weekday", "saturday", "sunday"]
                for fallback in fallbackOrder where fallback != dayType {
                    let fallbackFrequencies = frequencies.filter { $0.dayType == fallback }
                    if !fallbackFrequencies.isEmpty {
                        let result = calculateOperatingHours(from: fallbackFrequencies)
                        DebugLog.log("📅 [HOURS] ✅ From frequencies (\(fallback) fallback): \(result)")
                        return .hours(result)
                    }
                }
            }
        } catch {
            DebugLog.log("📅 [HOURS] Frequencies failed, trying operating-hours...")
        }

        // Try operating-hours (Cercanías - from stop_times)
        do {
            let hours = try await gtfsRealtimeService.fetchRouteOperatingHours(routeId: routeId)

            // Check for suspended service first
            if hours.isSuspended == true {
                DebugLog.log("📅 [HOURS] ⚠️ Service SUSPENDED for \(routeId): \(hours.suspensionMessage ?? "No message")")
                return .suspended(message: hours.suspensionMessage)
            }

            // DEBUG: Log RAW API response
            DebugLog.log("📅 [HOURS] RAW API response for \(routeId):")
            if let wd = hours.weekday {
                DebugLog.log("📅 [HOURS]   weekday: first=\(wd.firstDeparture), last=\(wd.lastDeparture), trips=\(wd.totalTrips)")
            }
            if let sat = hours.saturday {
                DebugLog.log("📅 [HOURS]   saturday: first=\(sat.firstDeparture), last=\(sat.lastDeparture)")
            }
            if let sun = hours.sunday {
                DebugLog.log("📅 [HOURS]   sunday: first=\(sun.firstDeparture), last=\(sun.lastDeparture)")
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
                DebugLog.log("📅 [HOURS] ✅ From operating-hours (\(dayType)): \(result)")
                return .hours(result)
            }
        } catch {
            DebugLog.log("📅 [HOURS] ❌ Both endpoints failed for \(routeId): \(error)")
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

    // Fetch arrivals for a specific stop using RenfeServer API
    func fetchArrivals(for stopId: String) async -> [Arrival] {
        DebugLog.log("🔍 [DataService] Fetching arrivals for stop: \(stopId)")

        // 1. Check cache first
        if let cached = getCachedArrivals(for: stopId) {
            DebugLog.log("✅ [DataService] Cache hit! Returning \(cached.count) cached arrivals")
            return cached
        }

        // 2. Fetch from RenfeServer API (redcercanias.com)
        do {
            DebugLog.log("📡 [DataService] Cache miss, calling RenfeServer API...")
            let departures = try await gtfsRealtimeService.fetchDepartures(stopId: stopId, limit: 10)
            DebugLog.log("📊 [DataService] API returned \(departures.count) departures for stop \(stopId)")

            let arrivals = gtfsMapper.mapToArrivals(departures: departures, stopId: stopId)
            DebugLog.log("✅ [DataService] Mapped to \(arrivals.count) arrivals")

            // 3. Cache results
            cacheArrivals(arrivals, for: stopId)

            return arrivals
        } catch {
            // 4. Handle errors gracefully
            DebugLog.log("⚠️ [DataService] RenfeServer API Error: \(error)")

            // Try stale cache as fallback
            if let stale = getStaleCachedArrivals(for: stopId) {
                DebugLog.log("ℹ️ [DataService] Using stale cached data for stop \(stopId)")
                return stale
            }

            // Return empty array instead of mock data
            DebugLog.log("ℹ️ [DataService] No data available for stop \(stopId)")
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

        guard let entry = arrivalCache[stopId], entry.isWithinGracePeriod else {
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
        DebugLog.log("❌ [getLine] NOT FOUND '\(id)'. Available: \(lines.map { $0.name }.sorted().joined(separator: ", "))")
        return nil
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
                    connectionLineIds: response.lineIds,
                    province: response.province,
                    accesibilidad: response.accesibilidad,
                    hasParking: response.parkingBicis != nil && response.parkingBicis != "0",
                    hasBusConnection: response.corBus != nil && response.corBus != "0",
                    hasMetroConnection: response.corMetro != nil && response.corMetro != "0",
                    isHub: response.isHub ?? false,
                    corMetro: response.corMetro,
                    corMl: response.corMl,
                    corCercanias: response.corCercanias,
                    corTranvia: response.corTranvia
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
        // Define transport network regions (provinces that share transport networks)
        // Note: Andalucía provinces are separated to avoid showing distant stations
        let networkRegions: [[String]] = [
            // Cataluña (Rodalies, FGC, TMB)
            ["Barcelona", "Tarragona", "Lleida", "Girona"],
            // Madrid (Cercanías Madrid, Metro Madrid)
            ["Madrid"],
            // País Vasco (Euskotren, Metro Bilbao, Cercanías Bilbao)
            ["Vizcaya", "Guipúzcoa", "Álava", "Bizkaia", "Gipuzkoa", "Araba"],
            // Valencia (Metrovalencia, Cercanías Valencia)
            ["Valencia", "Alicante", "Castellón", "Castelló"],
            // Andalucía - Separated by province to avoid distant stations
            ["Sevilla"],
            ["Málaga"],
            ["Cádiz"],
            ["Granada"],
            // Asturias
            ["Asturias"],
            // Galicia
            ["A Coruña", "Pontevedra", "Lugo", "Ourense"],
            // Murcia
            ["Murcia"],
            // Zaragoza
            ["Zaragoza"],
            // Cantabria
            ["Cantabria"],
            // Mallorca
            ["Illes Balears", "Islas Baleares", "Mallorca"],
        ]

        // Find which region this province belongs to
        for region in networkRegions {
            if region.contains(province) {
                return Set(region)
            }
        }

        // If not found in any region, just return the province itself
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
        do {
            // Use direct endpoint instead of fetching all + filtering
            let alerts = try await gtfsRealtimeService.fetchAlertsForStop(stopId: stopId)
            DebugLog.log("✅ [DataService] Fetched \(alerts.count) alerts for stop \(stopId)")
            return alerts
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch alerts for stop \(stopId): \(error)")
            return []
        }
    }

    /// Fetch alerts for a specific route
    func fetchAlertsForRoute(routeId: String) async -> [AlertResponse] {
        do {
            let alerts = try await gtfsRealtimeService.fetchAlertsForRoute(routeId: routeId)
            DebugLog.log("✅ [DataService] Fetched \(alerts.count) alerts for route \(routeId)")
            return alerts
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch alerts for route \(routeId): \(error)")
            return []
        }
    }

    /// Fetch alerts for a line using the route-specific endpoint
    func fetchAlertsForLine(_ line: Line) async -> [AlertResponse] {
        // Use the first routeId to fetch alerts via the new endpoint
        guard let routeId = line.routeIds.first else {
            DebugLog.log("⚠️ [Alerts] No routeId for line \(line.name)")
            return []
        }

        DebugLog.log("🔔 [Alerts] Fetching alerts for line \(line.name) via route \(routeId)")
        return await fetchAlertsForRoute(routeId: routeId)
    }

    // MARK: - Platforms & Correspondences

    /// Fetch platform coordinates for a station
    /// Returns the exact position of each platform/line within the station
    func fetchPlatforms(stopId: String) async -> [PlatformInfo] {
        do {
            let response = try await gtfsRealtimeService.fetchPlatforms(stopId: stopId)
            DebugLog.log("🚏 [DataService] Fetched \(response.platforms.count) platforms for \(stopId)")
            return response.platforms
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch platforms for \(stopId): \(error)")
            return []
        }
    }

    /// Fetch walking correspondences from a station
    /// Returns nearby stations connected by walking passages (e.g., underground tunnels)
    func fetchCorrespondences(stopId: String) async -> [CorrespondenceInfo] {
        do {
            let response = try await gtfsRealtimeService.fetchCorrespondences(stopId: stopId)
            DebugLog.log("🚶 [DataService] Fetched \(response.correspondences.count) correspondences for \(stopId)")
            return response.correspondences
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch correspondences for \(stopId): \(error)")
            return []
        }
    }

    // MARK: - Route Shapes

    /// Fetch shape (polyline) for a route
    /// Returns array of shape points to draw the route on a map
    func fetchRouteShape(routeId: String) async -> [ShapePoint] {
        do {
            let response = try await gtfsRealtimeService.fetchRouteShape(routeId: routeId)
            DebugLog.log("🗺️ [DataService] Fetched \(response.shape.count) shape points for \(routeId)")
            return response.shape.sorted { $0.sequence < $1.sequence }
        } catch {
            DebugLog.log("⚠️ [DataService] Failed to fetch shape for \(routeId): \(error)")
            return []
        }
    }

}
