//
//  StopDetailView.swift
//  WatchTrans iOS
//
//  Created by Juan Macias Gomez on 21/1/26.
//

import SwiftUI
import MapKit
import UIKit

struct StopDetailView: View {
    let stop: Stop
    let dataService: DataService
    let locationService: LocationService
    let favoritesManager: FavoritesManager?

    @Environment(\.scenePhase) private var scenePhase

    @State private var departures: [Arrival] = []
    @State private var alerts: [AlertResponse] = []
    @State private var isLoading = true
    @State private var hasLoadedOnce = false
    @State private var refreshTimer: Timer?
    @State private var isAlertsExpanded = false

    // Network monitoring
    private var networkMonitor = NetworkMonitor.shared

    // Map camera position centered on stop
    @State private var mapPosition: MapCameraPosition

    init(stop: Stop, dataService: DataService, locationService: LocationService, favoritesManager: FavoritesManager?) {
        self.stop = stop
        self.dataService = dataService
        self.locationService = locationService
        self.favoritesManager = favoritesManager

        // Initialize map position
        _mapPosition = State(initialValue: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Map header
                Map(position: $mapPosition) {
                    Annotation(stop.name, coordinate: CLLocationCoordinate2D(
                        latitude: stop.latitude,
                        longitude: stop.longitude
                    )) {
                        VStack(spacing: 2) {
                            Image(systemName: "tram.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Circle().fill(Color.blue))
                            Text(stop.name)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemBackground))
                                .cornerRadius(4)
                        }
                    }
                }
                .frame(height: 200)
                .allowsHitTesting(false)

                VStack(spacing: 16) {
                    // Offline banner
                    if !networkMonitor.isConnected {
                        OfflineBannerView()
                    }

                    // Stop info header
                    StopHeaderView(
                        stop: stop,
                        locationService: locationService,
                        favoritesManager: favoritesManager
                    )

                    // Alerts section (expandable)
                    if !alerts.isEmpty {
                        AlertsSectionView(alerts: alerts, isExpanded: $isAlertsExpanded)
                    }

                    // Connection badges
                    if hasConnections {
                        ConnectionsSectionView(stop: stop, dataService: dataService)
                    }

                    // Departures section
                    DeparturesSectionView(
                        departures: departures,
                        isLoading: isLoading,
                        dataService: dataService
                    )
                }
                .padding()
            }
        }
        .navigationTitle(stop.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let manager = favoritesManager {
                    Button {
                        // Haptic feedback
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()

                        if manager.isFavorite(stopId: stop.id) {
                            manager.removeFavorite(stopId: stop.id)
                        } else if manager.favorites.count < manager.maxFavorites {
                            _ = manager.addFavorite(stop: stop)
                        }
                    } label: {
                        Image(systemName: manager.isFavorite(stopId: stop.id) ? "star.fill" : "star")
                            .foregroundStyle(manager.isFavorite(stopId: stop.id) ? .yellow : .gray)
                    }
                }
            }
        }
        .refreshable {
            dataService.clearArrivalCache()
            await loadData()
        }
        .task {
            await loadData()
        }
        .onAppear {
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                startAutoRefresh()
            case .inactive, .background:
                stopAutoRefresh()
            @unknown default:
                break
            }
        }
    }

    // MARK: - Connections Check

    private var hasConnections: Bool {
        !stop.connectionLineIds.isEmpty ||
        stop.corMetro != nil ||
        stop.corMl != nil ||
        stop.corCercanias != nil ||
        stop.corTranvia != nil
    }

    // MARK: - Auto Refresh

    private func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: APIConfiguration.autoRefreshInterval, repeats: true) { _ in
            Task { @MainActor in
                dataService.clearArrivalCache()
                await loadData()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func loadData() async {
        // Solo mostrar spinner en la primera carga, no en auto-refresh
        if !hasLoadedOnce {
            isLoading = true
        }
        async let departuresTask = dataService.fetchArrivals(for: stop.id)
        async let alertsTask = dataService.fetchAlertsForStop(stopId: stop.id)
        departures = await departuresTask
        alerts = await alertsTask
        hasLoadedOnce = true
        isLoading = false
    }
}

// MARK: - Stop Header View

struct StopHeaderView: View {
    let stop: Stop
    let locationService: LocationService
    let favoritesManager: FavoritesManager?

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(stop.name)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 16) {
                    if let location = locationService.currentLocation {
                        Label(stop.formattedDistance(from: location), systemImage: "location")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if stop.hasMetroConnection {
                        Label("Metro", systemImage: "tram.tunnel.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }

                    if stop.hasParking {
                        Label("Parking", systemImage: "p.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                if let accesibilidad = stop.accesibilidad, !accesibilidad.isEmpty {
                    Label(accesibilidad, systemImage: "figure.roll")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Alerts Section (Expandable)

struct AlertsSectionView: View {
    let alerts: [AlertResponse]
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header - tappable
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("\(alerts.count) aviso\(alerts.count == 1 ? "" : "s")")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Preview: show first 2 alerts (collapsed)
            if !isExpanded {
                ForEach(alerts.prefix(2)) { alert in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 2) {
                            if let header = alert.headerText, !header.isEmpty {
                                Text(header)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                            }
                            if let description = alert.descriptionText, !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                if alerts.count > 2 {
                    Text("Toca para ver \(alerts.count - 2) mas...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Expanded: show all alerts
            if isExpanded {
                ForEach(alerts) { alert in
                    VStack(alignment: .leading, spacing: 4) {
                        if let header = alert.headerText, !header.isEmpty {
                            Text(header)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        if let description = alert.descriptionText, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Connections Section

struct ConnectionsSectionView: View {
    let stop: Stop
    let dataService: DataService

    // Default colors for when line not found (same as Watch app)
    private let defaultMetroColor = "#ED1C24"
    private let defaultMlColor = "#3A7DDA"
    private let defaultCercaniasColor = "#75B2E0"
    private let defaultTranviaColor = "#E4002B"

    /// All badges ordered: Cercanías → Metro → Metro Ligero → Tranvía
    private var allBadges: [(name: String, colorHex: String)] {
        var badges: [(String, String)] = []

        // 1. Cercanías
        for line in parseLines(stop.corCercanias) {
            let color = dataService.getLine(by: line)?.colorHex ?? defaultCercaniasColor
            badges.append((line, color))
        }

        // 2. Metro
        for line in parseLines(stop.corMetro) {
            let color = dataService.getLine(by: line)?.colorHex ?? defaultMetroColor
            badges.append((line, color))
        }

        // 3. Metro Ligero
        for line in parseLines(stop.corMl) {
            let color = dataService.getLine(by: line)?.colorHex ?? defaultMlColor
            badges.append((line, color))
        }

        // 4. Tranvía
        for line in parseLines(stop.corTranvia) {
            let color = dataService.getLine(by: line)?.colorHex ?? defaultTranviaColor
            badges.append((line, color))
        }

        return badges
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.blue)
                Text("Correspondencias")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            // Wrap badges in FlowLayout
            FlowLayout(spacing: 6) {
                ForEach(Array(allBadges.enumerated()), id: \.offset) { _, badge in
                    Text(badge.name)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: badge.colorHex) ?? .gray)
                        )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func parseLines(_ value: String?) -> [String] {
        guard let value = value, !value.isEmpty else { return [] }
        return value.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Departures Section

struct DeparturesSectionView: View {
    let departures: [Arrival]
    let isLoading: Bool
    let dataService: DataService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
                Text("Proximas salidas")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(departures.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Cargando salidas...")
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if departures.isEmpty {
                Text("No hay salidas programadas")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(departures) { departure in
                    let lineColor: Color = {
                        if let hex = departure.routeColor {
                            return Color(hex: hex) ?? .blue
                        }
                        return dataService.getLine(by: departure.lineId)?.color ?? .blue
                    }()

                    NavigationLink(destination: TrainDetailView(arrival: departure, lineColor: lineColor, dataService: dataService)) {
                        ArrivalRowView(arrival: departure, dataService: dataService)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Flow Layout (Simple implementation)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = max(totalHeight, currentY + lineHeight)
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

#Preview {
    NavigationStack {
        StopDetailView(
            stop: Stop(
                id: "RENFE_18000",
                name: "Atocha RENFE",
                latitude: 40.4067,
                longitude: -3.6893,
                connectionLineIds: ["c1", "c3", "c4"],
                province: "Madrid",
                accesibilidad: "Accesible",
                hasParking: true,
                hasBusConnection: true,
                hasMetroConnection: true,
                corMetro: "L1",
                corMl: nil,
                corCercanias: "C1, C3, C4",
                corTranvia: nil
            ),
            dataService: DataService(),
            locationService: LocationService(),
            favoritesManager: nil
        )
    }
}
