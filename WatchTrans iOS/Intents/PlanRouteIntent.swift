//
//  PlanRouteIntent.swift
//  WatchTrans iOS
//
//  Created by Claude on 28/1/26.
//  Siri Shortcut: "How do I get from X to Y?"
//  Uses the RAPTOR route planner API with ?compact=true for fast response
//

import AppIntents
import SwiftUI

// MARK: - Plan Route Intent

/// Siri Shortcut that plans a route between two stops using RAPTOR algorithm
/// User can say: "How do I get from Sol to Nuevos Ministerios?" or "Plan route from Atocha to Chamartin"
struct PlanRouteIntent: AppIntent {
    static var title: LocalizedStringResource = "Plan Route"
    static var description = IntentDescription("Plan a journey between two transit stops")

    /// Origin stop - Siri will ask for this if not provided
    @Parameter(title: "From", description: "Origin stop")
    var fromStop: StopEntity

    /// Destination stop - Siri will ask for this if not provided
    @Parameter(title: "To", description: "Destination stop")
    var toStop: StopEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Route from \(\.$fromStop) to \(\.$toStop)")
    }

    /// Don't open app when running
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        DebugLog.log("🗺️ [PlanRouteIntent] ▶️ Starting route plan via Siri")
        DebugLog.log("🗺️ [PlanRouteIntent]   From: \(fromStop.name) (ID: \(fromStop.id))")
        DebugLog.log("🗺️ [PlanRouteIntent]   To: \(toStop.name) (ID: \(toStop.id))")

        do {
            // Fetch route with compact=true for fast response (<5KB)
            let journey = try await fetchRoute(fromId: fromStop.id, toId: toStop.id)

            DebugLog.log("🗺️ [PlanRouteIntent] ✅ Route found:")
            DebugLog.log("🗺️ [PlanRouteIntent]   Duration: \(journey.durationMinutes) min")
            DebugLog.log("🗺️ [PlanRouteIntent]   Transfers: \(journey.transfers)")
            DebugLog.log("🗺️ [PlanRouteIntent]   Segments: \(journey.segments.count)")

            // Build response text
            let responseText = buildResponseText(journey: journey)

            return .result(
                dialog: "\(responseText)"
            ) {
                PlanRouteSnippetView(
                    fromName: fromStop.name,
                    toName: toStop.name,
                    journey: journey
                )
            }
        } catch PlanRouteError.noRouteFound {
            DebugLog.log("🗺️ [PlanRouteIntent] ❌ No route found")
            return .result(
                dialog: "No route found from \(fromStop.name) to \(toStop.name)"
            ) {
                PlanRouteErrorView(message: "No se encontro ruta entre \(fromStop.name) y \(toStop.name)")
            }
        } catch {
            DebugLog.log("🗺️ [PlanRouteIntent] ❌ Error: \(error)")
            return .result(
                dialog: "Could not plan route: \(error.localizedDescription)"
            ) {
                PlanRouteErrorView(message: "Error al planificar ruta")
            }
        }
    }

    // MARK: - API Call

    private func fetchRoute(fromId: String, toId: String) async throws -> SiriJourney {
        let baseURL = APIConfiguration.baseURL
        // Use compact=true for minimal response (<5KB, faster for Siri)
        let urlString = "\(baseURL)/route-planner?from=\(fromId)&to=\(toId)&compact=true"

        DebugLog.log("🗺️ [PlanRouteIntent] Fetching: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw PlanRouteError.invalidURL
        }

        let startTime = Date()
        let (data, response) = try await URLSession.shared.data(from: url)
        let elapsed = Date().timeIntervalSince(startTime)

        DebugLog.log("🗺️ [PlanRouteIntent] ⏱️ Response in \(String(format: "%.3f", elapsed))s")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlanRouteError.apiError
        }

        DebugLog.log("🗺️ [PlanRouteIntent]   HTTP Status: \(httpResponse.statusCode)")
        DebugLog.log("🗺️ [PlanRouteIntent]   Response size: \(data.count) bytes")

        guard httpResponse.statusCode == 200 else {
            throw PlanRouteError.apiError
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(CompactRoutePlanResponse.self, from: data)

        guard apiResponse.success, let journey = apiResponse.journeys?.first else {
            throw PlanRouteError.noRouteFound
        }

        DebugLog.log("🗺️ [PlanRouteIntent] ✅ Decoded journey: \(journey.durationMinutes) min, \(journey.segments.count) segments")

        return journey
    }

    private func buildResponseText(journey: SiriJourney) -> String {
        let durationText = "\(journey.durationMinutes) minutes"
        let transferText: String

        if journey.transfers == 0 {
            transferText = "with no transfers"
        } else if journey.transfers == 1 {
            transferText = "with 1 transfer"
        } else {
            transferText = "with \(journey.transfers) transfers"
        }

        // Build line summary
        let lines = journey.segments
            .filter { $0.type == "transit" }
            .compactMap { $0.routeName }

        let lineText = lines.isEmpty ? "" : " via \(lines.joined(separator: " then "))"

        return "The journey takes \(durationText) \(transferText)\(lineText)."
    }
}

// MARK: - Intent Errors

enum PlanRouteError: Error, CustomLocalizedStringResourceConvertible {
    case invalidURL
    case apiError
    case noRouteFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .apiError: return "Could not connect to service"
        case .noRouteFound: return "No route found"
        }
    }
}

// MARK: - Compact API Response Models

/// Compact response from route-planner?compact=true
/// Optimized for Widget/Siri (<5KB response)
struct CompactRoutePlanResponse: Codable {
    let success: Bool
    let message: String?
    let journeys: [SiriJourney]?
}

struct SiriJourney: Codable {
    let durationMinutes: Int
    let transfers: Int
    let walkingMinutes: Int
    let segments: [SiriSegment]

    enum CodingKeys: String, CodingKey {
        case durationMinutes = "duration_minutes"
        case transfers
        case walkingMinutes = "walking_minutes"
        case segments
    }
}

struct SiriSegment: Codable {
    let type: String  // "transit" or "walk"
    let routeId: String?
    let routeName: String?
    let routeColor: String?
    let fromStopName: String
    let toStopName: String
    let durationMinutes: Int

    enum CodingKeys: String, CodingKey {
        case type
        case routeId = "route_id"
        case routeName = "route_name"
        case routeColor = "route_color"
        case fromStopName = "from_stop_name"
        case toStopName = "to_stop_name"
        case durationMinutes = "duration_minutes"
    }
}

// MARK: - Snippet View (shown in Siri UI)

struct PlanRouteSnippetView: View {
    let fromName: String
    let toName: String
    let journey: SiriJourney

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(fromName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("→ \(toName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(journey.durationMinutes) min")
                        .font(.headline)
                        .fontWeight(.bold)
                    if journey.transfers > 0 {
                        Text("\(journey.transfers) transbordo\(journey.transfers > 1 ? "s" : "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // Segments
            ForEach(Array(journey.segments.enumerated()), id: \.offset) { index, segment in
                SiriSegmentRow(segment: segment, isLast: index == journey.segments.count - 1)
            }
        }
        .padding()
    }
}

struct SiriSegmentRow: View {
    let segment: SiriSegment
    let isLast: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            Image(systemName: segment.type == "transit" ? "tram.fill" : "figure.walk")
                .font(.caption)
                .foregroundStyle(segment.type == "transit" ? lineColor : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    // Line badge
                    if let lineName = segment.routeName {
                        Text(lineName)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(lineColor)
                            .cornerRadius(4)
                    }

                    Text(segment.fromStopName)
                        .font(.caption)
                        .lineLimit(1)
                }

                if !isLast {
                    Text("→ \(segment.toStopName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("\(segment.durationMinutes) min")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var lineColor: Color {
        if let hex = segment.routeColor {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }
}

struct PlanRouteErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Color Extension (local copy for Intent)

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
