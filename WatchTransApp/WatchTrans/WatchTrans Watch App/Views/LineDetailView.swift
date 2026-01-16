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

    @State private var stops: [Stop] = []
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
                        Text(line.type.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

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
                                dataService: dataService
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
            await loadStops()
        }
    }

    private func loadStops() async {
        isLoading = true
        // Fetch stops for this line using the first actual route ID
        if let routeId = line.routeIds.first {
            stops = await dataService.fetchStopsForRoute(routeId: routeId)
        }
        isLoading = false
    }
}

// MARK: - Stop Row

struct StopRow: View {
    let stop: Stop
    let isFirst: Bool
    let isLast: Bool
    let lineColor: Color
    let dataService: DataService

    @State private var showArrivals = false

    var hasConnections: Bool {
        !stop.connectionLineIds.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Connection line (vertical)
            if !isFirst {
                Rectangle()
                    .fill(lineColor)
                    .frame(width: 3, height: 12)
            }

            // Stop circle and info
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

                    // Connection badges
                    if hasConnections {
                        HStack(spacing: 4) {
                            ForEach(stop.connectionLineIds, id: \.self) { connectionId in
                                if let connectionLine = dataService.getLine(by: connectionId) {
                                    Text(connectionLine.name)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4)
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

                Spacer()

                // Tap to view arrivals indicator
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .cornerRadius(8)

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
                type: .cercanias,
                colorHex: "#75B6E0",
                nucleo: "madrid",
                routeIds: ["RENFE_C1_34"]
            ),
            dataService: DataService()
        )
    }
}
