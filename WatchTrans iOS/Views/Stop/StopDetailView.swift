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
    @State private var correspondences: [CorrespondenceInfo] = []
    @State private var accesses: [StationAccess] = []
    @State private var isLoading = true
    @State private var hasLoadedOnce = false
    @State private var refreshTimer: Timer?
    @State private var refreshCount = 0  // Counter for full refresh every 5 cycles
    @State private var isAlertsExpanded = false
    @State private var showFavoriteAlert = false
    @State private var favoriteAlertMessage = ""
    @State private var showMapOptions = false

    // Network monitoring
    private var networkMonitor = NetworkMonitor.shared

    // Map camera position centered on stop
    @State private var mapPosition: MapCameraPosition

    init(stop: Stop, dataService: DataService, locationService: LocationService, favoritesManager: FavoritesManager?) {
        self.stop = stop
        self.dataService = dataService
        self.locationService = locationService
        self.favoritesManager = favoritesManager

        // Initialize map position - zoomed in closer to show station and nearby accesses
        _mapPosition = State(initialValue: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Map header with accesses
                Map(position: $mapPosition) {
                    // Station marker
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

                    // Access markers (entrances)
                    ForEach(accesses) { access in
                        Annotation("", coordinate: CLLocationCoordinate2D(
                            latitude: access.lat,
                            longitude: access.lon
                        )) {
                            Image(systemName: access.wheelchair == true ? "figure.roll" : "door.left.hand.open")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(Circle().fill(Color.green))
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
                        ConnectionsSectionView(
                            stop: stop,
                            dataService: dataService,
                            stopLatitude: stop.latitude,
                            stopLongitude: stop.longitude
                        )
                    }

                    // Nearby stations (correspondences)
                    if !correspondences.isEmpty {
                        NearbyStationsSectionView(correspondences: correspondences)
                    }

                    // Navigate to nearest access
                    if !accesses.isEmpty {
                        NearestAccessSectionView(
                            accesses: accesses,
                            userLocation: locationService.currentLocation
                        )
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
                HStack(spacing: 16) {
                    // Open in Maps button
                    Button {
                        showMapOptions = true
                    } label: {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond")
                            .foregroundStyle(.blue)
                    }

                    // Favorite button
                    if let manager = favoritesManager {
                        Button {
                            // Haptic feedback
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()

                            if manager.isFavorite(stopId: stop.id) {
                                manager.removeFavorite(stopId: stop.id)
                            } else {
                                let result = manager.addFavorite(stop: stop)
                                switch result {
                                case .success:
                                    break // Already handled by state update
                                case .limitReached:
                                    favoriteAlertMessage = "Has alcanzado el limite de \(manager.maxFavorites) favoritos"
                                    showFavoriteAlert = true
                                case .alreadyExists:
                                    break // Should not happen due to isFavorite check
                                case .saveFailed(let error):
                                    favoriteAlertMessage = "Error al guardar: \(error.localizedDescription)"
                                    showFavoriteAlert = true
                                }
                            }
                        } label: {
                            Image(systemName: manager.isFavorite(stopId: stop.id) ? "star.fill" : "star")
                                .foregroundStyle(manager.isFavorite(stopId: stop.id) ? .yellow : .gray)
                        }
                    }
                }
            }
        }
        .alert("Favoritos", isPresented: $showFavoriteAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(favoriteAlertMessage)
        }
        .confirmationDialog("Abrir en", isPresented: $showMapOptions, titleVisibility: .visible) {
            ForEach(MapLauncher.availableApps(), id: \.name) { app in
                Button(app.name) {
                    MapLauncher.open(
                        coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude),
                        name: stop.name,
                        in: app
                    )
                }
            }
            Button("Cancelar", role: .cancel) { }
        }
        .refreshable {
            await refreshDepartures()
            dataService.clearArrivalCache()
        }
        .task {
            await loadData()
        }
        .onAppear {
            startAutoRefresh()
            // Record visit for frequent stops detection
            FrequentStopsService.shared.recordVisit(stopId: stop.id, stopName: stop.name)
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
                refreshCount += 1
                dataService.clearArrivalCache()

                // Full refresh every 5 cycles, light refresh otherwise
                if refreshCount >= 5 {
                    refreshCount = 0
                    await loadData()
                } else {
                    await refreshDepartures()
                }
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func loadData() async {
        // Solo mostrar spinner en la primera carga
        if !hasLoadedOnce {
            isLoading = true
        }

        // Load ALL data on first load
        async let departuresTask = dataService.fetchArrivals(for: stop.id)
        async let alertsTask = dataService.fetchAlertsForStop(stopId: stop.id)
        async let correspondencesTask = dataService.fetchCorrespondences(stopId: stop.id)
        async let accessesTask = dataService.fetchAccesses(stopId: stop.id)

        departures = await departuresTask
        alerts = await alertsTask
        correspondences = await correspondencesTask
        accesses = await accessesTask

        // If no accesses found and this stop has Metro correspondence,
        // try to load accesses from the corresponding Metro station
        // (Metro Madrid has accesses imported, Cercanías doesn't)
        if accesses.isEmpty, let corMetro = stop.corMetro, !corMetro.isEmpty {
            // Find Metro station with same name in loaded stops
            let metroStop = dataService.stops.first { otherStop in
                otherStop.id.hasPrefix("METRO_") &&
                otherStop.name.lowercased() == stop.name.lowercased()
            }
            if let metroStop = metroStop {
                DebugLog.log("🚪 [StopDetail] No accesses for \(stop.id), trying Metro station \(metroStop.id)")
                accesses = await dataService.fetchAccesses(stopId: metroStop.id)
            }
        }

        // Update map region to include accesses if loaded from Metro station
        if !accesses.isEmpty {
            updateMapToIncludeAccesses()
        }

        hasLoadedOnce = true
        isLoading = false
    }

    /// Light refresh - only fetches time-sensitive data (departures + alerts)
    /// Used for pull-to-refresh and auto-refresh
    private func refreshDepartures() async {
        async let departuresTask = dataService.fetchArrivals(for: stop.id)
        async let alertsTask = dataService.fetchAlertsForStop(stopId: stop.id)

        departures = await departuresTask
        alerts = await alertsTask
    }

    /// Update map region to include both the station and all accesses
    private func updateMapToIncludeAccesses() {
        guard !accesses.isEmpty else { return }

        // Collect all points: station + accesses
        var minLat = stop.latitude
        var maxLat = stop.latitude
        var minLon = stop.longitude
        var maxLon = stop.longitude

        for access in accesses {
            minLat = min(minLat, access.lat)
            maxLat = max(maxLat, access.lat)
            minLon = min(minLon, access.lon)
            maxLon = max(maxLon, access.lon)
        }

        // Add padding (20% on each side)
        let latPadding = max((maxLat - minLat) * 0.2, 0.001)
        let lonPadding = max((maxLon - minLon) * 0.2, 0.001)

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = (maxLat - minLat) + latPadding * 2
        let spanLon = (maxLon - minLon) + lonPadding * 2

        mapPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        ))

        DebugLog.log("🗺️ [StopDetail] Updated map to include \(accesses.count) accesses")
    }
}

// MARK: - Nearest Access Section View

struct NearestAccessSectionView: View {
    let accesses: [StationAccess]
    let userLocation: CLLocation?

    /// Find the nearest access to user's location
    private var nearestAccess: (access: StationAccess, distance: Double)? {
        guard let userLocation = userLocation else {
            // No user location, return first access
            guard let first = accesses.first else { return nil }
            return (first, 0)
        }

        var nearest: (StationAccess, Double)?

        for access in accesses {
            let accessLocation = CLLocation(latitude: access.lat, longitude: access.lon)
            let distance = userLocation.distance(from: accessLocation)

            if nearest == nil || distance < nearest!.1 {
                nearest = (access, distance)
            }
        }

        return nearest
    }

    /// Format distance for display
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        }
        return String(format: "%.1fkm", meters / 1000)
    }

    var body: some View {
        if let nearest = nearestAccess {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(.blue)
                    Text("Entrada más cercana")
                        .font(.headline)
                }

                Button {
                    openNavigationToAccess(nearest.access)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                if nearest.access.wheelchair == true {
                                    Image(systemName: "figure.roll")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                                Text(nearest.access.address)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }

                            HStack(spacing: 8) {
                                if userLocation != nil && nearest.distance > 0 {
                                    Text(formatDistance(nearest.distance))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let hours = nearest.access.hoursString {
                                    Text(hours)
                                        .font(.caption)
                                        .foregroundStyle(nearest.access.isCurrentlyOpen ? .green : .red)
                                }
                            }
                        }

                        Spacer()

                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }

    private func openNavigationToAccess(_ access: StationAccess) {
        let coordinate = CLLocationCoordinate2D(latitude: access.lat, longitude: access.lon)

        // Use URL scheme to avoid deprecated MKPlacemark API
        let urlString = "maps://?daddr=\(coordinate.latitude),\(coordinate.longitude)&dirflg=w&t=m"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
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

                // Province
                if let province = stop.province, !province.isEmpty {
                    Text(province)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
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

                    if stop.hasBusConnection {
                        Label("Bus", systemImage: "bus.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
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
    let stopLatitude: Double
    let stopLongitude: Double

    // Default colors for when line not found (same as Watch app)
    private let defaultMetroColor = "#ED1C24"
    private let defaultMlColor = "#3A7DDA"
    private let defaultCercaniasColor = "#75B2E0"
    private let defaultTranviaColor = "#E4002B"

    @State private var linesLoaded = false

    /// All badges ordered: Cercanías → Metro → Metro Ligero → Tranvía
    private var allBadges: [(name: String, colorHex: String)] {
        var badges: [(String, String)] = []

        // 1. Cercanías
        for line in parseLines(stop.corCercanias) {
            let color = dataService.getLineColor(by: line) ?? defaultCercaniasColor
            badges.append((line, color))
        }

        // 2. Metro
        for line in parseLines(stop.corMetro) {
            let color = dataService.getLineColor(by: line) ?? defaultMetroColor
            badges.append((line, color))
        }

        // 3. Metro Ligero
        for line in parseLines(stop.corMl) {
            let color = dataService.getLineColor(by: line) ?? defaultMlColor
            badges.append((line, color))
        }

        // 4. Tranvía
        for line in parseLines(stop.corTranvia) {
            let color = dataService.getLineColor(by: line) ?? defaultTranviaColor
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
        .task {
            // Load lines if not already loaded to get correct colors
            if dataService.lines.isEmpty {
                await dataService.fetchLinesIfNeeded(
                    latitude: stopLatitude,
                    longitude: stopLongitude
                )
                linesLoaded = true  // Trigger view update
            }
        }
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
                VStack(spacing: 8) {
                    if !NetworkMonitor.shared.isConnected {
                        // Offline with no cache - show helpful message
                        Image(systemName: "icloud.slash")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Sin datos en cache")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Visita esta parada con conexion para guardar horarios offline")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("No hay salidas programadas")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
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

// MARK: - Nearby Stations Section (Correspondences)

struct NearbyStationsSectionView: View {
    let correspondences: [CorrespondenceInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.green)
                Text("Estaciones cercanas a pie")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            ForEach(correspondences, id: \.id) { correspondence in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(correspondence.toStopName)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(correspondence.toLines)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("\(max(1, correspondence.walkTimeS / 60)) min")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Text("\(correspondence.distanceM) m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
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
