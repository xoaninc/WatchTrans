//
//  GTFSRealtimeMapper.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//  Updated on 15/1/26 for WatchTrans API
//

import Foundation

class GTFSRealtimeMapper {
    private weak var dataService: DataService?

    init(dataService: DataService) {
        self.dataService = dataService
    }

    // MARK: - Map DepartureResponse to Arrival

    /// Map departures from WatchTrans API to Arrival models
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

            // Detect double composition from trip_id (e.g., "MSEV_RT_111,116_d0" has comma)
            let isDoubleComposition = departure.tripId.contains(",")
            let cleanHeadsign = (departure.headsign ?? "").trimmingCharacters(in: .whitespaces)

            // Per-departure logging removed for production (was flooding logs with 40+ lines per stop)

            // Skip terminus trains (where cleaned headsign = current stop)
            if !cleanHeadsign.isEmpty,
               let stopName = currentStopName,
               cleanHeadsign.localizedCaseInsensitiveCompare(stopName) == .orderedSame {
                DebugLog.log("⏭️ [Mapper] Skipping terminus train: \(departure.routeShortName) -> \(cleanHeadsign)")
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

            let destination = cleanHeadsign.isEmpty ? "Unknown" : cleanHeadsign

            if cleanHeadsign.isEmpty {
                DebugLog.log("⚠️ [Mapper] headsign was nil, using fallback: \"\(destination)\"")
            }

            let arrival = Arrival(
                id: departure.tripId,
                lineId: line?.id ?? departure.routeId,
                lineName: line?.name ?? departure.routeShortName,  // Use formatted name from Line if available
                destination: destination,
                scheduledTime: scheduledTime,
                expectedTime: expectedTime,
                platform: departure.platform,
                platformEstimated: departure.platformEstimated ?? true,
                trainCurrentStop: departure.trainPosition?.currentStopName,
                trainProgressPercent: departure.trainPosition?.progressPercent,
                trainLatitude: departure.trainPosition?.latitude,
                trainLongitude: departure.trainPosition?.longitude,
                trainStatus: departure.trainPosition?.status,
                trainEstimated: departure.trainPosition?.estimated,
                trainCurrentStopId: departure.trainPosition?.currentStopId,
                trainPositionTimestamp: departure.trainPosition?.timestamp,
                delaySeconds: departure.delaySeconds,
                routeColor: departure.routeColor,
                routeId: departure.routeId,
                isSuspended: departure.isSuspended ?? false,
                wheelchairAccessible: departure.wheelchairAccessible == "WHEELCHAIR_ACCESSIBLE",
                frequencyBased: departure.frequencyBased ?? false,
                headwayMinutes: departure.headwayMinutes,
                isOfflineData: false,
                occupancyStatus: departure.occupancyStatus,
                occupancyPercentage: departure.occupancyPercentage,
                routeTextColor: departure.routeTextColor,
                isSkipped: departure.isSkipped,
                vehicleLat: departure.vehicleLat,
                vehicleLon: departure.vehicleLon,
                vehicleLabel: departure.vehicleLabel,
                isDoubleComposition: isDoubleComposition,
                isExpress: departure.isExpress ?? false,
                expressName: departure.expressName,
                expressColor: departure.expressColor,
                pmrWarning: departure.pmrWarning ?? false
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
