//
//  TrainDetailView.swift
//  WatchTrans iOS
//
//  Shows detailed train/arrival information
//

import SwiftUI

struct TrainDetailView: View {
    let arrival: Arrival
    let lineColor: Color
    var dataService: DataService?

    @State private var alerts: [AlertResponse] = []
    @State private var isAlertsExpanded = false
    @State private var isLoadingAlerts = false

    // Trip journey (recorrido completo)
    @State private var tripDetail: TripDetailResponse?
    @State private var isLoadingTrip = false
    @State private var isJourneyExpanded = true

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Train header card
                VStack(spacing: 12) {
                    HStack {
                        // Line badge
                        Text(arrival.lineName)
                            .font(.title)
                            .fontWeight(.heavy)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(lineColor)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                Text(arrival.destination)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }

                            if arrival.frequencyBased {
                                Text("Servicio por frecuencia")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)

                // Time section
                VStack(alignment: .leading, spacing: 12) {
                    Label("Llegada", systemImage: "clock.fill")
                        .font(.headline)
                        .foregroundStyle(.blue)

                    HStack {
                        Text(arrival.arrivalTimeString)
                            .font(.system(size: 48, weight: .bold, design: .rounded))

                        Spacer()

                        // Delay badge
                        if arrival.isDelayed {
                            VStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title2)
                                Text("+\(arrival.delayMinutes) min")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange)
                            )
                        }
                    }

                    // Progress bar
                    ProgressView(value: arrival.progressValue)
                        .tint(arrival.isMetroLine ? lineColor : (arrival.isDelayed ? .orange : .green))
                        .scaleEffect(y: 2)
                        .padding(.top, 4)

                    // Frequency info
                    if arrival.frequencyBased, let headway = arrival.headwayMinutes {
                        HStack {
                            Image(systemName: "repeat")
                                .foregroundStyle(.secondary)
                            Text("Frecuencia: cada \(headway) minutos")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)

                // Platform section
                if let platform = arrival.platform, !platform.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Anden", systemImage: "train.side.front.car")
                            .font(.headline)
                            .foregroundStyle(.blue)

                        HStack(alignment: .firstTextBaseline) {
                            Text("Via")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text(platform)
                                .font(.system(size: 48, weight: .bold, design: .rounded))

                            Spacer()

                            if arrival.platformEstimated {
                                Label("Estimada", systemImage: "questionmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(8)
                            } else {
                                Label("Confirmada", systemImage: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                }

                // Train position section
                VStack(alignment: .leading, spacing: 12) {
                    Label("Posicion del tren", systemImage: arrival.hasTrainPosition ? "location.fill" : "location.slash")
                        .font(.headline)
                        .foregroundStyle(arrival.hasTrainPosition ? .blue : .secondary)

                    if arrival.hasTrainPosition {
                        HStack(spacing: 16) {
                            Image(systemName: "tram.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(lineColor)

                            VStack(alignment: .leading, spacing: 4) {
                                if let statusText = arrival.trainStatusText {
                                    Text(statusText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if let currentStop = arrival.trainCurrentStop {
                                    Text(currentStop)
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                }
                            }

                            Spacer()

                            if let progress = arrival.trainProgressPercent {
                                VStack {
                                    Text("\(Int(progress))%")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text("recorrido")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Estimated indicator
                        if arrival.trainEstimated == true {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                Text("Posicion estimada basada en horarios")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        }
                    } else {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("Informacion de posicion no disponible")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)

                // Journey section (recorrido completo)
                if !arrival.frequencyBased {
                    JourneySectionView(
                        tripDetail: tripDetail,
                        isLoading: isLoadingTrip,
                        isExpanded: $isJourneyExpanded,
                        currentStopName: arrival.trainCurrentStop,
                        lineColor: lineColor
                    )
                }

                // Alerts section
                if isLoadingAlerts {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Cargando avisos...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                } else if !alerts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        // Header with count - tappable to expand
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isAlertsExpanded.toggle()
                            }
                        } label: {
                            HStack {
                                Label("\(alerts.count) aviso\(alerts.count == 1 ? "" : "s")", systemImage: "exclamationmark.triangle.fill")
                                    .font(.headline)
                                    .foregroundStyle(.orange)

                                Spacer()

                                Image(systemName: isAlertsExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        // Expanded alert details
                        if isAlertsExpanded {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(alerts) { alert in
                                    VStack(alignment: .leading, spacing: 6) {
                                        if let header = alert.headerText, !header.isEmpty {
                                            Text(header)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                        }
                                        if let description = alert.descriptionText, !description.isEmpty {
                                            Text(description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
            }
            .padding()
        }
        .background(Color(.systemGray6))
        .navigationTitle("Detalles del tren")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAlerts()
            await loadTripDetails()
        }
    }

    private func loadTripDetails() async {
        guard let dataService = dataService,
              !arrival.frequencyBased else { return }
        isLoadingTrip = true
        tripDetail = await dataService.fetchTripDetails(tripId: arrival.id)
        isLoadingTrip = false
    }

    private func loadAlerts() async {
        guard let dataService = dataService,
              let routeId = arrival.routeId else { return }
        isLoadingAlerts = true
        alerts = await dataService.fetchAlertsForRoute(routeId: routeId)
        isLoadingAlerts = false
    }
}

// MARK: - Journey Section View

struct JourneySectionView: View {
    let tripDetail: TripDetailResponse?
    let isLoading: Bool
    @Binding var isExpanded: Bool
    let currentStopName: String?
    let lineColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header - tappable to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("Recorrido completo", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.headline)
                        .foregroundStyle(.blue)

                    Spacer()

                    if let trip = tripDetail {
                        Text("\(trip.stops.count) paradas")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Content
            if isLoading {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Cargando recorrido...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if let trip = tripDetail, isExpanded {
                JourneyStopsListView(
                    stops: trip.stops,
                    currentStopName: currentStopName,
                    lineColor: lineColor
                )
            } else if tripDetail == nil && !isLoading {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Recorrido no disponible")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Journey Stops List View

struct JourneyStopsListView: View {
    let stops: [TripStopResponse]
    let currentStopName: String?
    let lineColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.element.stopId) { index, stop in
                let status = stopStatus(for: stop, at: index)

                HStack(alignment: .top, spacing: 12) {
                    // Timeline indicator
                    VStack(spacing: 0) {
                        // Top line (not for first stop)
                        if index > 0 {
                            Rectangle()
                                .fill(status == .passed ? lineColor : Color.gray.opacity(0.3))
                                .frame(width: 3, height: 12)
                        } else {
                            Spacer().frame(height: 12)
                        }

                        // Stop indicator
                        ZStack {
                            Circle()
                                .fill(stopIndicatorColor(for: status))
                                .frame(width: 24, height: 24)

                            if status == .current {
                                Image(systemName: "tram.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white)
                            } else if status == .passed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            } else if index == stops.count - 1 {
                                // Destination
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 8, height: 8)
                            }
                        }

                        // Bottom line (not for last stop)
                        if index < stops.count - 1 {
                            Rectangle()
                                .fill(status == .passed || status == .current ? lineColor : Color.gray.opacity(0.3))
                                .frame(width: 3, height: 20)
                        } else {
                            Spacer().frame(height: 20)
                        }
                    }

                    // Stop info
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(stop.stopName)
                                .font(status == .current ? .subheadline.bold() : .subheadline)
                                .foregroundStyle(status == .passed ? .secondary : .primary)

                            if status == .current {
                                Text("← Aqui")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(lineColor)
                                    .cornerRadius(4)
                            }
                        }

                        Text(formatTime(stop.arrivalTime))
                            .font(.caption)
                            .foregroundStyle(status == .passed ? .tertiary : .secondary)
                    }
                    .padding(.vertical, 4)

                    Spacer()
                }
            }
        }
    }

    // MARK: - Helpers

    enum StopStatus {
        case passed
        case current
        case upcoming
    }

    private func stopStatus(for stop: TripStopResponse, at index: Int) -> StopStatus {
        guard let currentName = currentStopName else {
            // No current stop info - assume all upcoming
            return .upcoming
        }

        // Find current stop index
        if let currentIndex = stops.firstIndex(where: {
            $0.stopName.localizedCaseInsensitiveCompare(currentName) == .orderedSame
        }) {
            if index < currentIndex {
                return .passed
            } else if index == currentIndex {
                return .current
            }
        }

        return .upcoming
    }

    private func stopIndicatorColor(for status: StopStatus) -> Color {
        switch status {
        case .passed:
            return lineColor.opacity(0.6)
        case .current:
            return lineColor
        case .upcoming:
            return Color.gray.opacity(0.3)
        }
    }

    private func formatTime(_ timeString: String) -> String {
        // Input: "HH:mm:ss", Output: "HH:mm"
        let components = timeString.split(separator: ":")
        if components.count >= 2 {
            return "\(components[0]):\(components[1])"
        }
        return timeString
    }
}

#Preview {
    NavigationStack {
        TrainDetailView(
            arrival: Arrival(
                id: "1",
                lineId: "c3",
                lineName: "C3",
                destination: "Aranjuez",
                scheduledTime: Date().addingTimeInterval(5 * 60),
                expectedTime: Date().addingTimeInterval(8 * 60),
                platform: "10",
                platformEstimated: false,
                trainCurrentStop: "Sol",
                trainProgressPercent: 45.0,
                trainLatitude: 40.4168,
                trainLongitude: -3.7038,
                trainStatus: "IN_TRANSIT_TO",
                trainEstimated: false,
                delaySeconds: 180,
                routeColor: "#813380",
                routeId: "RENFE_C3_36",
                frequencyBased: false,
                headwayMinutes: nil
            ),
            lineColor: Color(red: 129/255, green: 51/255, blue: 128/255)
        )
    }
}
