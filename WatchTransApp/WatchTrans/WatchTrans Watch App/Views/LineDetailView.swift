//
//  LineDetailView.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//  Shows all stops for a specific line - loads stops from API
//

import SwiftUI

struct LineDetailView: View {
    let line: Line
    let dataService: DataService
    let locationService: LocationService

    @State private var stops: [Stop] = []
    @State private var alerts: [AlertResponse] = []
    @State private var isLoading = true

    var lineColor: Color {
        Color(hex: line.colorHex) ?? .blue
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Line header
                HStack(spacing: 8) {
                    Text(line.name)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(lineColor)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(line.type.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            // Alert indicator in header
                            if !alerts.isEmpty {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }

                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                        } else {
                            Text("\(stops.count) stops")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

                // Alert banners (if any)
                if !alerts.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(alerts.prefix(2)) { alert in
                            LineAlertBannerView(alert: alert)
                        }

                        if alerts.count > 2 {
                            Text("+\(alerts.count - 2) more alerts")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.horizontal, 8)
                }

                // All stops
                if isLoading {
                    ProgressView("Cargando paradas...")
                        .padding()
                } else if stops.isEmpty {
                    Text("No hay paradas disponibles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                            StopRow(
                                stop: stop,
                                isFirst: index == 0,
                                isLast: index == stops.count - 1,
                                lineColor: lineColor,
                                currentLineId: line.id,
                                dataService: dataService,
                                locationService: locationService
                            )
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .navigationTitle(line.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        // Fetch stops and alerts in parallel
        async let stopsTask: [Stop] = {
            if let routeId = line.routeIds.first {
                return await dataService.fetchStopsForRoute(routeId: routeId)
            }
            return []
        }()
        async let alertsTask = dataService.fetchAlertsForLine(line)

        stops = await stopsTask
        alerts = await alertsTask
        isLoading = false
    }
}

// MARK: - Line Alert Banner View

struct LineAlertBannerView: View {
    let alert: AlertResponse

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)

            Text(alertText)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(3)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(8)
    }

    private var alertText: String {
        // Use header if available, otherwise use description
        if let header = alert.headerText, !header.isEmpty {
            return header
        }
        return alert.descriptionText
    }
}

// MARK: - Wrapping HStack for Connection Badges

struct WrappingHStack: View {
    let connectionIds: [String]
    let dataService: DataService

    init(_ connectionIds: [String], dataService: DataService) {
        self.connectionIds = connectionIds
        self.dataService = dataService
    }

    var body: some View {
        // Split into rows of max 5 badges each
        let rows = connectionIds.chunked(into: 5)

        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 3) {
                    ForEach(row, id: \.self) { connectionId in
                        if let connectionLine = dataService.getLine(by: connectionId) {
                            Text(connectionLine.name)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(hex: connectionLine.colorHex) ?? .gray)
                                )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Metro/ML Connection Badges

/// View showing Metro and Metro Ligero connection badges
struct MetroConnectionBadges: View {
    let corMetro: String?   // e.g. "1, 10" or "6, 8, 10"
    let corMl: String?      // e.g. "1" or "2, 3"

    // Metro Madrid official colors
    private let metroColors: [String: String] = [
        "1": "#00A1E4",   // Light blue
        "2": "#D0032A",   // Red
        "3": "#FFD503",   // Yellow
        "4": "#944634",   // Brown
        "5": "#85BC20",   // Green
        "6": "#808083",   // Gray
        "7": "#F2A400",   // Orange
        "8": "#E84D8A",   // Pink
        "9": "#9C3293",   // Purple
        "10": "#0F5AA7",  // Dark blue
        "11": "#85BC20",  // Green
        "12": "#A2C100",  // Olive/Yellow
        "R": "#0F5AA7"    // Blue (Ramal)
    ]

    // Metro Ligero colors
    private let mlColors: [String: String] = [
        "1": "#00A1E4",   // Light blue
        "2": "#9C3293",   // Purple
        "3": "#D0032A",   // Red
        "4": "#85BC20"    // Green (Parla)
    ]

    var body: some View {
        let metroLines = parseLines(corMetro)
        let mlLines = parseLines(corMl)

        if !metroLines.isEmpty || !mlLines.isEmpty {
            HStack(spacing: 3) {
                // Metro badges (L1, L2, etc. - except R for Ramal)
                ForEach(metroLines, id: \.self) { line in
                    let prefix = line == "R" ? "" : "L"
                    MetroBadge(line: line, prefix: prefix, color: metroColors[line] ?? "#808080")
                }

                // Metro Ligero badges (ML1, ML2, etc.)
                ForEach(mlLines, id: \.self) { line in
                    MetroBadge(line: line, prefix: "ML", color: mlColors[line] ?? "#808080")
                }
            }
        }
    }

    /// Parse comma-separated line numbers: "1, 10" -> ["1", "10"]
    private func parseLines(_ value: String?) -> [String] {
        guard let value = value, !value.isEmpty else { return [] }
        return value.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

/// Individual Metro/ML badge
struct MetroBadge: View {
    let line: String
    let prefix: String   // "L" for Metro, "ML" for Metro Ligero, "" for Ramal
    let color: String

    var body: some View {
        Text("\(prefix)\(line)")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: color) ?? .gray)
            )
    }
}

// MARK: - Cercanías Connection Badges

/// View showing Cercanías connection badges (for Metro/ML stops)
struct CercaniasConnectionBadges: View {
    let corCercanias: String?   // e.g. "C1, C10, C2" or "C3, C4, C4a, C4b"

    // Cercanías Madrid colors (approximate)
    private let cercaniasColors: [String: String] = [
        "C1": "#66CCFF",   // Light blue
        "C2": "#00AA00",   // Green
        "C3": "#AA00AA",   // Purple
        "C3A": "#AA00AA",
        "C3B": "#AA00AA",
        "C4": "#0066CC",   // Blue
        "C4A": "#0066CC",
        "C4B": "#0066CC",
        "C5": "#FFCC00",   // Yellow
        "C7": "#FF6600",   // Orange
        "C8": "#FF0066",   // Pink
        "C8A": "#FF0066",
        "C8B": "#FF0066",
        "C9": "#AA5500",   // Brown
        "C10": "#99CC00"   // Lime
    ]

    var body: some View {
        let lines = parseLines(corCercanias)

        if !lines.isEmpty {
            HStack(spacing: 3) {
                ForEach(lines.prefix(6), id: \.self) { line in
                    CercaniasBadge(line: line, color: cercaniasColors[line.uppercased()] ?? "#75B6E0")
                }
            }
        }
    }

    /// Parse comma-separated line names: "C1, C10, C2" -> ["C1", "C10", "C2"]
    private func parseLines(_ value: String?) -> [String] {
        guard let value = value, !value.isEmpty else { return [] }
        return value.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

/// Individual Cercanías badge
struct CercaniasBadge: View {
    let line: String   // "C1", "C10", etc.
    let color: String

    var body: some View {
        Text(line)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: color) ?? .blue)
            )
    }
}

// Helper extension to chunk array
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Stop Row

struct StopRow: View {
    let stop: Stop
    let isFirst: Bool
    let isLast: Bool
    let lineColor: Color
    let currentLineId: String  // To filter out current line from connections
    let dataService: DataService
    let locationService: LocationService

    // Filter connections to exclude current line, sorted numerically
    var otherLineConnections: [String] {
        stop.connectionLineIds
            .filter { $0 != currentLineId }
            .sorted { lineNumber($0) < lineNumber($1) }
    }

    // Extract numeric value from line name for proper sorting (C1, C2, C4a, C4b, C10, L1, L4, ML1)
    private func lineNumber(_ name: String) -> Double {
        let numericString = name.lowercased()
            .replacingOccurrences(of: "c", with: "")
            .replacingOccurrences(of: "r", with: "")
            .replacingOccurrences(of: "ml", with: "")  // Metro Ligero
            .replacingOccurrences(of: "l", with: "")   // Metro

        // Handle suffixes like "4a", "4b", "8a", "8b"
        var baseNumber: Double = 0
        var suffix: Double = 0

        for (index, char) in numericString.enumerated() {
            if char.isLetter {
                // Get base number from characters before this
                let baseString = String(numericString.prefix(index))
                baseNumber = Double(baseString) ?? 0

                // Add small value for suffix (a=0.1, b=0.2, etc.)
                let suffixChar = char.lowercased()
                if let asciiValue = suffixChar.first?.asciiValue {
                    suffix = Double(asciiValue - 97) * 0.1 // 'a' = 0.1, 'b' = 0.2
                }
                return baseNumber + suffix
            }
        }

        // No letter suffix, just return the number
        return Double(numericString) ?? 0
    }

    var hasConnections: Bool {
        !otherLineConnections.isEmpty
    }

    /// Check if stop has Metro or ML connections
    var hasMetroConnections: Bool {
        (stop.corMetro != nil && !stop.corMetro!.isEmpty) ||
        (stop.corMl != nil && !stop.corMl!.isEmpty)
    }

    /// Check if stop has Cercanías connections (for Metro/ML stops)
    var hasCercaniasConnections: Bool {
        stop.corCercanias != nil && !stop.corCercanias!.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Connection line (vertical)
            if !isFirst {
                Rectangle()
                    .fill(lineColor)
                    .frame(width: 3, height: 12)
            }

            // Stop circle and info - wrapped in NavigationLink
            NavigationLink(destination: StopDetailView(
                stop: stop,
                dataService: dataService,
                locationService: locationService,
                favoritesManager: nil
            )) {
                HStack(alignment: .center, spacing: 10) {
                    // Circle indicator
                    Circle()
                        .fill(lineColor)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(.background, lineWidth: 2)
                        )

                    // Stop name
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.name)
                            .font(.subheadline)
                            .fontWeight(isFirst || isLast ? .bold : .regular)

                        // Connection badges (other lines of same type)
                        if hasConnections {
                            WrappingHStack(otherLineConnections, dataService: dataService)
                        }

                        // Metro/ML connection badges (for Cercanías stops)
                        if hasMetroConnections {
                            MetroConnectionBadges(corMetro: stop.corMetro, corMl: stop.corMl)
                        }

                        // Cercanías connection badges (for Metro/ML stops)
                        if hasCercaniasConnections {
                            CercaniasConnectionBadges(corCercanias: stop.corCercanias)
                        }
                    }

                    Spacer()

                    // Tap to view departures indicator
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Connection line (vertical)
            if !isLast {
                Rectangle()
                    .fill(lineColor)
                    .frame(width: 3, height: 12)
            }
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    NavigationStack {
        LineDetailView(
            line: Line(
                id: "c1",
                name: "C1",
                longName: "Chamartín - Aeropuerto T4",
                type: .cercanias,
                colorHex: "#75B6E0",
                nucleo: "madrid",
                routeIds: ["RENFE_C1_34"]
            ),
            dataService: DataService(),
            locationService: LocationService()
        )
    }
}
