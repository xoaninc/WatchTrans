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
    var airQuality: TrainAirQuality? = nil

    var lineColor: Color {
        if let hex = arrival.routeColor {
            return Color(hex: hex) ?? .blue
        }
        return dataService.getLine(by: arrival.lineId)?.color ?? .blue
    }
    
    /// Metro Ligero and Ramal use inverted style: white background, colored border and text
    var isMetroLigero: Bool {
        arrival.lineName.hasPrefix("ML") || arrival.lineName == "R"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Line badge
            if isMetroLigero {
                // Metro Ligero: white background, colored border and text
                Text(arrival.lineName)
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundStyle(lineColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(lineColor, lineWidth: 2)
                            )
                    )
                    .frame(minWidth: 50)
            } else {
                // Standard: colored background, white text
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
            }

            // Destination and info
            VStack(alignment: .leading, spacing: 4) {
                // Destination + train code + composition + icons
                // Icons go to line 2 only when composition is shown (Metro Sevilla /Doble)
                let showsComposition = arrival.isDoubleComposition && arrival.routeId?.hasPrefix("METRO_SEVILLA") == true

                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(arrival.destination)
                        .font(.body)
                        .lineLimit(1)
                    if let code = arrival.trainCode, !code.isEmpty {
                        Text(code)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if showsComposition {
                        Text("/Doble")
                            .font(.body)
                            .foregroundStyle(.blue)
                    }

                    // Icons inline when no composition
                    if !showsComposition {
                        serviceIconsView
                    }
                }

                // Icons on line 2 only when composition takes too much space
                if showsComposition {
                    serviceIconsView
                }

                // Train position (if available)
                if arrival.hasTrainPosition {
                    HStack(spacing: 4) {
                        SymbolView(name: "TrenSymbol", size: 10)
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

                // Air quality indicator (Metro Sevilla)
                if let aq = airQuality {
                    AirQualityBadgeView(airQuality: aq)
                }

                // Progress bar
                ProgressView(value: arrival.progressValue)
                    .tint(arrival.isSuspended ? .red : (arrival.isMetroLine ? lineColor : (arrival.isDelayed ? .orange : .green)))
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

                // Occupancy indicator (TMB station occupancy or FGC vehicle occupancy)
                if arrival.hasOccupancyData {
                    OccupancyIndicator(level: arrival.occupancyLevel, percentage: arrival.occupancyPercentage)
                } else if let vehOcc = arrival.vehicleOccupancyStatus, vehOcc != 7, vehOcc != 8 {
                    let level: OccupancyLevel = switch vehOcc {
                    case 0, 1: .low
                    case 2, 3: .medium
                    case 4, 5, 6: .high
                    default: .unknown
                    }
                    OccupancyIndicator(level: level, percentage: nil)
                }

                // Platform badge (direction already shown in headsign above)
                if let platform = arrival.platform, !platform.isEmpty {
                    Text("Vía \(platform)")
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

                // Delay indicator
                if arrival.isDelayed {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("+\(arrival.delayMinutes)min")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
                
                // Suspension indicator (line closed)
                if arrival.isSuspended {
                    HStack(spacing: 2) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                        Text("CERRADA")
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                    )
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

    @ViewBuilder
    private var serviceIconsView: some View {
        let hasIcons = arrival.isExpress ||
            arrival.wheelchairAccessible || arrival.wheelchairInaccessible ||
            arrival.bikesAllowed == 1 ||
            arrival.isAlternativeService ||
            arrival.pmrWarning

        if hasIcons {
            HStack(spacing: 6) {
                if arrival.isExpress, let name = arrival.expressName {
                    Text(name)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: arrival.expressColor ?? arrival.routeColor ?? "") ?? .purple)
                        .cornerRadius(4)
                }
                if arrival.wheelchairAccessible {
                    SymbolView(name: "WheelchairSymbol", size: 12)
                        .foregroundStyle(.green)
                } else if arrival.wheelchairInaccessible {
                    NegatedSymbolView(name: "WheelchairSymbol", size: 12)
                        .foregroundStyle(.red)
                }
                if arrival.bikesAllowed == 1 {
                    Image(systemName: "bicycle")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                if arrival.isAlternativeService {
                    SymbolView(name: "BusSymbol", size: 12)
                        .foregroundStyle(.orange)
                }
                if arrival.pmrWarning {
                    HStack(spacing: 1) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                        SymbolView(name: "WheelchairSymbol", size: 10)
                    }
                    .foregroundStyle(.orange)
                }
            }
        }
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

// MARK: - Air Quality Badge

/// Compact air quality indicator for Metro Sevilla trains
struct AirQualityBadgeView: View {
    let airQuality: TrainAirQuality

    private var ratingColor: Color {
        switch airQuality.ratingColor {
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "aqi.medium")
                .font(.caption2)
                .foregroundStyle(ratingColor)

            if let temp = airQuality.temperature {
                Text("\(temp)\u{00B0}C")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let rating = airQuality.co2Rating {
                Text(rating)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(ratingColor)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(ratingColor.opacity(0.12))
        .cornerRadius(4)
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
                isSuspended: false,
                wheelchairAccessible: true,
                wheelchairInaccessible: false,
                frequencyBased: false,
                headwayMinutes: nil,
                isOfflineData: false,
                occupancyStatus: nil,
                occupancyPercentage: nil,
                routeTextColor: nil,
                isSkipped: nil,
                vehicleLat: nil,
                vehicleLon: nil,
                vehicleLabel: nil
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
                isSuspended: false,
                wheelchairAccessible: false,
                wheelchairInaccessible: false,
                frequencyBased: true,
                headwayMinutes: 5,
                isOfflineData: false,
                occupancyStatus: 2,  // FEW_SEATS_AVAILABLE
                occupancyPercentage: 45,
                routeTextColor: nil,
                isSkipped: nil,
                vehicleLat: nil,
                vehicleLon: nil,
                vehicleLabel: nil
            ),
            dataService: DataService()
        )
    }
    .padding()
}
