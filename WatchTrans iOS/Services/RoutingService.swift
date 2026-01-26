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
        let lines = dataService.getCachedLines()
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

        // Convert path to journey segments
        let segments = buildSegments(from: path)

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

    /// Build journey segments from path
    private func buildSegments(from path: [TransitNode]) -> [JourneySegment] {
        var segments: [JourneySegment] = []
        var currentLineId: String?
        var segmentStops: [Stop] = []
        var segmentStart: Stop?

        for i in 0..<path.count {
            let node = path[i]
            guard let stop = stopCache[node.stopId] else { continue }

            if node.lineId != currentLineId {
                // Line changed - finish previous segment
                if let start = segmentStart, !segmentStops.isEmpty, let lineId = currentLineId {
                    let line = lineCache[lineId]
                    let lastStop = segmentStops.last ?? start

                    // Determine transport mode from line type
                    let mode = transportMode(for: line)

                    let segment = JourneySegment(
                        type: .transit,
                        transportMode: mode,
                        lineName: line?.name,
                        lineColor: line?.colorHex,
                        origin: start,
                        destination: lastStop,
                        intermediateStops: Array(segmentStops.dropLast()),
                        durationMinutes: estimateDuration(from: start, to: lastStop, stops: segmentStops.count),
                        coordinates: segmentStops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                    )
                    segments.append(segment)
                }

                // Check if this is a transfer (walking)
                if i > 0 && node.lineId != nil && currentLineId != nil {
                    let prevStop = stopCache[path[i-1].stopId]
                    if let prev = prevStop, prev.id != stop.id {
                        // Walking transfer between different stops
                        let walkSegment = JourneySegment(
                            type: .walking,
                            transportMode: .walking,
                            lineName: nil,
                            lineColor: nil,
                            origin: prev,
                            destination: stop,
                            intermediateStops: [],
                            durationMinutes: estimateWalkingTime(from: prev, to: stop),
                            coordinates: [
                                CLLocationCoordinate2D(latitude: prev.latitude, longitude: prev.longitude),
                                CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
                            ]
                        )
                        segments.append(walkSegment)
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

            let segment = JourneySegment(
                type: .transit,
                transportMode: mode,
                lineName: line?.name,
                lineColor: line?.colorHex,
                origin: start,
                destination: lastStop,
                intermediateStops: Array(segmentStops.dropFirst().dropLast()),
                durationMinutes: estimateDuration(from: start, to: lastStop, stops: segmentStops.count),
                coordinates: segmentStops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            )
            segments.append(segment)
        }

        return segments
    }

    private func transportMode(for line: Line?) -> TransportMode {
        guard let line = line else { return .metro }
        switch line.type {
        case .metro: return .metro
        case .cercanias: return .cercanias
        case .tram: return .tranvia
        case .bus: return .bus
        case .other: return .metro
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
