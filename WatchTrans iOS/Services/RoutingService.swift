//
//  RoutingService.swift
//  WatchTrans iOS
//
//  Created by Claude on 26/1/26.
//  Service for calculating routes between stops using Dijkstra's algorithm
//

import Foundation
import CoreLocation

@Observable
class RoutingService {
    private let dataService: DataService

    // Graph representation
    private var nodes: Set<TransitNode> = []
    private var edges: [TransitNode: [TransitEdge]] = [:]
    private var stopCache: [String: Stop] = [:]
    private var lineCache: [String: Line] = [:]

    // Shape cache for route polylines
    private var shapeCache: [String: [CLLocationCoordinate2D]] = [:]

    // Configuration
    private let transferPenaltyMinutes: Double = 3.0  // Penalty for transfers
    private let walkingSpeedKmH: Double = 4.5         // Average walking speed
    private let averageTrainSpeedKmH: Double = 30.0   // Average metro/train speed

    var isGraphBuilt = false

    init(dataService: DataService) {
        self.dataService = dataService
    }

    // MARK: - Build Transit Graph

    /// Build the transit graph from all available lines and stops
    func buildGraph() async {
        DebugLog.log("🗺️ [Routing] Building transit graph...")

        nodes.removeAll()
        edges.removeAll()
        stopCache.removeAll()

        // Get all lines
        let lines = dataService.lines
        DebugLog.log("🗺️ [Routing] Found \(lines.count) lines")

        for line in lines {
            lineCache[line.id] = line

            // Get stops for this line
            guard let routeId = line.routeIds.first else { continue }
            let stops = await dataService.fetchStopsForRoute(routeId: routeId)

            guard stops.count > 1 else { continue }

            // Cache stops
            for stop in stops {
                stopCache[stop.id] = stop
            }

            // Add edges between consecutive stops on this line
            for i in 0..<(stops.count - 1) {
                let fromStop = stops[i]
                let toStop = stops[i + 1]

                let fromNode = TransitNode(stopId: fromStop.id, lineId: line.id)
                let toNode = TransitNode(stopId: toStop.id, lineId: line.id)

                nodes.insert(fromNode)
                nodes.insert(toNode)

                // Calculate travel time based on distance
                let distance = fromStop.location.distance(from: toStop.location)
                let travelTimeMinutes = (distance / 1000.0) / averageTrainSpeedKmH * 60.0

                let edge = TransitEdge(
                    from: fromNode,
                    to: toNode,
                    weight: max(1.0, travelTimeMinutes),  // Minimum 1 minute
                    type: .ride,
                    lineId: line.id,
                    lineName: line.name,
                    lineColor: line.colorHex
                )

                addEdge(edge)

                // Add reverse edge (bidirectional)
                let reverseEdge = TransitEdge(
                    from: toNode,
                    to: fromNode,
                    weight: max(1.0, travelTimeMinutes),
                    type: .ride,
                    lineId: line.id,
                    lineName: line.name,
                    lineColor: line.colorHex
                )
                addEdge(reverseEdge)
            }
        }

        // Add transfer edges between different lines at the same station
        await addTransferEdges()

        isGraphBuilt = true
        DebugLog.log("🗺️ [Routing] Graph built: \(nodes.count) nodes, \(edges.values.flatMap { $0 }.count) edges")
    }

    /// Add transfer edges using correspondences data
    private func addTransferEdges() async {
        // Group nodes by stop ID to find transfer points
        let nodesByStop = Dictionary(grouping: nodes) { $0.stopId }

        for (stopId, stopNodes) in nodesByStop {
            // Add transfers between different lines at the same stop
            if stopNodes.count > 1 {
                for fromNode in stopNodes {
                    for toNode in stopNodes where fromNode.lineId != toNode.lineId {
                        let transferEdge = TransitEdge(
                            from: fromNode,
                            to: toNode,
                            weight: transferPenaltyMinutes,
                            type: .transfer,
                            lineId: nil,
                            lineName: nil,
                            lineColor: nil
                        )
                        addEdge(transferEdge)
                    }
                }
            }

            // Add transfers from correspondences (walking to nearby stations)
            let correspondences = await dataService.fetchCorrespondences(stopId: stopId)
            for correspondence in correspondences {
                let walkTimeMinutes = Double(correspondence.walkTimeS) / 60.0

                // Find nodes at the destination stop
                let destNodes = nodesByStop[correspondence.toStopId] ?? []
                for fromNode in stopNodes {
                    for toNode in destNodes {
                        let walkEdge = TransitEdge(
                            from: fromNode,
                            to: toNode,
                            weight: walkTimeMinutes + transferPenaltyMinutes,
                            type: .transfer,
                            lineId: nil,
                            lineName: nil,
                            lineColor: nil
                        )
                        addEdge(walkEdge)
                    }
                }
            }
        }
    }

    private func addEdge(_ edge: TransitEdge) {
        if edges[edge.from] == nil {
            edges[edge.from] = []
        }
        edges[edge.from]?.append(edge)
    }

    // MARK: - Find Route (Dijkstra)

    /// Find the best route between two stops
    func findRoute(from originId: String, to destinationId: String) async -> Journey? {
        if !isGraphBuilt {
            await buildGraph()
        }

        guard let originStop = stopCache[originId],
              let destStop = stopCache[destinationId] else {
            DebugLog.log("⚠️ [Routing] Origin or destination not found in cache")
            return nil
        }

        DebugLog.log("🗺️ [Routing] Finding route: \(originStop.name) → \(destStop.name)")

        // Find all nodes at origin and destination
        let originNodes = nodes.filter { $0.stopId == originId }
        let destNodes = nodes.filter { $0.stopId == destinationId }

        guard !originNodes.isEmpty, !destNodes.isEmpty else {
            DebugLog.log("⚠️ [Routing] No nodes found for origin or destination")
            return nil
        }

        // Run Dijkstra from all origin nodes
        var bestPath: [TransitNode]?
        var bestDistance = Double.infinity

        for originNode in originNodes {
            if let (path, distance) = dijkstra(from: originNode, to: destNodes) {
                if distance < bestDistance {
                    bestDistance = distance
                    bestPath = path
                }
            }
        }

        guard let path = bestPath else {
            DebugLog.log("⚠️ [Routing] No route found")
            return nil
        }

        // Convert path to journey segments (with real shape data)
        let segments = await buildSegments(from: path)

        let journey = Journey(
            origin: originStop,
            destination: destStop,
            segments: segments,
            totalDurationMinutes: Int(bestDistance),
            totalWalkingMinutes: Journey.calculateWalkingTime(segments: segments),
            transferCount: segments.filter { $0.type == .walking }.count
        )

        DebugLog.log("🗺️ [Routing] Route found: \(segments.count) segments, \(Int(bestDistance)) min")
        return journey
    }

    /// Dijkstra's algorithm
    private func dijkstra(from start: TransitNode, to goals: Set<TransitNode>) -> ([TransitNode], Double)? {
        var distances: [TransitNode: Double] = [start: 0]
        var previous: [TransitNode: TransitNode] = [:]
        var unvisited = nodes

        while !unvisited.isEmpty {
            // Find unvisited node with smallest distance
            guard let current = unvisited.min(by: { (distances[$0] ?? .infinity) < (distances[$1] ?? .infinity) }),
                  let currentDist = distances[current],
                  currentDist < .infinity else {
                break
            }

            // Check if we reached a goal
            if goals.contains(current) {
                var path: [TransitNode] = []
                var node: TransitNode? = current
                while let n = node {
                    path.insert(n, at: 0)
                    node = previous[n]
                }
                return (path, currentDist)
            }

            unvisited.remove(current)

            // Update distances to neighbors
            for edge in edges[current] ?? [] {
                let alt = currentDist + edge.weight
                if alt < (distances[edge.to] ?? .infinity) {
                    distances[edge.to] = alt
                    previous[edge.to] = current
                }
            }
        }

        return nil
    }

    /// Build journey segments from path with real shape data
    private func buildSegments(from path: [TransitNode]) async -> [JourneySegment] {
        var segments: [JourneySegment] = []
        var currentLineId: String?
        var segmentStops: [Stop] = []
        var segmentStart: Stop?

        DebugLog.log("🛤️ [Routing] Building segments from path with \(path.count) nodes")

        for i in 0..<path.count {
            let node = path[i]
            guard let stop = stopCache[node.stopId] else {
                DebugLog.log("⚠️ [Routing] Stop not found in cache: \(node.stopId)")
                continue
            }

            if node.lineId != currentLineId {
                // Line changed - finish previous segment
                if let start = segmentStart, !segmentStops.isEmpty, let lineId = currentLineId {
                    let line = lineCache[lineId]
                    let lastStop = segmentStops.last ?? start

                    // Determine transport mode from line type
                    let mode = transportMode(for: line)

                    // Get real shape coordinates for this segment
                    let coordinates = await getShapeCoordinates(
                        for: line,
                        from: start,
                        to: lastStop,
                        fallbackStops: segmentStops
                    )

                    let segment = JourneySegment(
                        type: .transit,
                        transportMode: mode,
                        lineName: line?.name,
                        lineColor: line?.colorHex,
                        origin: start,
                        destination: lastStop,
                        intermediateStops: Array(segmentStops.dropLast()),
                        durationMinutes: estimateDuration(from: start, to: lastStop, stops: segmentStops.count),
                        coordinates: coordinates
                    )
                    segments.append(segment)
                    DebugLog.log("🚇 [Routing] Added TRANSIT segment: \(line?.name ?? "?") from \(start.name) to \(lastStop.name) with \(coordinates.count) coords")
                }

                // Check if this is a transfer (walking)
                if i > 0 && node.lineId != nil && currentLineId != nil {
                    let prevStop = stopCache[path[i-1].stopId]
                    if let prev = prevStop, prev.id != stop.id {
                        // Walking transfer between different stops - interpolate path
                        let walkCoordinates = interpolateWalkingPath(from: prev, to: stop)
                        let walkSegment = JourneySegment(
                            type: .walking,
                            transportMode: .walking,
                            lineName: nil,
                            lineColor: nil,
                            origin: prev,
                            destination: stop,
                            intermediateStops: [],
                            durationMinutes: estimateWalkingTime(from: prev, to: stop),
                            coordinates: walkCoordinates
                        )
                        segments.append(walkSegment)
                        DebugLog.log("🚶 [Routing] Added WALKING segment: \(prev.name) to \(stop.name)")
                    }
                }

                // Start new segment
                currentLineId = node.lineId
                segmentStart = stop
                segmentStops = [stop]
            } else {
                segmentStops.append(stop)
            }
        }

        // Finish last segment
        if let start = segmentStart, segmentStops.count > 1, let lineId = currentLineId {
            let line = lineCache[lineId]
            let lastStop = segmentStops.last ?? start
            let mode = transportMode(for: line)

            // Get real shape coordinates for last segment
            let coordinates = await getShapeCoordinates(
                for: line,
                from: start,
                to: lastStop,
                fallbackStops: segmentStops
            )

            let segment = JourneySegment(
                type: .transit,
                transportMode: mode,
                lineName: line?.name,
                lineColor: line?.colorHex,
                origin: start,
                destination: lastStop,
                intermediateStops: Array(segmentStops.dropFirst().dropLast()),
                durationMinutes: estimateDuration(from: start, to: lastStop, stops: segmentStops.count),
                coordinates: coordinates
            )
            segments.append(segment)
            DebugLog.log("🚇 [Routing] Added FINAL TRANSIT segment: \(line?.name ?? "?") from \(start.name) to \(lastStop.name) with \(coordinates.count) coords")
        }

        DebugLog.log("🛤️ [Routing] Total segments created: \(segments.count)")
        for (idx, seg) in segments.enumerated() {
            DebugLog.log("   [\(idx)] \(seg.type == .transit ? "🚇" : "🚶") \(seg.lineName ?? "Walking") - \(seg.coordinates.count) coords")
        }

        return segments
    }

    // MARK: - Shape Helpers

    /// Get shape coordinates for a segment, loading from API if needed
    private func getShapeCoordinates(
        for line: Line?,
        from origin: Stop,
        to destination: Stop,
        fallbackStops: [Stop]
    ) async -> [CLLocationCoordinate2D] {
        guard let line = line, let routeId = line.routeIds.first else {
            // Fallback to stop coordinates
            return fallbackStops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }

        // Load shape if not cached
        if shapeCache[routeId] == nil {
            let shapePoints = await dataService.fetchRouteShape(routeId: routeId)
            if !shapePoints.isEmpty {
                shapeCache[routeId] = shapePoints.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
            }
        }

        guard let fullShape = shapeCache[routeId], !fullShape.isEmpty else {
            // Fallback to stop coordinates
            return fallbackStops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }

        // Extract the portion of the shape between origin and destination
        let originCoord = CLLocationCoordinate2D(latitude: origin.latitude, longitude: origin.longitude)
        let destCoord = CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)

        return extractShapeSegment(from: fullShape, origin: originCoord, destination: destCoord)
    }

    /// Extract a portion of the shape between two coordinates
    /// The shape points are already sorted by sequence from the API
    private func extractShapeSegment(
        from shape: [CLLocationCoordinate2D],
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D
    ) -> [CLLocationCoordinate2D] {
        guard shape.count > 1 else { return [origin, destination] }

        // Find closest point to origin
        var originIndex = 0
        var minOriginDist = Double.infinity
        for (index, coord) in shape.enumerated() {
            let d = distance(from: coord, to: origin)
            if d < minOriginDist {
                minOriginDist = d
                originIndex = index
            }
        }

        // Find closest point to destination
        var destIndex = shape.count - 1
        var minDestDist = Double.infinity
        for (index, coord) in shape.enumerated() {
            let d = distance(from: coord, to: destination)
            if d < minDestDist {
                minDestDist = d
                destIndex = index
            }
        }

        // Extract segment - points are already in correct order by sequence
        var segment: [CLLocationCoordinate2D]
        if originIndex <= destIndex {
            segment = Array(shape[originIndex...destIndex])
        } else {
            // Origin comes after destination in shape, so we're going "backwards"
            // Extract and reverse to get origin -> destination order
            segment = Array(shape[destIndex...originIndex].reversed())
        }

        // If segment is too short, interpolate more points for smoother animation
        if segment.count < 10 {
            segment = interpolatePoints(segment, targetCount: max(20, segment.count * 3))
        }

        return segment
    }

    /// Interpolate walking path between two stops
    private func interpolateWalkingPath(from origin: Stop, to destination: Stop) -> [CLLocationCoordinate2D] {
        let start = CLLocationCoordinate2D(latitude: origin.latitude, longitude: origin.longitude)
        let end = CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)

        // Create interpolated points for smooth walking animation
        return interpolatePoints([start, end], targetCount: 15)
    }

    /// Interpolate points to create smoother path
    private func interpolatePoints(_ points: [CLLocationCoordinate2D], targetCount: Int) -> [CLLocationCoordinate2D] {
        guard points.count >= 2, targetCount > points.count else { return points }

        var result: [CLLocationCoordinate2D] = []
        let segmentCount = points.count - 1
        let pointsPerSegment = max(1, (targetCount - 1) / segmentCount)

        for i in 0..<segmentCount {
            let start = points[i]
            let end = points[i + 1]

            for j in 0..<pointsPerSegment {
                let t = Double(j) / Double(pointsPerSegment)
                let lat = start.latitude + (end.latitude - start.latitude) * t
                let lon = start.longitude + (end.longitude - start.longitude) * t
                result.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
        }

        // Add final point
        if let last = points.last {
            result.append(last)
        }

        return result
    }

    /// Calculate distance between two coordinates in meters
    private func distance(from coord1: CLLocationCoordinate2D, to coord2: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let loc2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return loc1.distance(from: loc2)
    }

    private func transportMode(for line: Line?) -> TransportMode {
        guard let line = line else { return .metro }
        switch line.type {
        case .metro: return .metro
        case .cercanias: return .cercanias
        case .tram: return .tranvia
        case .metroLigero: return .metroLigero
        case .fgc: return .cercanias  // FGC behaves like cercanías
        }
    }

    private func estimateDuration(from: Stop, to: Stop, stops: Int) -> Int {
        // Average 2 minutes per stop
        return max(1, stops * 2)
    }

    private func estimateWalkingTime(from: Stop, to: Stop) -> Int {
        let distance = from.location.distance(from: to.location)
        let timeHours = (distance / 1000.0) / walkingSpeedKmH
        return max(1, Int(timeHours * 60))
    }
}
