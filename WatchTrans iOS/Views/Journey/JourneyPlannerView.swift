//
//  JourneyPlannerView.swift
//  WatchTrans iOS
//
//  Created by Claude on 26/1/26.
//  View for planning journeys between two stops
//  Updated 27/1/26 to use API route planner instead of local RoutingService
//

import SwiftUI

struct JourneyPlannerView: View {
    let dataService: DataService
    let locationService: LocationService

    @State private var originText = ""
    @State private var destinationText = ""
    @State private var selectedOrigin: Stop?
    @State private var selectedDestination: Stop?
    @State private var originSuggestions: [Stop] = []
    @State private var destinationSuggestions: [Stop] = []
    @State private var isSearchingOrigin = false
    @State private var isSearchingDestination = false
    @State private var routePlanResult: DataService.RoutePlanResult?
    @State private var selectedJourney: Journey?  // Currently displayed journey
    @State private var isCalculating = false
    @State private var showAnimation = false
    @State private var showAlternatives = false
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
                    if let journey = selectedJourney {
                        JourneyResultView(
                            journey: journey,
                            dataService: dataService,
                            onPreview: {
                                showAnimation = true
                            }
                        )

                        // Alternatives section (collapsible)
                        if let result = routePlanResult, result.alternativeJourneys.count > 0 {
                            alternativesSection(alternatives: result.alternativeJourneys)
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Planificar viaje")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(isPresented: $showAnimation) {
                if let journey = selectedJourney {
                    Journey3DAnimationView(journey: journey, dataService: dataService)
                }
            }
        }
    }

    // MARK: - Search Card

    private var currentRegionName: String {
        dataService.currentLocation?.provinceName ?? "Tu zona"
    }

    private var searchCard: some View {
        VStack(spacing: 16) {
            // Region indicator
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
                Text("Buscando en \(currentRegionName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)

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
                            routePlanResult = nil
                            selectedJourney = nil
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
                            routePlanResult = nil
                            selectedJourney = nil
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
        routePlanResult = nil
        selectedJourney = nil
    }

    private func swapOriginDestination() {
        let tempStop = selectedOrigin
        let tempText = originText

        selectedOrigin = selectedDestination
        originText = destinationText

        selectedDestination = tempStop
        destinationText = tempText

        routePlanResult = nil
        selectedJourney = nil
    }

    private func calculateRoute() async {
        guard let origin = selectedOrigin,
              let destination = selectedDestination else { return }

        isCalculating = true
        errorMessage = nil
        showAlternatives = false

        // Use API route planner via DataService
        if let result = await dataService.planJourneys(fromStopId: origin.id, toStopId: destination.id) {
            await MainActor.run {
                routePlanResult = result
                selectedJourney = result.bestJourney
                isCalculating = false
            }
        } else {
            await MainActor.run {
                routePlanResult = nil
                selectedJourney = nil
                errorMessage = "No se encontro ruta entre estas estaciones"
                isCalculating = false
            }
        }
    }

    // MARK: - Alternatives Section

    private func alternativesSection(alternatives: [Journey]) -> some View {
        VStack(spacing: 0) {
            // Header (tap to expand/collapse)
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showAlternatives.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(.blue)
                    Text("\(alternatives.count) alternativa\(alternatives.count > 1 ? "s" : "")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: showAlternatives ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            // Alternatives list (collapsible)
            if showAlternatives {
                VStack(spacing: 8) {
                    ForEach(Array(alternatives.enumerated()), id: \.element.id) { index, alternative in
                        AlternativeRowView(
                            journey: alternative,
                            index: index + 2,  // "Ruta 2", "Ruta 3", etc.
                            isSelected: selectedJourney?.id == alternative.id,
                            onSelect: {
                                withAnimation {
                                    selectedJourney = alternative
                                }
                            }
                        )
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Alternative Row View

struct AlternativeRowView: View {
    let journey: Journey
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ruta \(index)")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    HStack(spacing: 12) {
                        Label("\(journey.totalDurationMinutes) min", systemImage: "clock")
                        if journey.transferCount > 0 {
                            Label("\(journey.transferCount)", systemImage: "arrow.triangle.branch")
                        }
                        if journey.totalWalkingMinutes > 0 {
                            Label("\(journey.totalWalkingMinutes) min", systemImage: "figure.walk")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Line badges
                    HStack(spacing: 4) {
                        ForEach(journey.segments.filter { $0.type == .transit }, id: \.id) { segment in
                            if let lineName = segment.lineName {
                                Text(lineName)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(hex: segment.lineColor ?? "#007AFF") ?? .blue)
                                    )
                            }
                        }
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
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
                        isLast: false,  // Never show inline destination
                        dataService: dataService
                    )
                }

                // Final destination row
                DestinationRowView(destination: journey.destination)
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

// MARK: - Destination Row View

struct DestinationRowView: View {
    let destination: Stop

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.red.opacity(0.5))
                    .frame(width: 3, height: 20)

                // Destination icon
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 36, height: 36)

                    Image(systemName: "flag.checkered")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer().frame(width: 3, height: 20)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text("Destino")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(destination.name)
                    .font(.subheadline)
                    .fontWeight(.bold)

                if destination.isHub {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption2)
                        Text("Intercambiador")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)

            Spacer()
        }
        .padding(.horizontal)
    }
}

#Preview {
    JourneyPlannerView(
        dataService: DataService(),
        locationService: LocationService()
    )
}
