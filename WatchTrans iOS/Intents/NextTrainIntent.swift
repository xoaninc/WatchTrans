//
//  NextTrainIntent.swift
//  WatchTrans iOS
//
//  Created by Claude on 27/1/26.
//  Siri Shortcut: "When is the next train at [stop]?"
//

import AppIntents
import Foundation

// MARK: - Next Train Intent

/// Siri Shortcut that returns upcoming departures for a stop
/// User can say: "Hey Siri, next train at Sol" or "When is the next train at Atocha?"
struct NextTrainIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Train"
    static var description = IntentDescription("Get upcoming departures for a transit stop")

    /// The stop to query - Siri will ask for this if not provided
    @Parameter(title: "Stop", description: "The transit stop to check")
    var stop: StopEntity

    /// How many departures to show
    @Parameter(title: "Number of departures", default: 3)
    var limit: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Next train at \(\.$stop)")
    }

    /// Phrases that trigger this shortcut
    static var openAppWhenRun: Bool = false

    // Base URL for API (local constant to avoid MainActor issues)
    private static let apiBaseURL = "https://redcercanias.com/api/v1/gtfs"

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        // Fetch departures from API
        let departures = try await fetchDepartures(stopId: stop.id, limit: limit)

        if departures.isEmpty {
            return .result(
                dialog: "No upcoming departures found for \(stop.name)"
            ) {
                NextTrainSnippetView(stopName: stop.name, departures: [])
            }
        }

        // Build response text
        let firstDeparture = departures[0]
        let responseText: String

        if firstDeparture.minutes <= 1 {
            responseText = "The next \(firstDeparture.line) to \(firstDeparture.headsign) is arriving now at \(stop.name)"
        } else {
            responseText = "The next \(firstDeparture.line) to \(firstDeparture.headsign) arrives in \(firstDeparture.minutes) minutes at \(stop.name)"
        }

        return .result(
            dialog: "\(responseText)"
        ) {
            NextTrainSnippetView(stopName: stop.name, departures: departures)
        }
    }

    // MARK: - API Call

    private func fetchDepartures(stopId: String, limit: Int) async throws -> [SiriDeparture] {
        let urlString = "\(Self.apiBaseURL)/stops/\(stopId)/departures?limit=\(limit)"

        guard let url = URL(string: urlString) else {
            throw IntentError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw IntentError.apiError
        }

        let decoder = JSONDecoder()
        let apiDepartures = try decoder.decode([APIDeparture].self, from: data)

        return apiDepartures.prefix(limit).map { dep in
            SiriDeparture(
                line: dep.routeShortName,
                headsign: dep.headsign ?? "Unknown",
                minutes: dep.realtimeMinutesUntil ?? dep.minutesUntil,
                isRealtime: dep.realtimeMinutesUntil != nil
            )
        }
    }
}

// MARK: - Intent Errors

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case invalidURL
    case apiError
    case noData

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .apiError: return "Could not fetch departures"
        case .noData: return "No departure data available"
        }
    }
}

// MARK: - API Models (for decoding)

private struct APIDeparture: Codable {
    let routeShortName: String
    let headsign: String?
    let minutesUntil: Int
    let realtimeMinutesUntil: Int?

    enum CodingKeys: String, CodingKey {
        case routeShortName = "route_short_name"
        case headsign
        case minutesUntil = "minutes_until"
        case realtimeMinutesUntil = "realtime_minutes_until"
    }
}

// MARK: - Siri Departure Model

struct SiriDeparture: Identifiable {
    let id = UUID()
    let line: String
    let headsign: String
    let minutes: Int
    let isRealtime: Bool
}

// MARK: - Snippet View (shown in Siri UI)

import SwiftUI

struct NextTrainSnippetView: View {
    let stopName: String
    let departures: [SiriDeparture]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stopName)
                .font(.headline)

            if departures.isEmpty {
                Text("No departures")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(departures) { departure in
                    HStack {
                        Text(departure.line)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(6)

                        Text(departure.headsign)
                            .font(.subheadline)
                            .lineLimit(1)

                        Spacer()

                        HStack(spacing: 2) {
                            Text("\(departure.minutes)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if departure.isRealtime {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
}
