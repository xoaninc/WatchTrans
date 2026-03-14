//
//  LineDetailView.swift
//  WatchTrans iOS
//
//  Created by Juan Macias Gomez on 21/1/26.
//

import SwiftUI
import MapKit

struct LineDetailView: View {
    let line: Line
    let dataService: DataService
    let locationService: LocationService
    let favoritesManager: FavoritesManager?

    @State private var stops: [Stop] = []
    @State private var alerts: [AlertResponse] = []
    @State private var stopAlerts: [String: [AlertResponse]] = [:]
    @State private var operatingHoursResult: OperatingHoursResult?
    @State private var shapePoints: [CLLocationCoordinate2D] = []
    @State private var stopOnShapeCoords: [String: CLLocationCoordinate2D] = [:]  // Stop coordinates projected onto shape
    @State private var isLoading = true
    @State private var isShapeLoading = true
    @State private var isAlertsExpanded = false
    @State private var isOfflineData = false

    var lineColor: Color {
        Color(hex: line.colorHex) ?? .blue
    }
    
    /// Check if line has any full suspension alerts
    var isLineSuspended: Bool {
        alerts.contains { $0.isFullSuspension }
    }

    /// Special descriptions for specific lines (hardcoded)
    var specialLineDescription: String? {
        let nucleo = line.nucleo.lowercased()
        let name = line.name.uppercased()

        // C4 Sevilla - circular en sentido horario
        if nucleo == "sevilla" && name == "C4" {
            return "Linea circular en sentido horario"
        }

        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Offline banner
                if isOfflineData {
                    HStack {
                        Image(systemName: "icloud.slash")
                        Text("Datos en cache - Sin conexion")
                            .font(.caption)
                    }
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(8)
                }

                // Line header
                LineHeaderView(line: line, stopsCount: stops.count, isLoading: isLoading)

                // Special line description (hardcoded for specific lines)
                if let description = specialLineDescription {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(lineColor)
                        Text(description)
                            .font(.subheadline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(lineColor.opacity(0.1))
                    .cornerRadius(10)
                }

                // Alerts (if any) - expandable
                if !alerts.isEmpty {
                    AlertsSummaryView(
                        alerts: alerts,
                        isExpanded: $isAlertsExpanded
                    )
                }

                // Operating hours or suspension banner
                if let result = operatingHoursResult {
                    if result.isSuspended {
                        // Suspended service banner
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "exclamationmark.octagon.fill")
                                    .foregroundStyle(.red)
                                Text("Servicio suspendido")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            if let message = result.suspensionMessage {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    } else if let hours = result.hoursString {
                        // Normal operating hours
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(.blue)
                            Text("Apertura hoy: \(hours)")
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }

                // Route map
                if !stops.isEmpty {
                    RouteMapView(
                        line: line,
                        stops: stops,
                        dataService: dataService,
                        shapePoints: shapePoints.isEmpty ? nil : shapePoints,
                        stopOnShapeCoords: stopOnShapeCoords.isEmpty ? nil : stopOnShapeCoords,
                        isSuspended: isLineSuspended,
                        isShapeLoading: isShapeLoading
                    )
                }

                // Stops list
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Cargando paradas...")
                        Spacer()
                    }
                    .padding(.vertical, 40)
                } else if stops.isEmpty {
                    Text("No hay paradas disponibles")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                            NavigationLink(destination: StopDetailView(
                                stop: stop,
                                dataService: dataService,
                                locationService: locationService,
                                favoritesManager: favoritesManager
                            )) {
                                LineStopRowView(
                                    stop: stop,
                                    lineColor: lineColor,
                                    isFirst: index == 0,
                                    isLast: index == stops.count - 1,
                                    isCircular: line.isCircular,
                                    dataService: dataService,
                                    alerts: stopAlerts[stop.id] ?? []
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(line.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        isShapeLoading = true
        isOfflineData = false

        DebugLog.log("📋 [LineDetail] Loading line: \(line.name) (\(line.id))")

        // Check if offline - try cached data first
        if !NetworkMonitor.shared.isConnected {
            if let routeId = line.routeIds.first,
               let cachedStops = await OfflineLineService.shared.getCachedStops(for: routeId) {
                stops = cachedStops
                isOfflineData = true
                isLoading = false
                isShapeLoading = false
                DebugLog.log("📋 [LineDetail] 📦 Using \(stops.count) cached stops (offline)")
                return
            }
        }

        // Online: fetch from API (Sequential)
        if let routeId = line.routeIds.first {
            stops = await dataService.fetchStopsForRoute(routeId: routeId)
        } else {
            stops = []
        }

        // Fetch alerts for all stops in parallel
        await withTaskGroup(of: (String, [AlertResponse]).self) { group in
            for stop in stops {
                group.addTask {
                    let alerts = await dataService.fetchAlertsForStop(stopId: stop.id)
                    return (stop.id, alerts)
                }
            }
            for await (stopId, alerts) in group {
                stopAlerts[stopId] = alerts
            }
        }

        alerts = await dataService.fetchAlertsForLine(line)

        if let routeId = line.routeIds.first {
            operatingHoursResult = await dataService.fetchOperatingHours(routeId: routeId)
        } else {
            operatingHoursResult = nil
        }

        let shapeResult: DataService.ShapeWithStops
        if let routeId = line.routeIds.first {
            shapeResult = await dataService.fetchRouteShapeWithStops(routeId: routeId, maxGap: 100)
        } else {
            shapeResult = DataService.ShapeWithStops(shapePoints: [], stopCoordinates: [:])
        }
        
        shapePoints = shapeResult.shapePoints.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        stopOnShapeCoords = shapeResult.stopCoordinates
        isShapeLoading = false

        // If online fetch failed, try cached data
        if stops.isEmpty, let routeId = line.routeIds.first,
           let cachedStops = await OfflineLineService.shared.getCachedStops(for: routeId) {
            stops = cachedStops
            isOfflineData = true
            DebugLog.log("📋 [LineDetail] 📦 API failed, using \(stops.count) cached stops")
        }

        DebugLog.log("📋 [LineDetail] ✅ Loaded: \(stops.count) stops, \(shapePoints.count) shape coords, \(alerts.count) alerts")
        isLoading = false
    }
}

// MARK: - Line Header View

struct LineHeaderView: View {
    let line: Line
    let stopsCount: Int
    let isLoading: Bool

    var lineColor: Color {
        Color(hex: line.colorHex) ?? .blue
    }

    /// Metro Ligero uses inverted style: white background, colored border and text
    var isMetroLigero: Bool {
        line.type == .metroLigero
    }

    var body: some View {
        HStack(spacing: 12) {
            // Line badge
            if isMetroLigero {
                // Metro Ligero: white background, colored border and text
                Text(line.name)
                    .font(.title)
                    .fontWeight(.heavy)
                    .foregroundStyle(lineColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(lineColor, lineWidth: 3)
                            )
                    )
            } else {
                // Standard: colored background, white text
                Text(line.name)
                    .font(.title)
                    .fontWeight(.heavy)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(lineColor)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(line.longName)
                    .font(.headline)
                    .lineLimit(2)

                HStack {
                    Text(line.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text("\(stopsCount) paradas")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Alert Banner View

// MARK: - Alerts Summary View (Expandable)

struct AlertsSummaryView: View {
    let alerts: [AlertResponse]
    @Binding var isExpanded: Bool
    
    // Determine color based on whether any alert is a suspension
    private var sectionColor: Color {
        alerts.contains { $0.isFullSuspension } ? .red : .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header - always visible, tappable
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(sectionColor)
                    Text("\(alerts.count) aviso\(alerts.count == 1 ? "" : "s")")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Preview: show first 2 alerts (collapsed)
            if !isExpanded {
                ForEach(alerts.prefix(2)) { alert in
                    AlertBannerCompactView(alert: alert)
                }
                if alerts.count > 2 {
                    Text("Toca para ver \(alerts.count - 2) mas...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Expanded: show all alerts
            if isExpanded {
                ForEach(alerts) { alert in
                    AlertBannerView(alert: alert)
                }
            }
        }
        .padding()
        .background(sectionColor.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Alert Banner Compact View

struct AlertBannerCompactView: View {
    let alert: AlertResponse
    
    // Extract first line of description as header fallback
    private var effectiveHeader: String? {
        if let header = alert.headerText, !header.isEmpty {
            return header
        }
        // Use first line of description as header if headerText is empty
        if let description = alert.descriptionText, !description.isEmpty {
            return description.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
    
    private var shouldShowFullDescription: Bool {
        // Only show full description if we have a proper headerText
        alert.headerText != nil && !alert.headerText!.isEmpty
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(alert.severityColor)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                if let header = effectiveHeader {
                    Text(header)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                }
                if shouldShowFullDescription, let description = alert.descriptionText, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Alert Banner View (Full)

struct AlertBannerView: View {
    let alert: AlertResponse
    
    // Extract first line of description as header fallback
    private var effectiveHeader: String? {
        if let header = alert.headerText, !header.isEmpty {
            return header
        }
        // Use first line of description as header if headerText is empty
        if let description = alert.descriptionText, !description.isEmpty {
            return description.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
    
    private var effectiveDescription: String? {
        // Only show description if we have a proper headerText (not extracted from description)
        guard let header = alert.headerText, !header.isEmpty else {
            // If header is extracted from description, show remaining lines
            if let description = alert.descriptionText, !description.isEmpty {
                let lines = description.components(separatedBy: .newlines)
                if lines.count > 1 {
                    return lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            return nil
        }
        return alert.descriptionText
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(alert.severityColor)

            VStack(alignment: .leading, spacing: 4) {
                if let header = effectiveHeader {
                    Text(header)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                if let description = effectiveDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(alert.severityColor.opacity(0.15))
        .cornerRadius(10)
    }
}

// MARK: - Line Stop Row View

struct LineStopRowView: View {
    let stop: Stop
    let lineColor: Color
    let isFirst: Bool
    let isLast: Bool
    let isCircular: Bool  // For circular lines (L6, L12)
    let dataService: DataService
    var alerts: [AlertResponse] = []

    // Default colors for connection badges
    private let defaultMetroColor = "#ED1C24"
    private let defaultMlColor = "#3A7DDA"
    private let defaultCercaniasColor = "#75B2E0"
    private let defaultTranviaColor = "#E4002B"
    private let defaultFunicularColor = "#000000"

    /// Format line name: "c4a" → "C4a", "l10b" → "L10b", "ml1" → "ML1"
    private func formatLineName(_ name: String, type: String) -> String {
        if name.lowercased() == "true" {
            return type
        }
        
        let lowercased = name.lowercased()

        // Handle ML prefix specially (2 chars)
        if lowercased.hasPrefix("ml") {
            let rest = String(lowercased.dropFirst(2))
            return "ML" + rest
        }

        // Handle single-char prefixes (C, L, R, T, S)
        if let first = lowercased.first, first.isLetter {
            let rest = String(lowercased.dropFirst())
            return String(first).uppercased() + rest
        }

        return name
    }

    /// Parse comma-separated line string into array
    private func parseLines(_ value: String?) -> [String] {
        guard let value = value, !value.isEmpty else { return [] }
        return value.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// All connection badges: Cercanías → Metro → Metro Ligero → Tranvía → Funicular
    /// Returns (name, color, isMetroLigero) for each badge
    private var connectionBadges: [(name: String, color: Color, isMetroLigero: Bool)] {
        var badges: [(String, Color, Bool)] = []

        // 1. Train connections (Cercanías, FEVE, etc.)
        let cercaniasLines = stop.correspondences?.tren ?? parseLines(stop.corTren)
        for line in cercaniasLines {
            let color = dataService.getLine(by: line)?.color ?? Color(hex: defaultCercaniasColor) ?? .blue
            badges.append((formatLineName(line, type: "Cercanías"), color, false))
        }

        // 2. Metro connections
        let metroLines = stop.correspondences?.metro ?? parseLines(stop.corMetro)
        for line in metroLines {
            let color = dataService.getLine(by: line)?.color ?? Color(hex: defaultMetroColor) ?? .red
            badges.append((formatLineName(line, type: "Metro"), color, false))
        }

        // 3. Metro Ligero connections
        let mlLines = stop.correspondences?.ml ?? parseLines(stop.corMl)
        for line in mlLines {
            let color = dataService.getLine(by: line)?.color ?? Color(hex: defaultMlColor) ?? .blue
            badges.append((formatLineName(line, type: "ML"), color, true))  // isMetroLigero = true
        }

        // 4. Tranvía connections
        let tramLines = stop.correspondences?.tranvia ?? parseLines(stop.corTranvia)
        for line in tramLines {
            let color = dataService.getLine(by: line)?.color ?? Color(hex: defaultTranviaColor) ?? .red
            badges.append((formatLineName(line, type: "TRAM"), color, false))
        }
        
        // 5. Funicular connections
        let funicularLines = stop.correspondences?.funicular ?? parseLines(stop.corFunicular)
        for line in funicularLines {
            badges.append((formatLineName(line, type: "Funicular"), Color(hex: defaultFunicularColor) ?? .black, false))
        }

        return badges
    }

    /// Check if stop has any connections to show
    private var hasConnections: Bool {
        !connectionBadges.isEmpty
    }

    // For circular lines, don't highlight first/last as terminals
    private var isTerminal: Bool {
        !isCircular && (isFirst || isLast)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Vertical line with stop circle
            VStack(spacing: 0) {
                // For circular lines, show continuous line (no gap at start)
                if !isFirst || isCircular {
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: 3, height: 20)
                } else {
                    Spacer()
                        .frame(width: 3, height: 20)
                }

                Circle()
                    .fill(lineColor)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )

                // For circular lines, show continuous line (no gap at end)
                if !isLast || isCircular {
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: 3, height: 20)
                } else {
                    Spacer()
                        .frame(width: 3, height: 20)
                }
            }

            // Stop info
            VStack(alignment: .leading, spacing: 4) {
                Text(stop.name)
                    .font(isTerminal ? .headline : .body)
                    .fontWeight(isTerminal ? .bold : .regular)

                // Show connection badges (Metro, Cercanías, Tranvía, ML)
                if hasConnections {
                    HStack(spacing: 4) {
                        ForEach(Array(connectionBadges.prefix(6).enumerated()), id: \.offset) { _, badge in
                            if badge.isMetroLigero {
                                // Metro Ligero: white background, colored border and text
                                Text(badge.name)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(badge.color)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 3)
                                                    .stroke(badge.color, lineWidth: 1)
                                            )
                                    )
                            } else {
                                // Standard: colored background, white text
                                Text(badge.name)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(badge.color)
                                    .cornerRadius(3)
                            }
                        }
                    }
                }

                if !alerts.isEmpty {
                    StopAlertBadge(alerts: alerts, mode: .inline)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
    }
}

#Preview {
    NavigationStack {
        LineDetailView(
            line: Line(
                id: "c3",
                name: "C3",
                longName: "Sol - Aranjuez",
                type: .cercanias,
                colorHex: "#813380",
                nucleo: "madrid",
                routeIds: ["RENFE_C3_34"],
                isCircular: false,
                serviceStatus: nil,
                suspendedSince: nil,
                isAlternativeService: nil
            ),
            dataService: DataService(),
            locationService: LocationService(),
            favoritesManager: nil
        )
    }
}
