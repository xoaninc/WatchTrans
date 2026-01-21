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
            // Cercanías: green (on time) / orange (delayed)
            // Metro/ML: line color (no real-time delay info)
            HStack {
                ProgressView(value: arrival.progressValue)
                    .tint(arrival.isMetroLine ? lineColor : (arrival.isDelayed ? .orange : .green))
                    .frame(height: 4)

                // Show actual minutes until arrival for all lines
                // For frequency-based (Metro/ML): show minutes + frequency indicator
                // For Cercanías >= 30 min: show actual time
                // For non-Cercanías > 30 min: show "+ 30 min"
                if arrival.minutesUntilArrival > 30 && !arrival.isCercaniasLine {
                    Text("+ 30 min")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 2) {
                        Text(arrival.arrivalTimeString)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        // Show frequency indicator for Metro/ML/Tranvía
                        if arrival.frequencyBased, let headway = arrival.headwayMinutes {
                            Text("(freq. \(headway))")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Platform badge (if available)
                // Color indicates confidence: blue = confirmed, orange = estimated
                if let platform = arrival.platform, !platform.isEmpty {
                    Text("Vía \(platform)")
                        .font(.caption2)
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
        routeId: "RENFE_C3_36",
        frequencyBased: false,
        headwayMinutes: nil
    )

    ArrivalCard(arrival: mockArrival, lineColor: .blue)
        .padding()
}
