//
//  WatchTransWidget.swift
//  WatchTransWidget
//
//  Created by Juan Macias Gomez on 14/1/26.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget API Configuration
// NOTE: Keep in sync with APIConfiguration.swift in main app

enum WidgetAPIConfig {
    static let baseURL = "https://redcercanias.com/api/v1/gtfs"
    static let refreshInterval: TimeInterval = 150  // 2.5 minutes
    static let requestTimeout: TimeInterval = 10
    static let resourceTimeout: TimeInterval = 15
    static let nearestStopTimeout: TimeInterval = 5
}

// MARK: - Debug Logging (Widget-local copy)
enum DebugLog {
    static var isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    static func log(_ message: String) {
        guard isEnabled else { return }
        print(message)
    }
}

// MARK: - Timeline Entry

struct ArrivalEntry: TimelineEntry {
    let date: Date
    let lineName: String
    let destination: String
    let minutesUntilArrival: Int
    let isDelayed: Bool
    let lineColor: String // Hex color
    let stopName: String? // Name of the stop (for display)

    init(date: Date, lineName: String, destination: String, minutesUntilArrival: Int, isDelayed: Bool, lineColor: String, stopName: String? = nil) {
        self.date = date
        self.lineName = lineName
        self.destination = destination
        self.minutesUntilArrival = minutesUntilArrival
        self.isDelayed = isDelayed
        self.lineColor = lineColor
        self.stopName = stopName
    }
}

// MARK: - Timeline Provider (Configurable)

struct ArrivalProvider: AppIntentTimelineProvider {
    // API Configuration - must match APIConfiguration.swift in main app
    private let apiBaseURL = WidgetAPIConfig.baseURL
    // Refresh interval: 2.5 minutes (150 seconds)
    private let refreshIntervalSeconds: TimeInterval = WidgetAPIConfig.refreshInterval

    // Recommendations for widget gallery - reads user's favorites from shared storage
    func recommendations() -> [AppIntentRecommendation<SelectStopIntent>] {
        // Try to get user's favorites from shared storage
        let favorites = SharedStorage.shared.getFavorites()

        if !favorites.isEmpty {
            // Use user's favorites as recommendations
            return favorites.map { favorite in
                let intent = SelectStopIntent(stop: StopEntity(id: favorite.stopId, name: favorite.stopName))
                return AppIntentRecommendation(intent: intent, description: favorite.stopName)
            }
        }

        // Try to get cached hub stops from shared storage
        let cachedHubs = SharedStorage.shared.getHubStops()
        if !cachedHubs.isEmpty {
            return cachedHubs.prefix(3).map { hub in
                let intent = SelectStopIntent(stop: StopEntity(id: hub.stopId, name: hub.stopName))
                return AppIntentRecommendation(intent: intent, description: hub.stopName)
            }
        }

        // Ultimate fallback: Default recommendations with major hub stations
        let defaultStops = [
            ("RENFE_18000", "Atocha RENFE"),
            ("RENFE_17000", "Chamartín RENFE"),
            ("RENFE_71801", "Barcelona-Sants")
        ]

        return defaultStops.map { (id, name) in
            let intent = SelectStopIntent(stop: StopEntity(id: id, name: name))
            return AppIntentRecommendation(intent: intent, description: name)
        }
    }

    func placeholder(in context: Context) -> ArrivalEntry {
        ArrivalEntry(
            date: Date(),
            lineName: "C3",
            destination: "Aranjuez",
            minutesUntilArrival: 5,
            isDelayed: false,
            lineColor: "#813380"
        )
    }

    func snapshot(for configuration: SelectStopIntent, in context: Context) async -> ArrivalEntry {
        // For preview in widget gallery, use placeholder
        if context.isPreview {
            return ArrivalEntry(
                date: Date(),
                lineName: "C3",
                destination: "Aranjuez",
                minutesUntilArrival: 5,
                isDelayed: false,
                lineColor: "#813380"
            )
        }

        // Otherwise try to fetch real data
        do {
            let departures = try await fetchDepartures(for: configuration)
            if let first = departures.first {
                return ArrivalEntry(
                    date: Date(),
                    lineName: first.routeShortName,
                    destination: first.headsign ?? "Unknown",
                    minutesUntilArrival: first.minutesUntil,
                    isDelayed: first.isDelayed,
                    lineColor: first.routeColor ?? "#75B6E0"
                )
            }
        } catch {
            DebugLog.log("⚠️ [Widget Snapshot] Error: \(error)")
        }

        // Fallback to placeholder
        return ArrivalEntry(
            date: Date(),
            lineName: "---",
            destination: "No data",
            minutesUntilArrival: 0,
            isDelayed: false,
            lineColor: "#808080"
        )
    }

    func timeline(for configuration: SelectStopIntent, in context: Context) async -> Timeline<ArrivalEntry> {
        do {
            let departures = try await fetchDepartures(for: configuration)
            let entries = createEntries(from: departures)

            // Update every 2.5 minutes
            let nextUpdate = Date().addingTimeInterval(refreshIntervalSeconds)
            return Timeline(entries: entries, policy: .after(nextUpdate))
        } catch {
            // On error, show error info and retry in 30 seconds
            DebugLog.log("⚠️ [Widget] Failed to fetch: \(error)")
            let errorMessage = String(describing: error).prefix(20)
            let fallbackEntry = ArrivalEntry(
                date: Date(),
                lineName: "ERR",
                destination: String(errorMessage),
                minutesUntilArrival: 0,
                isDelayed: true,
                lineColor: "#FF0000"
            )
            let nextUpdate = Date().addingTimeInterval(30)
            return Timeline(entries: [fallbackEntry], policy: .after(nextUpdate))
        }
    }

    // MARK: - API Fetch

    private func fetchDepartures(for configuration: SelectStopIntent) async throws -> [WidgetDeparture] {
        // Get stop ID from configuration or use fallback
        let stopId = try await getStopId(from: configuration)

        let urlString = "\(apiBaseURL)/stops/\(stopId)/departures?limit=5"
        guard let url = URL(string: urlString) else {
            throw WidgetError.badURL
        }

        // Create a URLSession configuration that works in extensions
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = WidgetAPIConfig.requestTimeout
        config.timeoutIntervalForResource = WidgetAPIConfig.resourceTimeout
        let session = URLSession(configuration: config)

        let (data, response) = try await session.data(from: url)

        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                throw WidgetError.httpError(httpResponse.statusCode)
            }
        }

        let departures = try JSONDecoder().decode([WidgetDeparture].self, from: data)
        return departures
    }

    // MARK: - Get Stop ID (User Selected or Location-Based)

    private func getStopId(from configuration: SelectStopIntent) async throws -> String {
        // 1. Check if user selected a stop in widget configuration
        if let selectedStop = configuration.stop {
            return selectedStop.id
        }

        // 2. Try to get nearest stop from user's last known location (via App Group)
        if let location = SharedStorage.shared.getLocation() {
            do {
                let nearestStop = try await fetchNearestStop(latitude: location.latitude, longitude: location.longitude)
                if let stopId = nearestStop {
                    DebugLog.log("📍 [Widget] Using nearest stop: \(stopId)")
                    return stopId
                }
            } catch {
                DebugLog.log("⚠️ [Widget] Failed to fetch nearest stop: \(error)")
            }
        }

        // 3. Fallback based on last known nucleo
        let fallbackStop = getFallbackStop()
        DebugLog.log("📍 [Widget] Using fallback stop: \(fallbackStop)")
        return fallbackStop
    }

    /// Get fallback stop based on last known nucleo
    /// Madrid uses Atocha, other nucleos use their main hub station
    private func getFallbackStop() -> String {
        // Main hub stations for each nucleo (most connected stations)
        let nucleoHubs: [String: String] = [
            "Madrid": "RENFE_18000",              // Atocha RENFE
            "Asturias": "RENFE_15211",            // Oviedo
            "Sevilla": "RENFE_51003",             // Santa Justa
            "Cádiz": "RENFE_51405",               // Cádiz
            "Málaga": "RENFE_54517",              // Málaga Centro
            "Valencia": "RENFE_65000",            // València Estació del Nord
            "Murcia/Alicante": "RENFE_61200",     // Murcia del Carmen
            "Rodalies de Catalunya": "RENFE_71801", // Barcelona-Sants
            "Bilbao": "RENFE_13200",              // Abando
            "San Sebastián": "RENFE_11511",       // Donostia-San Sebastián
            "Cantabria": "RENFE_14223",           // Santander
            "Zaragoza": "RENFE_70807"             // Zaragoza - Goya
        ]

        // Check last known nucleo
        if let nucleoName = SharedStorage.shared.getNucleoName(),
           let hubStop = nucleoHubs[nucleoName] {
            return hubStop
        }

        // Ultimate fallback: Atocha (Madrid is most common)
        return "RENFE_18000"
    }

    /// Fetch nearest stop from user's location
    private func fetchNearestStop(latitude: Double, longitude: Double) async throws -> String? {
        let urlString = "\(apiBaseURL)/stops/by-coordinates?lat=\(latitude)&lon=\(longitude)&limit=1"
        guard let url = URL(string: urlString) else {
            return nil
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = WidgetAPIConfig.nearestStopTimeout
        let session = URLSession(configuration: config)

        let (data, response) = try await session.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            let stops = try JSONDecoder().decode([WidgetStop].self, from: data)
            return stops.first?.id
        }

        return nil
    }

    // MARK: - Create Timeline Entries

    private func createEntries(from departures: [WidgetDeparture]) -> [ArrivalEntry] {
        guard !departures.isEmpty else {
            // Return a default placeholder entry
            return [ArrivalEntry(
                date: Date(),
                lineName: "---",
                destination: "No data",
                minutesUntilArrival: 0,
                isDelayed: false,
                lineColor: "#75B6E0"
            )]
        }

        let currentDate = Date()
        var entries: [ArrivalEntry] = []

        // Create entries for each departure
        for (index, departure) in departures.prefix(3).enumerated() {
            // Calculate entry date (stagger by 2 minutes for visual updates)
            let entryDate = Calendar.current.date(byAdding: .minute, value: index * 2, to: currentDate) ?? currentDate

            // Recalculate minutes until based on entry date
            let originalMinutes = departure.minutesUntil
            let adjustedMinutes = max(0, originalMinutes - (index * 2))

            let entry = ArrivalEntry(
                date: entryDate,
                lineName: departure.routeShortName,
                destination: departure.headsign ?? "Unknown",
                minutesUntilArrival: adjustedMinutes,
                isDelayed: departure.isDelayed,
                lineColor: departure.routeColor ?? "#75B6E0"
            )
            entries.append(entry)
        }

        return entries
    }
}

// MARK: - Widget Models (simplified for widget)

struct WidgetDeparture: Codable {
    let tripId: String
    let routeShortName: String
    let routeColor: String?
    let headsign: String?
    let minutesUntil: Int
    let isDelayed: Bool

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case routeShortName = "route_short_name"
        case routeColor = "route_color"
        case headsign
        case minutesUntil = "minutes_until"
        case isDelayed = "is_delayed"
    }
}

struct WidgetStop: Codable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    let isHub: Bool?  // true if station has 2+ different transport types

    enum CodingKeys: String, CodingKey {
        case id, name, lat, lon
        case isHub = "is_hub"
    }
}

// Custom error type for better debugging
enum WidgetError: Error, CustomStringConvertible {
    case badURL
    case httpError(Int)
    case noData

    var description: String {
        switch self {
        case .badURL: return "Bad URL"
        case .httpError(let code): return "HTTP \(code)"
        case .noData: return "No data"
        }
    }
}

// MARK: - Shared Storage (App Group)
// NOTE: Duplicated from SharedStorage.swift because widget extensions
// cannot import code from the main app target in watchOS.
// Keep in sync with WatchTrans Watch App/Services/SharedStorage.swift

/// Shared storage for reading location and favorites from main app (read-only in widget)
class SharedStorage {
    static let shared = SharedStorage()

    private let appGroupId = "group.juan.WatchTrans"

    private enum Keys {
        static let lastLatitude = "lastLatitude"
        static let lastLongitude = "lastLongitude"
        static let lastLocationTimestamp = "lastLocationTimestamp"
        static let lastNucleoName = "lastNucleoName"
        static let favorites = "favorites"
        static let hubStops = "hubStops"
    }

    /// Simple favorite structure for sharing via UserDefaults
    struct SharedFavorite: Codable {
        let stopId: String
        let stopName: String
    }

    /// Hub stop structure for sharing via UserDefaults
    struct SharedHubStop: Codable {
        let stopId: String
        let stopName: String
    }

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    private var defaults: UserDefaults {
        sharedDefaults ?? UserDefaults.standard
    }

    private init() {}

    /// Get user's last known location from shared storage
    /// Uses timestamp to validate instead of checking for (0,0) coordinates
    func getLocation() -> (latitude: Double, longitude: Double)? {
        // Check timestamp to see if location was ever saved
        guard defaults.object(forKey: Keys.lastLocationTimestamp) != nil else {
            // Try standard defaults as fallback
            guard UserDefaults.standard.object(forKey: Keys.lastLocationTimestamp) != nil else {
                return nil
            }
            let stdLat = UserDefaults.standard.double(forKey: Keys.lastLatitude)
            let stdLon = UserDefaults.standard.double(forKey: Keys.lastLongitude)
            return (stdLat, stdLon)
        }

        let lat = defaults.double(forKey: Keys.lastLatitude)
        let lon = defaults.double(forKey: Keys.lastLongitude)
        return (lat, lon)
    }

    /// Get last known nucleo name
    func getNucleoName() -> String? {
        defaults.string(forKey: Keys.lastNucleoName)
    }

    /// Get favorites from shared storage
    func getFavorites() -> [SharedFavorite] {
        guard let data = defaults.data(forKey: Keys.favorites) else {
            return []
        }

        do {
            return try JSONDecoder().decode([SharedFavorite].self, from: data)
        } catch {
            DebugLog.log("⚠️ [Widget] Failed to decode favorites: \(error)")
            return []
        }
    }

    /// Get hub stops from shared storage (stations with 2+ transport types)
    func getHubStops() -> [SharedHubStop] {
        guard let data = defaults.data(forKey: Keys.hubStops) else {
            return []
        }

        do {
            return try JSONDecoder().decode([SharedHubStop].self, from: data)
        } catch {
            DebugLog.log("⚠️ [Widget] Failed to decode hub stops: \(error)")
            return []
        }
    }
}

// MARK: - Complication View (Rectangular)
// accessoryRectangular supports: fullColor, accented, vibrant

struct WatchTransWidgetEntryView: View {
    var entry: ArrivalProvider.Entry

    var lineColor: Color {
        Color(hex: entry.lineColor) ?? .blue
    }

    /// Check if this is a Metro/ML line (static GTFS, no real-time delay info)
    var isMetroLine: Bool {
        entry.lineName.hasPrefix("L") || entry.lineName.hasPrefix("ML")
    }

    /// Progress bar color:
    /// - Cercanías: green (on time) or orange (delayed)
    /// - Metro/ML: line color (no real-time delay info available)
    var progressColor: Color {
        if isMetroLine {
            return lineColor
        } else {
            return entry.isDelayed ? .orange : .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Line and destination
            HStack(spacing: 4) {
                Text(entry.lineName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(lineColor)
                    )
                Text("→")
                    .font(.caption2)
                Text(entry.destination)
                    .font(.caption)
                    .lineLimit(1)
            }

            // Time and progress
            HStack(spacing: 8) {
                Text(timeText)
                    .font(.body)
                    .bold()
                    .minimumScaleFactor(0.8)
                    .frame(minWidth: 45, alignment: .leading)
                ProgressView(value: progressValue)
                    .tint(progressColor)
            }
        }
        .privacySensitive(false)
    }

    var timeText: String {
        if entry.minutesUntilArrival == 0 {
            return "Now"
        } else {
            return "\(entry.minutesUntilArrival) min"
        }
    }

    var progressValue: Double {
        let minutes = Double(entry.minutesUntilArrival)
        let maxMinutes = 30.0
        return max(0, min(1.0, 1.0 - (minutes / maxMinutes)))
    }
}

// MARK: - Circular Complication View

struct WatchTransCircularView: View {
    var entry: ArrivalProvider.Entry

    var lineColor: Color {
        Color(hex: entry.lineColor) ?? .blue
    }

    /// Check if this is a Metro/ML line (no real-time delay info)
    var isMetroLine: Bool {
        entry.lineName.hasPrefix("L") || entry.lineName.hasPrefix("ML")
    }

    /// Progress bar color:
    /// - Cercanías: green (on time) or orange (delayed)
    /// - Metro/ML: line color
    var progressColor: Color {
        if isMetroLine {
            return lineColor
        } else {
            return entry.isDelayed ? .orange : .green
        }
    }

    var body: some View {
        ZStack {
            // Background circle (full ring, dimmed)
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .foregroundStyle(progressColor.opacity(0.3))

            // Progress circle - Cercanías: green/orange, Metro: line color
            Circle()
                .trim(from: 0, to: progressValue)
                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .foregroundStyle(progressColor)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(entry.lineName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(lineColor)
                Text(timeText)
                    .font(.system(size: 11))
            }
        }
        .privacySensitive(false)
    }

    var timeText: String {
        if entry.minutesUntilArrival == 0 {
            return "Now"
        } else {
            return "\(entry.minutesUntilArrival)m"
        }
    }

    var progressValue: Double {
        let minutes = Double(entry.minutesUntilArrival)
        let maxMinutes = 30.0
        return max(0, min(1.0, 1.0 - (minutes / maxMinutes)))
    }
}

// MARK: - Widget Configuration

struct WatchTransWidget: Widget {
    let kind: String = "juan.WatchTrans.watchkitapp.NextArrival"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectStopIntent.self, provider: ArrivalProvider()) { entry in
            WatchTransWidgetContentView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Arrival")
        .description("See your next train arrival. Tap to select a stop.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

// MARK: - Content View (Family Switcher)

struct WatchTransWidgetContentView: View {
    @Environment(\.widgetFamily) var family
    var entry: ArrivalProvider.Entry

    var body: some View {
        switch family {
        case .accessoryCircular:
            WatchTransCircularView(entry: entry)
        case .accessoryCorner:
            WatchTransCornerView(entry: entry)
        case .accessoryInline:
            WatchTransInlineView(entry: entry)
        default:
            WatchTransWidgetEntryView(entry: entry)
        }
    }
}

// MARK: - Corner Complication View

struct WatchTransCornerView: View {
    var entry: ArrivalProvider.Entry

    var lineColor: Color {
        Color(hex: entry.lineColor) ?? .blue
    }

    var body: some View {
        Text(entry.lineName)
            .font(.title2)
            .bold()
            .foregroundStyle(lineColor)
            .widgetLabel {
                Text(timeText)
            }
            .privacySensitive(false)
    }

    var timeText: String {
        if entry.minutesUntilArrival == 0 {
            return "Now"
        } else {
            return "\(entry.minutesUntilArrival) min"
        }
    }
}

// MARK: - Inline Complication View
// Note: Inline has very limited color support, keeping widgetAccentable as fallback

struct WatchTransInlineView: View {
    var entry: ArrivalProvider.Entry

    var lineColor: Color {
        Color(hex: entry.lineColor) ?? .blue
    }

    var body: some View {
        Text("\(entry.lineName): \(timeText)")
            .foregroundStyle(lineColor)
            .privacySensitive(false)
    }

    var timeText: String {
        if entry.minutesUntilArrival == 0 {
            return "Now"
        } else {
            return "\(entry.minutesUntilArrival) min"
        }
    }
}

// MARK: - Color Extension
// NOTE: Duplicated from Color+Hex.swift because widget extensions
// cannot import code from the main app target in watchOS

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview

#Preview(as: .accessoryRectangular) {
    WatchTransWidget()
} timeline: {
    ArrivalEntry(
        date: .now,
        lineName: "C3",
        destination: "Aranjuez",
        minutesUntilArrival: 5,
        isDelayed: false,
        lineColor: "#813380" // Official Cercanías C3 purple
    )
    ArrivalEntry(
        date: .now,
        lineName: "L1",
        destination: "Valdecarros",
        minutesUntilArrival: 2,
        isDelayed: true,
        lineColor: "#2ca5dd" // Official Metro L1 light blue - ColorsWall
    )
}
