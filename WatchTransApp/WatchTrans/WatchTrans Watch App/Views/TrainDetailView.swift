//
//  TrainDetailView.swift
//  WatchTrans Watch App
//
//  Shows detailed train information including position
//

import SwiftUI

struct TrainDetailView: View {
    let arrival: Arrival
    let lineColor: Color

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Train header
                HStack {
                    Text(arrival.lineName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(lineColor)

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(arrival.destination)
                        .font(.headline)
                        .lineLimit(2)
                }
                .padding(.horizontal, 8)

                // Time section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text("Llegada")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text(arrival.arrivalTimeString)
                            .font(.title3)
                            .fontWeight(.bold)

                        Spacer()

                        // Delay badge
                        if arrival.isDelayed {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                Text("+\(arrival.delayMinutes) min")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.orange)
                            )
                        }
                    }

                    // Progress bar
                    ProgressView(value: arrival.progressValue)
                        .tint(arrival.isDelayed ? .orange : .green)
                }
                .padding(12)
                .background(.regularMaterial)
                .cornerRadius(12)

                // Platform section
                if let platform = arrival.platform, !platform.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "train.side.front.car")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text("Andén")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text("Vía \(platform)")
                                .font(.title3)
                                .fontWeight(.bold)

                            if arrival.platformEstimated {
                                Text("(estimada)")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(12)
                    .background(.regularMaterial)
                    .cornerRadius(12)
                }

                // Train position section
                if arrival.hasTrainPosition {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text("Posición del tren")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        // Status and current stop
                        if let currentStop = arrival.trainCurrentStop {
                            HStack {
                                Image(systemName: "tram.fill")
                                    .font(.body)
                                    .foregroundStyle(lineColor)

                                VStack(alignment: .leading, spacing: 2) {
                                    if let statusText = arrival.trainStatusText {
                                        Text(statusText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(currentStop)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                            }
                        }

                        // Estimated indicator
                        if arrival.trainEstimated == true {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                                Text("Posición estimada")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(.regularMaterial)
                    .cornerRadius(12)
                } else {
                    // No position available
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "location.slash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Posición")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Text("Información no disponible")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.regularMaterial)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .navigationTitle(arrival.lineName)
        .navigationBarTitleDisplayMode(.inline)
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
                platform: "10-11",
                platformEstimated: false,
                trainCurrentStop: "Sol",
                trainProgressPercent: 45.0,
                trainLatitude: 40.4168,
                trainLongitude: -3.7038,
                trainStatus: "IN_TRANSIT_TO",
                trainEstimated: false,
                delaySeconds: 180,
                routeColor: "#813380",
                frequencyBased: false,
                headwayMinutes: nil
            ),
            lineColor: Color(red: 129/255, green: 51/255, blue: 128/255)
        )
    }
}
