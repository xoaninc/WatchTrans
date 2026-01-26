//
//  JourneyPlannerView.swift
//  WatchTrans iOS
//
//  Created by Claude on 26/1/26.
//  View for planning journeys between two stops
//

import SwiftUI

struct JourneyPlannerView: View {
    let dataService: DataService
    let locationService: LocationService

    @State private var routingService: RoutingService?
    @State private var originText = ""
    @State private var destinationText = ""
    @State private var selectedOrigin: Stop?
    @State private var selectedDestination: Stop?
    @State private var originSuggestions: [Stop] = []
    @State private var destinationSuggestions: [Stop] = []
    @State private var isSearchingOrigin = false
    @State private var isSearchingDestination = false
    @State private var journey: Journey?
    @State private var isCalculating = false
    @State private var showAnimation = false
    @State private var errorMessage: String?

    @FocusState private var focusedField: Field?

    enum Field {
        case origin
        case destination
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Search card
                    searchCard

                    // Error message
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }

                    // Journey result
                    if let journey = journey {
                        JourneyResultView(
                            journey: journey,
                            dataService: dataService,
                            onPreview: {
                                showAnimation = true
                            }
                        )
                    }

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Planificar viaje")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(isPresented: $showAnimation) {
                if let journey = journey {
                    Journey3DAnimationView(journey: journey, dataService: dataService)
                }
            }
        }
        .onAppear {
            if routingService == nil {
                routingService = RoutingService(dataService: dataService)
            }
        }
    }

    // MARK: - Search Card

    private var searchCard: some View {
        VStack(spacing: 16) {
            // Origin field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                    Text("Origen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    TextField("Buscar estacion...", text: $originText)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .origin)
                        .onChange(of: originText) { _, newValue in
                            searchStops(query: newValue, isOrigin: true)
                        }

                    if selectedOrigin != nil {
                        Button {
                            originText = ""
                            selectedOrigin = nil
                            journey = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

                // Origin suggestions
                if focusedField == .origin && !originSuggestions.isEmpty && selectedOrigin == nil {
                    suggestionsList(stops: originSuggestions, isOrigin: true)
                }
            }

            // Swap button
            HStack {
                Spacer()
                Button {
                    swapOriginDestination()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .padding(8)
                        .background(Circle().fill(Color(.systemGray6)))
                }
                Spacer()
            }

            // Destination field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                    Text("Destino")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    TextField("Buscar estacion...", text: $destinationText)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .destination)
                        .onChange(of: destinationText) { _, newValue in
                            searchStops(query: newValue, isOrigin: false)
                        }

                    if selectedDestination != nil {
                        Button {
                            destinationText = ""
                            selectedDestination = nil
                            journey = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

                // Destination suggestions
                if focusedField == .destination && !destinationSuggestions.isEmpty && selectedDestination == nil {
                    suggestionsList(stops: destinationSuggestions, isOrigin: false)
                }
            }

            // Search button
            Button {
                Task {
                    await calculateRoute()
                }
            } label: {
                HStack {
                    if isCalculating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    Text(isCalculating ? "Calculando..." : "Buscar ruta")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSearch ? Color.blue : Color.gray)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(!canSearch || isCalculating)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private var canSearch: Bool {
        selectedOrigin != nil && selectedDestination != nil
    }

    // MARK: - Suggestions List

    private func suggestionsList(stops: [Stop], isOrigin: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(stops.prefix(5)) { stop in
                Button {
                    selectStop(stop, isOrigin: isOrigin)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stop.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            if let connections = formatConnections(stop) {
                                Text(connections)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if stop.isHub {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)

                if stop.id != stops.prefix(5).last?.id {
                    Divider()
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    private func formatConnections(_ stop: Stop) -> String? {
        var parts: [String] = []
        if let metro = stop.corMetro { parts.append(metro) }
        if let cercanias = stop.corCercanias { parts.append(cercanias) }
        if let ml = stop.corMl { parts.append(ml) }
        if let tram = stop.corTranvia { parts.append(tram) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Actions

    private func searchStops(query: String, isOrigin: Bool) {
        guard query.count >= 2 else {
            if isOrigin {
                originSuggestions = []
            } else {
                destinationSuggestions = []
            }
            return
        }

        Task {
            let stops = await dataService.searchStops(query: query)
            await MainActor.run {
                if isOrigin {
                    originSuggestions = stops
                } else {
                    destinationSuggestions = stops
                }
            }
        }
    }

    private func selectStop(_ stop: Stop, isOrigin: Bool) {
        if isOrigin {
            selectedOrigin = stop
            originText = stop.name
            originSuggestions = []
            focusedField = .destination
        } else {
            selectedDestination = stop
            destinationText = stop.name
            destinationSuggestions = []
            focusedField = nil
        }
        journey = nil
    }

    private func swapOriginDestination() {
        let tempStop = selectedOrigin
        let tempText = originText

        selectedOrigin = selectedDestination
        originText = destinationText

        selectedDestination = tempStop
        destinationText = tempText

        journey = nil
    }

    private func calculateRoute() async {
        guard let origin = selectedOrigin,
              let destination = selectedDestination,
              let routing = routingService else { return }

        isCalculating = true
        errorMessage = nil

        do {
            if let result = await routing.findRoute(from: origin.id, to: destination.id) {
                await MainActor.run {
                    journey = result
                    isCalculating = false
                }
            } else {
                await MainActor.run {
                    errorMessage = "No se encontro ruta entre estas estaciones"
                    isCalculating = false
                }
            }
        }
    }
}

// MARK: - Journey Result View

struct JourneyResultView: View {
    let journey: Journey
    let dataService: DataService
    let onPreview: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Summary header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(journey.totalDurationMinutes) min")
                        .font(.title)
                        .fontWeight(.bold)

                    HStack(spacing: 12) {
                        if journey.transferCount > 0 {
                            Label("\(journey.transferCount) transbordo\(journey.transferCount > 1 ? "s" : "")",
                                  systemImage: "arrow.triangle.branch")
                        }
                        if journey.totalWalkingMinutes > 0 {
                            Label("\(journey.totalWalkingMinutes) min andando",
                                  systemImage: "figure.walk")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Preview button
                Button {
                    onPreview()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                        Text("Ver en 3D")
                            .font(.caption2)
                    }
                    .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)

            // Segments timeline
            VStack(spacing: 0) {
                ForEach(Array(journey.segments.enumerated()), id: \.element.id) { index, segment in
                    SegmentRowView(
                        segment: segment,
                        isFirst: index == 0,
                        isLast: index == journey.segments.count - 1,
                        dataService: dataService
                    )
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Segment Row View

struct SegmentRowView: View {
    let segment: JourneySegment
    let isFirst: Bool
    let isLast: Bool
    let dataService: DataService

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle()
                        .fill(timelineColor)
                        .frame(width: 3, height: 20)
                } else {
                    Spacer().frame(width: 3, height: 20)
                }

                // Icon
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 36, height: 36)

                    Image(systemName: segment.transportMode.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                if !isLast {
                    Rectangle()
                        .fill(timelineColor)
                        .frame(width: 3, height: 40)
                } else {
                    Spacer().frame(width: 3, height: 20)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Origin
                HStack {
                    Text(segment.origin.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    if let lineName = segment.lineName {
                        Text(lineName)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hex: segment.lineColor ?? "#007AFF") ?? .blue)
                            )
                    }
                }

                // Duration and stops info
                HStack {
                    if segment.type == .transit {
                        Text("\(segment.stopCount) parada\(segment.stopCount > 1 ? "s" : "") · \(segment.durationMinutes) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Andando · \(segment.durationMinutes) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Destination (for last segment)
                if isLast {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.red)
                        Text(segment.destination.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.vertical, 8)

            Spacer()
        }
        .padding(.horizontal)
    }

    private var timelineColor: Color {
        if let hex = segment.lineColor {
            return Color(hex: hex) ?? .gray
        }
        return segment.type == .walking ? .gray : .blue
    }

    private var iconBackgroundColor: Color {
        if segment.type == .walking {
            return Color(.systemGray5)
        }
        if let hex = segment.lineColor {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }

    private var iconColor: Color {
        segment.type == .walking ? .primary : .white
    }
}

#Preview {
    JourneyPlannerView(
        dataService: DataService(),
        locationService: LocationService()
    )
}
