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
                // Time display - show actual minutes for all lines
                if arrival.minutesUntilArrival > 30 && !arrival.isCercaniasLine {
                    Text("+ 30 min")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(arrival.arrivalTimeString)
                            .font(.headline)
                            .fontWeight(.bold)

                        // Show frequency indicator for Metro/ML/Tranvía
                        if arrival.frequencyBased, let headway = arrival.headwayMinutes {
                            Text("freq. \(headway) min")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Occupancy indicator (currently only TMB Metro Barcelona)
                if arrival.hasOccupancyData {
                    OccupancyIndicator(level: arrival.occupancyLevel, percentage: arrival.occupancyPercentage)
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

                // Offline indicator
                if arrival.isOfflineData {
                    HStack(spacing: 2) {
                        Image(systemName: "icloud.slash")
                            .font(.caption2)
                        Text("offline")
                    }
                    .font(.caption)
                    .foregroundStyle(.gray)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Occupancy Indicator

/// Visual indicator for train occupancy level
struct OccupancyIndicator: View {
    let level: OccupancyLevel
    let percentage: Int?

    var body: some View {
        HStack(spacing: 3) {
            // Colored circle indicator
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)

            // Person icons based on level
            Image(systemName: level.iconName)
                .font(.caption2)
                .foregroundStyle(indicatorColor)

            // Percentage if available
            if let pct = percentage {
                Text("\(pct)%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(indicatorColor.opacity(0.15))
        .cornerRadius(4)
    }

    private var indicatorColor: Color {
        switch level {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        case .unknown: return .gray
        }
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
                headwayMinutes: nil,
                isOfflineData: false,
                occupancyStatus: nil,
                occupancyPercentage: nil
            ),
            dataService: DataService()
        )

        // Metro Barcelona con ocupación
        ArrivalRowView(
            arrival: Arrival(
                id: "2",
                lineId: "TMB_METRO_L1",
                lineName: "L1",
                destination: "Hospital de Bellvitge",
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
                routeColor: "#E23131",
                routeId: "TMB_METRO_L1",
                frequencyBased: true,
                headwayMinutes: 5,
                isOfflineData: false,
                occupancyStatus: 2,  // FEW_SEATS_AVAILABLE
                occupancyPercentage: 45
            ),
            dataService: DataService()
        )
    }
    .padding()
}
