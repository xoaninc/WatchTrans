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
    @State private var operatingHours: String?
    @State private var isLoading = true

    var lineColor: Color {
        Color(hex: line.colorHex) ?? .blue
    }

    /// All line types can potentially have operating hours from API
    var shouldShowOperatingHours: Bool {
        true  // Try to fetch for all lines - API returns empty if not available
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

                // Operating hours (below alerts)
                if let hours = operatingHours {
                    let _ = print("🕐 [UI] Rendering operating hours: \(hours)")
                    Text("Apertura hoy: \(hours)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(8)
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
                                currentLineName: line.name,
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

        print("🚀 [LineDetail] Loading data for line \(line.name) (routeIds: \(line.routeIds))")

        // Fetch stops, alerts, and operating hours in parallel
        async let stopsTask: [Stop] = {
            if let routeId = line.routeIds.first {
                return await dataService.fetchStopsForRoute(routeId: routeId)
            }
            return []
        }()
        async let alertsTask = dataService.fetchAlertsForLine(line)
        async let hoursTask: String? = {
            if let routeId = line.routeIds.first {
                print("📅 [LineDetail] Requesting operating hours for routeId: \(routeId)")
                return await dataService.fetchOperatingHours(routeId: routeId)
            }
            print("⚠️ [LineDetail] No routeId available for line \(line.name)")
            return nil
        }()

        stops = await stopsTask
        alerts = await alertsTask
        operatingHours = await hoursTask

        print("✅ [LineDetail] Loaded: \(stops.count) stops, \(alerts.count) alerts, hours=\(operatingHours ?? "nil")")

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
        return alert.descriptionText ?? "Alerta de servicio"
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

// MARK: - All Connection Badges (Combined Wrapping View)

/// View showing all connection badges (Metro, ML, Cercanías, Tranvía) in a wrapping layout
struct AllConnectionBadges: View {
    let corMetro: String?
    let corMl: String?
    let corCercanias: String?
    let corTranvia: String?
    let dataService: DataService
    var excludeLineName: String? = nil  // Filter out current line to avoid duplicates
    var excludeLineIds: [String] = []   // Filter out lines already shown in connectionLineIds

    // Default colors for when line not found
    private let defaultMetroColor = "#ED1C24"
    private let defaultMlColor = "#3A7DDA"
    private let defaultCercaniasColor = "#75B2E0"
    private let defaultTranviaColor = "#E4002B"

    /// All badges as (name, color) tuples - ordered by transport type:
    /// Cercanías → Metro → Metro Ligero → Tranvía
    private var allBadges: [(name: String, color: String)] {
        var badges: [(String, String)] = []
        let excludeLower = excludeLineName?.lowercased()

        // Normalize excludeLineIds for comparison
        let excludeIdsNormalized = Set(excludeLineIds.map { normalizeLineName($0) })

        // DEBUG: Log filtering
        if let exclude = excludeLineName {
            print("🏷️ [Filter] excludeLineName='\(exclude)', excludeIds=\(excludeLineIds), cor_metro=\(corMetro ?? "nil"), cor_cerc=\(corCercanias ?? "nil")")
        }

        // 1. Cercanías lines first
        for line in parseLines(corCercanias) {
            let normalized = normalizeLineName(line)
            if line.lowercased() != excludeLower && !excludeIdsNormalized.contains(normalized) {
                let color = dataService.getLine(by: line)?.colorHex ?? defaultCercaniasColor
                badges.append((line, color))
            }
        }

        // 2. Metro lines
        for line in parseLines(corMetro) {
            let normalized = normalizeLineName(line)
            if line.lowercased() != excludeLower && !excludeIdsNormalized.contains(normalized) {
                let color = dataService.getLine(by: line)?.colorHex ?? defaultMetroColor
                badges.append((line, color))
            }
        }

        // 3. Metro Ligero lines
        for line in parseLines(corMl) {
            let normalized = normalizeLineName(line)
            if line.lowercased() != excludeLower && !excludeIdsNormalized.contains(normalized) {
                let color = dataService.getLine(by: line)?.colorHex ?? defaultMlColor
                badges.append((line, color))
            }
        }

        // 4. Tranvía lines last
        for line in parseLines(corTranvia) {
            let normalized = normalizeLineName(line)
            if line.lowercased() != excludeLower && !excludeIdsNormalized.contains(normalized) {
                let color = dataService.getLine(by: line)?.colorHex ?? defaultTranviaColor
                badges.append((line, color))
            }
        }

        return badges
    }

    var body: some View {
        let badges = allBadges
        if !badges.isEmpty {
            // DEBUG: Log badges being displayed
            let _ = print("🏷️ [AllConnectionBadges] Displaying \(badges.count) badges: \(badges.map { $0.name }.joined(separator: ", "))")

            // Split into rows of max 5 badges each
            let rows = badges.chunked(into: 5)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 3) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, badge in
                            Text(badge.name)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(hex: badge.color) ?? .gray)
                                )
                        }
                    }
                }
            }
        }
    }

    /// Parse comma-separated line names: "L1, L10" -> ["L1", "L10"]
    private func parseLines(_ value: String?) -> [String] {
        guard let value = value, !value.isEmpty else { return [] }
        return value.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Normalize line name for comparison: "L7" -> "7", "l7" -> "7", "7" -> "7"
    private func normalizeLineName(_ name: String) -> String {
        var normalized = name.lowercased().trimmingCharacters(in: .whitespaces)
        for prefix in ["ml", "l", "c", "r", "t"] {
            if normalized.hasPrefix(prefix) && normalized.count > prefix.count {
                let afterPrefix = normalized.dropFirst(prefix.count)
                if let firstChar = afterPrefix.first, firstChar.isNumber {
                    normalized = String(afterPrefix)
                    break
                }
            }
        }
        return normalized
    }
}

// MARK: - Legacy Badge Views (kept for compatibility)

/// View showing Metro and Metro Ligero connection badges
struct MetroConnectionBadges: View {
    let corMetro: String?
    let corMl: String?
    let dataService: DataService

    var body: some View {
        AllConnectionBadges(
            corMetro: corMetro,
            corMl: corMl,
            corCercanias: nil,
            corTranvia: nil,
            dataService: dataService
        )
    }
}

/// View showing Cercanías connection badges
struct CercaniasConnectionBadges: View {
    let corCercanias: String?
    let dataService: DataService

    var body: some View {
        AllConnectionBadges(
            corMetro: nil,
            corMl: nil,
            corCercanias: corCercanias,
            corTranvia: nil,
            dataService: dataService
        )
    }
}

/// View showing Tranvía connection badges
struct TranviaConnectionBadges: View {
    let corTranvia: String?
    let dataService: DataService

    var body: some View {
        AllConnectionBadges(
            corMetro: nil,
            corMl: nil,
            corCercanias: nil,
            corTranvia: corTranvia,
            dataService: dataService
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
    let currentLineName: String  // To filter out current line from cor_* badges
    let dataService: DataService
    let locationService: LocationService

    // Filter connections to exclude current line, sorted numerically
    // Compare normalized names (strip L/C/ML prefixes for comparison)
    var otherLineConnections: [String] {
        let currentNormalized = normalizeLineName(currentLineName)
        let filtered = stop.connectionLineIds
            .filter { normalizeLineName($0) != currentNormalized }
            .sorted { lineNumber($0) < lineNumber($1) }

        // DEBUG: Log filtering
        if !stop.connectionLineIds.isEmpty {
            print("🔗 [StopRow] '\(stop.name)' lineas=\(stop.connectionLineIds), current='\(currentLineName)'(\(currentNormalized)), filtered=\(filtered)")
        }
        return filtered
    }

    // Normalize line name for comparison: "L7" -> "7", "l7" -> "7", "7" -> "7"
    private func normalizeLineName(_ name: String) -> String {
        var normalized = name.lowercased().trimmingCharacters(in: .whitespaces)
        // Remove common prefixes
        for prefix in ["ml", "l", "c", "r", "t"] {
            if normalized.hasPrefix(prefix) && normalized.count > prefix.count {
                let afterPrefix = normalized.dropFirst(prefix.count)
                // Only strip if what follows starts with a digit
                if let firstChar = afterPrefix.first, firstChar.isNumber {
                    normalized = String(afterPrefix)
                    break
                }
            }
        }
        return normalized
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

    /// Check if stop has Tranvía connections
    var hasTranviaConnections: Bool {
        stop.corTranvia != nil && !stop.corTranvia!.isEmpty
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

                        // All other connection badges (Metro, ML, Cercanías, Tranvía) combined
                        // Exclude current line AND lines already shown in WrappingHStack
                        if hasMetroConnections || hasCercaniasConnections || hasTranviaConnections {
                            AllConnectionBadges(
                                corMetro: stop.corMetro,
                                corMl: stop.corMl,
                                corCercanias: stop.corCercanias,
                                corTranvia: stop.corTranvia,
                                dataService: dataService,
                                excludeLineName: currentLineName,
                                excludeLineIds: otherLineConnections  // Don't duplicate badges from WrappingHStack
                            )
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
