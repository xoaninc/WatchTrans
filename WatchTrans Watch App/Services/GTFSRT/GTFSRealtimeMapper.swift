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

            // Skip departures where the train doesn't stop at this station
            if departure.isSkipped == true { continue }

            // Extract and clean headsign (strip /T.DOBLE suffix from Metro Sevilla double compositions)
            let rawHeadsign = departure.headsign ?? ""
            let isDoubleComposition = departure.vehicleLabel?.contains(",") == true
                || rawHeadsign.uppercased().contains("/T.DOBLE")
            let cleanHeadsign = rawHeadsign
                .replacingOccurrences(of: "/T.DOBLE", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "/T. DOBLE", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)

            DebugLog.log("🚂 [Mapper] \(departure.routeShortName) - headsign: \"\(rawHeadsign)\" -> \"\(cleanHeadsign)\" (double: \(isDoubleComposition), trip: \(departure.tripId))")

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

            if cleanHeadsign.isEmpty && rawHeadsign.isEmpty {
                DebugLog.log("⚠️ [Mapper] headsign was nil, using fallback: \"\(destination)\"")
            }

            let arrival = Arrival(
                id: departure.tripId,
                lineId: line?.id ?? departure.routeId,
                lineName: line?.name ?? departure.routeShortName,
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
                wheelchairAccessible: Self.wheelchairValue(rt: departure.wheelchairAccessible, static: departure.wheelchairAccessibleStatic) == 2,
                wheelchairInaccessible: Self.wheelchairValue(rt: departure.wheelchairAccessible, static: departure.wheelchairAccessibleStatic) == 3,
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
                transportType: line?.type ?? .tren
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

    // MARK: - Wheelchair

    /// Resolve wheelchair accessibility: RT (protobuf scale) takes priority, fallback to static (GTFS scale).
    /// RT: 2=accessible, 3=not accessible. Static: 1=accessible, 2=not accessible.
    /// Returns normalized to RT scale: 2=accessible, 3=not accessible, nil=no data.
    static func wheelchairValue(rt: Int?, static staticVal: Int?) -> Int? {
        // RT (protobuf): 2=accessible, 3=not accessible
        if let rt, rt == 2 || rt == 3 { return rt }
        // Static (GTFS): 1=accessible, 2=not accessible — normalize to RT scale
        if let staticVal {
            if staticVal == 1 { return 2 }  // accessible → RT 2
            if staticVal == 2 { return 3 }  // not accessible → RT 3
        }
        return nil
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
