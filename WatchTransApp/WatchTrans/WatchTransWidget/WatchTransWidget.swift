//
//  WatchTransWidget.swift
//  WatchTransWidget
//
//  Created by Juan Macias Gomez on 14/1/26.
//

import WidgetKit
import SwiftUI
import AppIntents

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
    private let apiBaseURL = "https://redcercanias.com/api/v1/gtfs"
    // Refresh interval: 2.5 minutes (150 seconds)
    private let refreshIntervalSeconds: TimeInterval = 150

    // Recommendations for widget gallery
    func recommendations() -> [AppIntentRecommendation<SelectStopIntent>] {
        // Return some default recommendations
        let defaultStops = [
            ("RENFE_17000", "Nuevos Ministerios"),
            ("RENFE_18000", "Sol"),
            ("RENFE_10000", "Atocha Cercanías")
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
            print("⚠️ [Widget Snapshot] Error: \(error)")
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
            print("⚠️ [Widget] Failed to fetch: \(error)")
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
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
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

    // MARK: - Get Stop ID (User Selected or Fallback)

    private func getStopId(from configuration: SelectStopIntent) async throws -> String {
        // 1. Check if user selected a stop in widget configuration
        if let selectedStop = configuration.stop {
            return selectedStop.id
        }

        // 2. Fallback to Nuevos Ministerios (major hub in Madrid)
        // TODO: Add App Group to share location between app and widget
        return "RENFE_17000"
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

// MARK: - Complication View (Rectangular)
// accessoryRectangular supports: fullColor, accented, vibrant

struct WatchTransWidgetEntryView: View {
    var entry: ArrivalProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Line and destination
            HStack(spacing: 4) {
                Text(entry.lineName)
                    .font(.headline)
                    .bold()
                Text("→")
                    .font(.caption2)
                Text(entry.destination)
                    .font(.caption)
                    .lineLimit(1)
            }

            // Time and progress
            HStack {
                Text(timeText)
                    .font(.body)
                    .bold()
                    .minimumScaleFactor(0.8)
                Spacer()
                ProgressView(value: progressValue)
                    .frame(width: 50)
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
// accessoryCircular supports: accented, vibrant (NO fullColor!)

struct WatchTransCircularView: View {
    var entry: ArrivalProvider.Entry

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: progressValue)
                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(entry.lineName)
                    .font(.system(size: 16, weight: .bold))
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
// accessoryCorner supports: accented, vibrant (NO fullColor!)

struct WatchTransCornerView: View {
    var entry: ArrivalProvider.Entry

    var body: some View {
        Text(entry.lineName)
            .font(.title2)
            .bold()
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
// accessoryInline supports: accented, vibrant (NO fullColor!)

struct WatchTransInlineView: View {
    var entry: ArrivalProvider.Entry

    var body: some View {
        Text("\(entry.lineName): \(timeText)")
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
