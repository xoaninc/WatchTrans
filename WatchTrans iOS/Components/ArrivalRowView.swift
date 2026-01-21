//
//  ArrivalRowView.swift
//  WatchTrans iOS
//
//  Created by Juan Macias Gomez on 21/1/26.
//

import SwiftUI

struct ArrivalRowView: View {
    let arrival: Arrival
    let dataService: DataService

    var lineColor: Color {
        if let hex = arrival.routeColor {
            return Color(hex: hex) ?? .blue
        }
        return dataService.getLine(by: arrival.lineId)?.color ?? .blue
    }

    var body: some View {
        HStack(spacing: 12) {
            // Line badge
            Text(arrival.lineName)
                .font(.headline)
                .fontWeight(.heavy)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(lineColor)
                )
                .frame(minWidth: 50)

            // Destination and info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(arrival.destination)
                        .font(.body)
                        .lineLimit(1)
                }

                // Train position (if available)
                if arrival.hasTrainPosition {
                    HStack(spacing: 4) {
                        Image(systemName: "tram.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        if let statusText = arrival.trainStatusText, let stopName = arrival.trainCurrentStop {
                            Text("\(statusText) \(stopName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else if let stopName = arrival.trainCurrentStop {
                            Text(stopName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                // Progress bar
                ProgressView(value: arrival.progressValue)
                    .tint(arrival.isMetroLine ? lineColor : (arrival.isDelayed ? .orange : .green))
            }

            Spacer()

            // Time and platform
            VStack(alignment: .trailing, spacing: 4) {
                // Time display
                if arrival.frequencyBased, let headway = arrival.headwayMinutes {
                    if arrival.minutesUntilArrival > 30 {
                        Text("+ 30 min")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("c/\(headway) min")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(arrival.arrivalTimeString)
                        .font(.headline)
                        .fontWeight(.bold)
                }

                // Platform badge (if available)
                if let platform = arrival.platform, !platform.isEmpty {
                    HStack(spacing: 2) {
                        Text("Via \(platform)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(arrival.platformEstimated ? Color.orange.opacity(0.8) : Color.blue.opacity(0.8))
                            )
                    }
                }

                // Delay indicator
                if arrival.isDelayed {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("+\(arrival.delayMinutes)")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    VStack(spacing: 8) {
        ArrivalRowView(
            arrival: Arrival(
                id: "1",
                lineId: "c3",
                lineName: "C3",
                destination: "Aranjuez",
                scheduledTime: Date().addingTimeInterval(5 * 60),
                expectedTime: Date().addingTimeInterval(8 * 60),
                platform: "4",
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
            dataService: DataService()
        )

        ArrivalRowView(
            arrival: Arrival(
                id: "2",
                lineId: "l1",
                lineName: "L1",
                destination: "Valdecarros",
                scheduledTime: Date().addingTimeInterval(2 * 60),
                expectedTime: Date().addingTimeInterval(2 * 60),
                platform: nil,
                platformEstimated: false,
                trainCurrentStop: nil,
                trainProgressPercent: nil,
                trainLatitude: nil,
                trainLongitude: nil,
                trainStatus: nil,
                trainEstimated: nil,
                delaySeconds: nil,
                routeColor: "#2ca5dd",
                routeId: "METRO_L1_123",
                frequencyBased: true,
                headwayMinutes: 5
            ),
            dataService: DataService()
        )
    }
    .padding()
}
