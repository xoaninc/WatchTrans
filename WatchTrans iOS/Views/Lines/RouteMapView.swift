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

    // Shape points for the route polyline (from API when available)
    var shapePoints: [CLLocationCoordinate2D]?

    @State private var mapPosition: MapCameraPosition
    @State private var selectedStop: Stop?
    @State private var isFullScreen = false

    var lineColor: Color {
        Color(hex: line.colorHex) ?? .blue
    }

    init(line: Line, stops: [Stop], dataService: DataService, shapePoints: [CLLocationCoordinate2D]? = nil) {
        self.line = line
        self.stops = stops
        self.dataService = dataService
        self.shapePoints = shapePoints

        // Calculate the region to fit all stops
        let coordinates = stops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let region = Self.regionToFit(coordinates: coordinates)
        _mapPosition = State(initialValue: .region(region))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Map header
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

            // Map
            Map(position: $mapPosition, selection: $selectedStop) {
                // Route polyline
                if let shapePoints = shapePoints, !shapePoints.isEmpty {
                    // Use actual shape data from API
                    MapPolyline(coordinates: shapePoints)
                        .stroke(lineColor, lineWidth: 4)
                } else if stops.count > 1 {
                    // Fallback: connect stops in order (temporary until shapes API ready)
                    let coordinates = stops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                    MapPolyline(coordinates: coordinates)
                        .stroke(lineColor.opacity(0.7), style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
                }

                // Stop markers
                ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                    let isTerminal = index == 0 || index == stops.count - 1

                    Annotation(
                        stop.name,
                        coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude),
                        anchor: .bottom
                    ) {
                        StopMarkerView(
                            stop: stop,
                            lineColor: lineColor,
                            isTerminal: isTerminal,
                            isSelected: selectedStop?.id == stop.id
                        )
                    }
                    .tag(stop)
                }
            }
            .mapStyle(.standard(elevation: .realistic, emphasis: .automatic, pointsOfInterest: .excludingAll, showsTraffic: false))
            .mapControls {
                MapCompass()
                MapScaleView()
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
                lineColor: lineColor,
                initialPosition: mapPosition
            )
        }
    }

    // MARK: - Calculate region to fit all coordinates

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

// MARK: - Stop Marker View

struct StopMarkerView: View {
    let stop: Stop
    let lineColor: Color
    let isTerminal: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            // Circle marker
            ZStack {
                Circle()
                    .fill(isTerminal ? lineColor : .white)
                    .frame(width: isTerminal ? 24 : 16, height: isTerminal ? 24 : 16)

                Circle()
                    .stroke(lineColor, lineWidth: isTerminal ? 3 : 2)
                    .frame(width: isTerminal ? 24 : 16, height: isTerminal ? 24 : 16)

                if isTerminal {
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

            // Name label (only for terminals or selected)
            if isTerminal || isSelected {
                Text(stop.name)
                    .font(.caption2)
                    .fontWeight(isTerminal ? .bold : .medium)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                    )
                    .lineLimit(1)
            }
        }
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
    let lineColor: Color
    let initialPosition: MapCameraPosition

    @Environment(\.dismiss) private var dismiss
    @State private var mapPosition: MapCameraPosition
    @State private var selectedStop: Stop?
    @State private var mapStyle: MapStyleOption = .standard

    enum MapStyleOption: String, CaseIterable {
        case standard = "Estandar"
        case satellite = "Satelite"
        case hybrid = "Hibrido"
    }

    init(line: Line, stops: [Stop], shapePoints: [CLLocationCoordinate2D]?, lineColor: Color, initialPosition: MapCameraPosition) {
        self.line = line
        self.stops = stops
        self.shapePoints = shapePoints
        self.lineColor = lineColor
        self.initialPosition = initialPosition
        _mapPosition = State(initialValue: initialPosition)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $mapPosition, selection: $selectedStop) {
                    // Route polyline
                    if let shapePoints = shapePoints, !shapePoints.isEmpty {
                        MapPolyline(coordinates: shapePoints)
                            .stroke(lineColor, lineWidth: 5)
                    } else if stops.count > 1 {
                        let coordinates = stops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                        MapPolyline(coordinates: coordinates)
                            .stroke(lineColor.opacity(0.7), style: StrokeStyle(lineWidth: 4, dash: [10, 5]))
                    }

                    // Stop markers
                    ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                        let isTerminal = index == 0 || index == stops.count - 1

                        Annotation(
                            stop.name,
                            coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude),
                            anchor: .bottom
                        ) {
                            StopMarkerView(
                                stop: stop,
                                lineColor: lineColor,
                                isTerminal: isTerminal,
                                isSelected: selectedStop?.id == stop.id
                            )
                        }
                        .tag(stop)
                    }
                }
                .mapStyle(currentMapStyle)
                .mapControls {
                    MapCompass()
                    MapScaleView()
                    MapUserLocationButton()
                }
                .ignoresSafeArea(edges: .bottom)

                // Selected stop panel
                if let stop = selectedStop {
                    VStack(spacing: 0) {
                        SelectedStopInfoView(stop: stop, lineColor: lineColor)
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12, corners: [.topLeft, .topRight])
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: -2)
                    .transition(.move(edge: .bottom))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedStop?.id)
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

    private var currentMapStyle: MapStyle {
        switch mapStyle {
        case .standard:
            return .standard(elevation: .realistic, emphasis: .automatic, pointsOfInterest: .excludingAll, showsTraffic: false)
        case .satellite:
            return .imagery(elevation: .realistic)
        case .hybrid:
            return .hybrid(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: false)
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
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
            routeIds: ["METRO_1"]
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
