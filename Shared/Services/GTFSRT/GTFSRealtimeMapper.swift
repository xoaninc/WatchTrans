//
//  GTFSRealtimeMapper.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//  Updated on 15/1/26 for RenfeServer API
//

import Foundation

class GTFSRealtimeMapper {
    private weak var dataService: DataService?

    init(dataService: DataService) {
        self.dataService = dataService
    }

    // MARK: - Map DepartureResponse to Arrival

    /// Map departures from RenfeServer API to Arrival models
    /// The API already provides most of the data we need
    func mapToArrivals(departures: [DepartureResponse], stopId: String) -> [Arrival] {
        guard let dataService = dataService else {
            DebugLog.log("⚠️ [Mapper] DataService is nil!")
            return []
        }

        // Get current stop name to filter out terminus trains
        let currentStopName = dataService.getStop(by: stopId)?.name

        let now = Date()
        var arrivals: [Arrival] = []

        DebugLog.log("🗺️ [Mapper] Processing \(departures.count) departures for stop \(stopId)")

        for departure in departures {
            // Skip if already passed - use realtime if available
            let effectiveMinutes = departure.realtimeMinutesUntil ?? departure.minutesUntil
            guard effectiveMinutes >= 0 else { continue }

            DebugLog.log("🚂 [Mapper] \(departure.routeShortName) - headsign from API: \"\(departure.headsign ?? "nil")\" (trip: \(departure.tripId))")

            // Skip terminus trains (where headsign = current stop)
            if let headsign = departure.headsign,
               let stopName = currentStopName,
               headsign.localizedCaseInsensitiveCompare(stopName) == .orderedSame {
                DebugLog.log("⏭️ [Mapper] Skipping terminus train: \(departure.routeShortName) -> \(headsign)")
                continue
            }

            // Find the line in our local data
            let line = findLine(
                routeShortName: departure.routeShortName,
                routeId: departure.routeId,
                stopId: stopId,
                dataService: dataService
            )

            // Calculate times using realtime minutes if available
            let expectedTime = now.addingTimeInterval(TimeInterval(effectiveMinutes * 60))
            let scheduledTime = now.addingTimeInterval(TimeInterval(departure.minutesUntil * 60))

            // Use headsign as destination
            let destination = departure.headsign ?? "Unknown"

            if departure.headsign == nil {
                DebugLog.log("⚠️ [Mapper] headsign was nil, using fallback: \"\(destination)\"")
            }

            let arrival = Arrival(
                id: departure.tripId,
                lineId: line?.id ?? departure.routeId,
                lineName: departure.routeShortName,
                destination: destination,
                scheduledTime: scheduledTime,
                expectedTime: expectedTime,
                platform: departure.platform,
                platformEstimated: departure.platformEstimated ?? false,
                trainCurrentStop: departure.trainPosition?.currentStopName,
                trainProgressPercent: departure.trainPosition?.progressPercent,
                trainLatitude: departure.trainPosition?.latitude,
                trainLongitude: departure.trainPosition?.longitude,
                trainStatus: departure.trainPosition?.status,
                trainEstimated: departure.trainPosition?.estimated,
                delaySeconds: departure.delaySeconds,
                routeColor: departure.routeColor,
                routeId: departure.routeId,
                frequencyBased: departure.frequencyBased ?? false,
                headwayMinutes: departure.headwayMinutes
            )

            arrivals.append(arrival)
        }

        // Sort by time and limit
        let sortedArrivals = arrivals
            .sorted { $0.expectedTime < $1.expectedTime }
            .prefix(APIConfiguration.defaultDeparturesLimit)

        DebugLog.log("✅ [Mapper] Mapped \(sortedArrivals.count) arrivals")
        return Array(sortedArrivals)
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
}
