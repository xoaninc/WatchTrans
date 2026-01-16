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
        var numericString = name.lowercased()
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

                        // Connection badges (other lines only) - wrap to multiple rows
                        if hasConnections {
                            WrappingHStack(otherLineConnections, dataService: dataService)
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
