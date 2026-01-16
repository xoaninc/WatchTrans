//
//  GTFSRealtimeMapper.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//  Updated on 15/1/26 for RenfeServer API - Much simpler now!
//

import Foundation

class GTFSRealtimeMapper {
    private weak var dataService: DataService?

    init(dataService: DataService) {
        self.dataService = dataService
    }

    // MARK: - Map DepartureResponse to Arrival

    /// Map departures from RenfeServer API to Arrival models
    /// The new API already provides most of the data we need!
    func mapToArrivals(departures: [DepartureResponse], stopId: String) -> [Arrival] {
        guard let dataService = dataService else {
            print("⚠️ [Mapper] DataService is nil!")
            return []
        }

        let now = Date()
        var arrivals: [Arrival] = []

        print("🗺️ [Mapper] Processing \(departures.count) departures for stop \(stopId)")

        for departure in departures {
            // Skip if already passed
            guard departure.minutesUntil >= 0 else { continue }

            // Find the line in our local data
            let line = findLine(
                routeShortName: departure.routeShortName,
                routeId: departure.routeId,
                stopId: stopId,
                dataService: dataService
            )

            // Calculate times
            let expectedTime = now.addingTimeInterval(TimeInterval(departure.minutesUntil * 60))
            let scheduledTime = expectedTime  // API doesn't separate these yet

            // Use headsign as destination, or try to determine from line
            let destination = departure.headsign ?? determineDestination(line: line, stopId: stopId)

            let arrival = Arrival(
                id: departure.tripId,
                lineId: line?.id ?? departure.routeId,
                lineName: departure.routeShortName,
                destination: destination,
                scheduledTime: scheduledTime,
                expectedTime: expectedTime,
                platform: nil
            )

            arrivals.append(arrival)
        }

        // Sort by time and limit
        let sortedArrivals = arrivals
            .sorted { $0.expectedTime < $1.expectedTime }
            .prefix(10)

        print("✅ [Mapper] Mapped \(sortedArrivals.count) arrivals")
        return Array(sortedArrivals)
    }

    // MARK: - Map ETAResponse to Arrival (with delay info)

    /// Map ETAs from RenfeServer API to Arrival models
    /// This includes accurate delay information
    func mapToArrivals(etas: [ETAResponse], stopId: String) -> [Arrival] {
        guard let dataService = dataService else {
            print("⚠️ [Mapper] DataService is nil!")
            return []
        }

        var arrivals: [Arrival] = []
        let now = Date()

        for eta in etas {
            // Skip if already passed
            guard eta.estimatedArrival > now else { continue }

            // We need to look up route info from the trip
            // For now, extract from tripId if possible
            let lineInfo = extractLineInfo(from: eta.tripId, dataService: dataService)

            let arrival = Arrival(
                id: eta.tripId,
                lineId: lineInfo?.id ?? eta.tripId,
                lineName: lineInfo?.name ?? "?",
                destination: "Unknown",  // ETA endpoint doesn't include headsign
                scheduledTime: eta.scheduledArrival,
                expectedTime: eta.estimatedArrival,
                platform: nil
            )

            arrivals.append(arrival)
        }

        return arrivals.sorted { $0.expectedTime < $1.expectedTime }
    }

    // MARK: - Helpers

    /// Find line in DataService by route name or ID
    private func findLine(routeShortName: String, routeId: String, stopId: String, dataService: DataService) -> Line? {
        let normalizedName = routeShortName.uppercased()

        // Match by name (case-insensitive)
        if let match = dataService.lines.first(where: { $0.name.uppercased() == normalizedName }) {
            return match
        }

        // Match by ID suffix (e.g., "C1" matches "madrid-c1")
        if let match = dataService.lines.first(where: { $0.id.uppercased().hasSuffix(normalizedName) }) {
            return match
        }

        return nil
    }

    /// Determine destination - now just returns "Unknown" since we rely on API headsign
    private func determineDestination(line: Line?, stopId: String) -> String {
        // The RenfeServer API provides headsign in DepartureResponse
        // This is only a fallback if headsign is nil
        return "Unknown"
    }

    /// Extract line info from trip ID (e.g., "3010X23522C1" → "C1")
    private func extractLineInfo(from tripId: String, dataService: DataService) -> Line? {
        let pattern = "[CT][0-9]+[a-z]?$"
        guard let range = tripId.range(of: pattern, options: .regularExpression) else {
            return nil
        }

        let lineCode = String(tripId[range]).uppercased()
        return dataService.lines.first { $0.name.uppercased() == lineCode }
    }
}

// MARK: - Convenience Extensions

extension DepartureResponse {
    /// Convert to Arrival directly (when line info is known)
    func toArrival(lineId: String, lineName: String) -> Arrival {
        let now = Date()
        let expectedTime = now.addingTimeInterval(TimeInterval(minutesUntil * 60))

        return Arrival(
            id: tripId,
            lineId: lineId,
            lineName: lineName,
            destination: headsign ?? "Unknown",
            scheduledTime: expectedTime,
            expectedTime: expectedTime,
            platform: nil
        )
    }
}

extension ETAResponse {
    /// Convert to Arrival directly (when line info is known)
    func toArrival(lineId: String, lineName: String, destination: String) -> Arrival {
        return Arrival(
            id: tripId,
            lineId: lineId,
            lineName: lineName,
            destination: destination,
            scheduledTime: scheduledArrival,
            expectedTime: estimatedArrival,
            platform: nil
        )
    }
}
