//
//  ArrivalCard.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//

import SwiftUI

struct ArrivalCard: View {
    let arrival: Arrival
    let lineColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Line and destination
            HStack {
                Text(arrival.lineName)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(lineColor)

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(arrival.destination)
                    .font(.subheadline)
                    .lineLimit(1)
            }

            // Progress bar, time, and platform
            HStack {
                ProgressView(value: arrival.progressValue)
                    .tint(arrival.isDelayed ? .orange : lineColor)
                    .frame(height: 4)

                // Show frequency for Metro, or time for Cercanías
                if arrival.frequencyBased, let headway = arrival.headwayMinutes {
                    Text("c/\(headway) min")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                } else {
                    Text(arrival.arrivalTimeString)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }

                // Platform badge (if available)
                if let platform = arrival.platform, !platform.isEmpty {
                    HStack(spacing: 2) {
                        Text("Vía \(platform)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                        // Estimated indicator
                        if arrival.platformEstimated {
                            Text("*")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
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
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)

                    Text("+\(arrival.delayMinutes) min delay")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Train position indicator (if available)
            if arrival.hasTrainPosition {
                HStack(spacing: 4) {
                    Image(systemName: "tram.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)

                    if let statusText = arrival.trainStatusText, let stopName = arrival.trainCurrentStop {
                        Text("\(statusText) \(stopName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else if let stopName = arrival.trainCurrentStop {
                        Text(stopName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}

#Preview {
    let mockArrival = Arrival(
        id: "1",
        lineId: "c3",
        lineName: "C3",
        destination: "Aranjuez",
        scheduledTime: Date().addingTimeInterval(5 * 60),
        expectedTime: Date().addingTimeInterval(12 * 60),
        platform: "1",
        platformEstimated: true,
        trainCurrentStop: "Atocha",
        trainProgressPercent: 75.0,
        trainLatitude: 40.4067,
        trainLongitude: -3.6934,
        trainStatus: "IN_TRANSIT_TO",
        trainEstimated: false,
        delaySeconds: 120,
        routeColor: "#813380",
        frequencyBased: false,
        headwayMinutes: nil
    )

    ArrivalCard(arrival: mockArrival, lineColor: .blue)
        .padding()
}
