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
        }
    }

    private func loadAlerts() async {
        guard let dataService = dataService,
              let routeId = arrival.routeId else { return }
        isLoadingAlerts = true
        alerts = await dataService.fetchAlertsForRoute(routeId: routeId)
        isLoadingAlerts = false
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
