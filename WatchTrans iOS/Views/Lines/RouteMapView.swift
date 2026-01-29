//
//  RouteMapView.swift
//  WatchTrans iOS
//
//  Created by Claude on 26/1/26.
//  Map view showing the route of a transit line with all its stops
//

import SwiftUI
import MapKit

struct RouteMapView: View {
    let line: Line
    let stops: [Stop]
    let dataService: DataService
    let shapePoints: [CLLocationCoordinate2D]?
    let stopOnShapeCoords: [String: CLLocationCoordinate2D]?  // Projected coordinates for markers
    let isSuspended: Bool
    let isShapeLoading: Bool

    @State private var mapPosition: MapCameraPosition
    @State private var selectedStop: Stop?
    @State private var isFullScreen = false

    var lineColor: Color {
        Color(hex: line.colorHex) ?? .blue
    }

    /// Deduplicated stops (removes duplicates by name, keeps first occurrence)
    private var uniqueStops: [Stop] {
        var seen = Set<String>()
        return stops.filter { stop in
            let normalized = stop.name.lowercased().trimmingCharacters(in: .whitespaces)
            if seen.contains(normalized) {
                return false
            }
            seen.insert(normalized)
            return true
        }
    }

    init(line: Line, stops: [Stop], dataService: DataService, shapePoints: [CLLocationCoordinate2D]? = nil, stopOnShapeCoords: [String: CLLocationCoordinate2D]? = nil, isSuspended: Bool = false, isShapeLoading: Bool = false) {
        self.line = line
        self.stops = stops
        self.dataService = dataService
        self.shapePoints = shapePoints
        self.stopOnShapeCoords = stopOnShapeCoords
        self.isSuspended = isSuspended
        self.isShapeLoading = isShapeLoading

        // Calculate region from shape points if available, otherwise from stops
        let coordinates: [CLLocationCoordinate2D]
        if let shapePoints = shapePoints, !shapePoints.isEmpty {
            coordinates = shapePoints
        } else {
            coordinates = stops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }
        let region = Self.regionToFit(coordinates: coordinates)
        _mapPosition = State(initialValue: .region(region))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Map header
            mapHeader

            // Map content - show loading placeholder until shape loads
            ZStack {
                if isShapeLoading {
                    // Loading placeholder with line color gradient
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [lineColor.opacity(0.1), lineColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(lineColor)
                                Text("Cargando recorrido...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        )
                } else {
                    // Map content - use id to force refresh when shape data changes
                    mapContent
                        .id(shapePoints?.count ?? 0)
                }
            }
            .frame(height: 280)

            // Selected stop info
            if let stop = selectedStop {
                SelectedStopInfoView(stop: stop, lineColor: lineColor)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.2), value: selectedStop?.id)
        .fullScreenCover(isPresented: $isFullScreen) {
            FullScreenMapView(
                line: line,
                stops: stops,
                shapePoints: shapePoints,
                stopOnShapeCoords: stopOnShapeCoords,
                lineColor: lineColor,
                initialPosition: mapPosition,
                isSuspended: isSuspended
            )
        }
        .onChange(of: shapePoints?.count) { oldCount, newCount in
            // Update map region when shape points are loaded
            if let count = newCount, count > 2, let shape = shapePoints {
                DebugLog.log("🗺️ [RouteMapView] Shape loaded (\(count) points), updating region")
                let region = Self.regionToFit(coordinates: shape)
                mapPosition = .region(region)
            }
        }
    }

    private var mapHeader: some View {
        HStack {
            Image(systemName: "map")
                .foregroundStyle(lineColor)
            Text("Recorrido")
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
            Button {
                isFullScreen = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private var mapContent: some View {
        let _ = DebugLog.log("🗺️ [RouteMapView] Rendering \(line.name): shapePoints=\(shapePoints?.count ?? 0), stops=\(stops.count)")

        return Map(position: $mapPosition) {
            // Route polyline - use shape points if available, otherwise connect stops
            if let shape = shapePoints, shape.count > 2 {
                if isSuspended {
                    MapPolyline(coordinates: shape)
                        .stroke(lineColor.opacity(0.5), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [8, 4]))
                } else {
                    MapPolyline(coordinates: shape)
                        .stroke(lineColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
            } else {
                // Fallback: connect stops with straight lines
                let coords = stops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                if isSuspended {
                    MapPolyline(coordinates: coords)
                        .stroke(lineColor.opacity(0.5), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [8, 4]))
                } else {
                    MapPolyline(coordinates: coords)
                        .stroke(lineColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
            }

            // Stop markers - interchange stations get white circle with black border
            // Use on_shape coordinates when available for precise placement on the line
            // Use uniqueStops to avoid duplicate markers at the same station
            ForEach(uniqueStops) { stop in
                // For circular lines, no terminal markers
                let isTerminal = !line.isCircular && (stop.id == uniqueStops.first?.id || stop.id == uniqueStops.last?.id)
                let hasCorrespondence = stop.hasCorrespondence(excludingLine: line.name)
                // Use projected coordinates if available, otherwise fall back to stop coordinates
                let coord = stopOnShapeCoords?[stop.id] ?? CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
                Annotation("", coordinate: coord) {
                    if hasCorrespondence {
                        // Interchange: white circle with black border (like Metro Madrid map)
                        Circle()
                            .fill(.white)
                            .frame(width: isTerminal ? 12 : 8, height: isTerminal ? 12 : 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: isTerminal ? 2 : 1.5)
                            )
                    } else if isTerminal {
                        // Terminal stop: colored circle with white center
                        Circle()
                            .fill(isSuspended ? lineColor.opacity(0.5) : lineColor)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .fill(.white)
                                    .frame(width: 5, height: 5)
                            )
                    } else {
                        // Regular stop: colored circle with white center
                        Circle()
                            .fill(isSuspended ? lineColor.opacity(0.5) : lineColor)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .fill(.white)
                                    .frame(width: 4, height: 4)
                            )
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }

    static func regionToFit(coordinates: [CLLocationCoordinate2D], padding: Double = 1.3) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * padding + 0.005,
            longitudeDelta: (maxLon - minLon) * padding + 0.005
        )

        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Selected Stop Info View

struct SelectedStopInfoView: View {
    let stop: Stop
    let lineColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(lineColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if stop.isHub {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption2)
                        Text("Intercambiador")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - Full Screen Map View

struct FullScreenMapView: View {
    let line: Line
    let stops: [Stop]
    let shapePoints: [CLLocationCoordinate2D]?
    let stopOnShapeCoords: [String: CLLocationCoordinate2D]?  // Projected coordinates for markers
    let lineColor: Color
    let initialPosition: MapCameraPosition
    let isSuspended: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var mapPosition: MapCameraPosition
    @State private var mapStyle: MapStyleOption = .standard

    enum MapStyleOption: String, CaseIterable {
        case standard = "Estandar"
        case satellite = "Satelite"
        case hybrid = "Hibrido"
    }

    /// Deduplicated stops (removes duplicates by name, keeps first occurrence)
    private var uniqueStops: [Stop] {
        var seen = Set<String>()
        return stops.filter { stop in
            let normalized = stop.name.lowercased().trimmingCharacters(in: .whitespaces)
            if seen.contains(normalized) {
                return false
            }
            seen.insert(normalized)
            return true
        }
    }

    init(line: Line, stops: [Stop], shapePoints: [CLLocationCoordinate2D]?, stopOnShapeCoords: [String: CLLocationCoordinate2D]? = nil, lineColor: Color, initialPosition: MapCameraPosition, isSuspended: Bool = false) {
        self.line = line
        self.stops = stops
        self.shapePoints = shapePoints
        self.stopOnShapeCoords = stopOnShapeCoords
        self.lineColor = lineColor
        self.initialPosition = initialPosition
        self.isSuspended = isSuspended
        _mapPosition = State(initialValue: initialPosition)
    }

    var body: some View {
        NavigationStack {
            mapContent
                .mapStyle(currentMapStyle)
                .mapControls {
                    MapCompass()
                    MapScaleView()
                    MapUserLocationButton()
                }
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(line.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cerrar") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            ForEach(MapStyleOption.allCases, id: \.self) { style in
                                Button {
                                    mapStyle = style
                                } label: {
                                    HStack {
                                        Text(style.rawValue)
                                        if mapStyle == style {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "map")
                        }
                    }
                }
        }
    }

    private var mapContent: some View {
        Map(position: $mapPosition) {
            // Route polyline - use shape points if available, otherwise connect stops
            if let shape = shapePoints, shape.count > 2 {
                if isSuspended {
                    MapPolyline(coordinates: shape)
                        .stroke(lineColor.opacity(0.5), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [10, 5]))
                } else {
                    MapPolyline(coordinates: shape)
                        .stroke(lineColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
            } else {
                // Fallback: connect stops with straight lines
                let coords = stops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                if isSuspended {
                    MapPolyline(coordinates: coords)
                        .stroke(lineColor.opacity(0.5), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [10, 5]))
                } else {
                    MapPolyline(coordinates: coords)
                        .stroke(lineColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
            }

            // Stop markers - interchange stations get white circle with black border
            // Use on_shape coordinates when available for precise placement on the line
            // Use uniqueStops to avoid duplicate markers at the same station
            ForEach(uniqueStops) { stop in
                // For circular lines, no terminal markers
                let isTerminal = !line.isCircular && (stop.id == uniqueStops.first?.id || stop.id == uniqueStops.last?.id)
                let hasCorrespondence = stop.hasCorrespondence(excludingLine: line.name)
                // Use projected coordinates if available, otherwise fall back to stop coordinates
                let coord = stopOnShapeCoords?[stop.id] ?? CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
                Annotation("", coordinate: coord) {
                    if hasCorrespondence {
                        // Interchange: white circle with black border (like Metro Madrid map)
                        Circle()
                            .fill(.white)
                            .frame(width: isTerminal ? 14 : 10, height: isTerminal ? 14 : 10)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: isTerminal ? 2.5 : 2)
                            )
                    } else if isTerminal {
                        // Terminal stop: colored circle with white center
                        Circle()
                            .fill(isSuspended ? lineColor.opacity(0.5) : lineColor)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .fill(.white)
                                    .frame(width: 6, height: 6)
                            )
                    } else {
                        // Regular stop: colored circle with white center
                        Circle()
                            .fill(isSuspended ? lineColor.opacity(0.5) : lineColor)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .fill(.white)
                                    .frame(width: 5, height: 5)
                            )
                    }
                }
            }
        }
    }

    private var currentMapStyle: MapStyle {
        switch mapStyle {
        case .standard:
            return .standard(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: false)
        case .satellite:
            return .imagery(elevation: .realistic)
        case .hybrid:
            return .hybrid(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: false)
        }
    }
}

#Preview {
    RouteMapView(
        line: Line(
            id: "l1",
            name: "L1",
            longName: "Pinar de Chamartin - Valdecarros",
            type: .metro,
            colorHex: "#38A3DC",
            nucleo: "madrid",
            routeIds: ["METRO_1"],
            isCircular: false
        ),
        stops: [
            Stop(id: "1", name: "Pinar de Chamartin", latitude: 40.4801, longitude: -3.6668, connectionLineIds: [], province: "Madrid", accesibilidad: nil, hasParking: false, hasBusConnection: false, hasMetroConnection: true, corMetro: "L1, L4", corMl: nil, corCercanias: nil, corTranvia: nil),
            Stop(id: "2", name: "Bambu", latitude: 40.4768, longitude: -3.6764, connectionLineIds: [], province: "Madrid", accesibilidad: nil, hasParking: false, hasBusConnection: false, hasMetroConnection: true, corMetro: "L1", corMl: nil, corCercanias: nil, corTranvia: nil),
            Stop(id: "3", name: "Chamartin", latitude: 40.4721, longitude: -3.6826, connectionLineIds: [], province: "Madrid", accesibilidad: nil, hasParking: false, hasBusConnection: false, hasMetroConnection: true, corMetro: "L1, L10", corMl: nil, corCercanias: "C3, C4", corTranvia: nil),
        ],
        dataService: DataService()
    )
    .padding()
}
