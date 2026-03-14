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
    let display: StopDisplay?
    let dataService: DataService
    let locationService: LocationService
    let favoritesManager: FavoritesManager?

    @Environment(\.scenePhase) private var scenePhase

    @State private var departures: [Arrival] = []
    @State private var alerts: [AlertResponse] = []
    @State private var correspondences: [CorrespondenceInfo] = []
    @State private var transportModes: [TransportModeInfo] = []
    @State private var accesses: [StationAccess] = []
    @State private var isLoading = true
    @State private var hasLoadedOnce = false
    @State private var refreshTimer: Timer?
    @State private var refreshCount = 0  // Counter for full refresh every 5 cycles
    @State private var isAlertsExpanded = false
    @State private var showFavoriteAlert = false
    @State private var favoriteAlertMessage = ""
    @State private var showMapOptions = false
    @State private var stationOccupancy: [StationOccupancyResponse] = []
    @State private var equipmentStatus: [EquipmentStatusResponse] = []
    @State private var airQualityData: [String: TrainAirQuality] = [:]

    // Network monitoring
    private var networkMonitor = NetworkMonitor.shared

    // Map camera position centered on stop
    @State private var mapPosition: MapCameraPosition

    init(
        stop: Stop,
        display: StopDisplay? = nil,
        dataService: DataService,
        locationService: LocationService,
        favoritesManager: FavoritesManager?
    ) {
        self.stop = stop
        self.display = display
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

                    // Station occupancy (TMB Metro)
                    if !stationOccupancy.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ocupación de la estación")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(stationOccupancy, id: \.track) { occ in
                                HStack(spacing: 6) {
                                    Text("Andén \(occ.track ?? 0)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    ProgressView(value: Double(occ.occupancyPct ?? 0), total: 100)
                                        .tint(occupancyColor(pct: occ.occupancyPct ?? 0))
                                    Text("\(occ.occupancyPct ?? 0)%")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Equipment status (Metro Sevilla elevators/escalators)
                    if !equipmentStatus.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Estado de equipos")
                                .font(.headline)

                            let broken = equipmentStatus.filter { $0.isBroken }
                            if !broken.isEmpty {
                                ForEach(broken) { device in
                                    HStack(spacing: 6) {
                                        Image(systemName: device.isElevator ? "elevator.fill" : "escalator")
                                            .foregroundStyle(.red)
                                        VStack(alignment: .leading) {
                                            Text(device.isElevator ? "Ascensor" : "Escalera mecánica")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text("\(device.location ?? "") — Fuera de servicio")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                }
                            }

                            let working = equipmentStatus.filter { !$0.isBroken }
                            if !working.isEmpty {
                                DisclosureGroup("Todos los equipos (\(working.count) operativos)") {
                                    ForEach(working) { device in
                                        HStack(spacing: 6) {
                                            Image(systemName: device.isElevator ? "elevator.fill" : "escalator")
                                                .foregroundStyle(.green)
                                                .font(.caption)
                                            Text(device.isElevator ? "Ascensor" : "Escalera")
                                                .font(.caption)
                                            Text(device.location ?? "")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            if let dir = device.direction, dir != "disabled" {
                                                Image(systemName: dir == "up" ? "arrow.up" : "arrow.down")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Connection badges
                    if hasConnections {
                        ConnectionsSectionView(
                            stop: stop,
                            dataService: dataService,
                            transportModes: transportModes,
                            stopLatitude: stop.latitude,
                            stopLongitude: stop.longitude
                        )
                    }

                    // Nearby stations (correspondences)
                    if !correspondences.isEmpty {
                        NearbyStationsSectionView(
                            correspondences: correspondences,
                            parentStopId: stop.id,
                            dataService: dataService,
                            locationService: locationService,
                            favoritesManager: favoritesManager
                        )
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
                        dataService: dataService,
                        airQualityData: airQualityData
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
        !transportModes.isEmpty ||
        !(stop.corMetro?.isEmpty ?? true) ||
        !(stop.corMl?.isEmpty ?? true) ||
        !(stop.corTren?.isEmpty ?? true) ||
        !(stop.corTranvia?.isEmpty ?? true) ||
        !(stop.corFunicular?.isEmpty ?? true)
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

        // Week 3 Optimization: Load full details + arrivals in parallel
        async let fullDetailsTask = dataService.fetchStopDetails(stopId: stop.id)
        async let arrivalsTask = dataService.fetchArrivals(for: stop.id)
        
        let (fullDetails, rawDepartures) = await (fullDetailsTask, arrivalsTask)
        
        // Update UI with full details
        if fullDetails != nil {
            alerts = await dataService.fetchAlertsForStop(stopId: stop.id)
            // TODO: Re-enable when Stop model has correspondences, accesses, and routes properties
            // correspondences = fullDetails.correspondences ?? []
            // accesses = fullDetails.accesses ?? []
            // if fullDetails.routes != nil {
            //     // Future optimization: Use routes from /full to populate connection badges
            // }
        } else {
            // Fallback to old method if /full fails
            alerts = await dataService.fetchAlertsForStop(stopId: stop.id)
            correspondences = await dataService.fetchCorrespondences(stopId: stop.id)
            transportModes = await dataService.fetchTransportModes(stopId: stop.id)
            accesses = await dataService.fetchAccesses(stopId: stop.id)
        }

        // Process arrivals
        departures = dataService.filterArrivals(rawDepartures, for: display)

        // If no accesses found and this stop has Metro correspondence,
        // try to load accesses from the corresponding Metro station
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

        // Fetch station occupancy for TMB Metro stops
        if stop.id.hasPrefix("TMB_METRO_") {
            stationOccupancy = (try? await dataService.gtfsRealtimeService.fetchStationOccupancy(stopIds: [stop.id])) ?? []
        }

        // Fetch equipment status and air quality for Metro Sevilla stops
        if stop.id.hasPrefix("METRO_SEVILLA_") {
            equipmentStatus = (try? await dataService.gtfsRealtimeService.fetchEquipmentStatus(stopId: stop.id)) ?? []
            airQualityData = (try? await dataService.gtfsRealtimeService.fetchMetroSevillaAirQuality()) ?? [:]
        }

        hasLoadedOnce = true
        isLoading = false
        
        // Haptic feedback on completion
        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.impactOccurred()
    }

    /// Light refresh - only fetches time-sensitive data (departures + alerts)
    /// Used for pull-to-refresh and auto-refresh
    private func refreshDepartures() async {
        let rawDepartures = await dataService.fetchArrivals(for: stop.id)
        departures = dataService.filterArrivals(rawDepartures, for: display)
        
        alerts = await dataService.fetchAlertsForStop(stopId: stop.id)
        
        // Soft haptic feedback on silent refresh
        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.impactOccurred()
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

    private func occupancyColor(pct: Int) -> Color {
        if pct < 30 { return .green }
        if pct < 60 { return .orange }
        return .red
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
    
    /// Alerts sorted with suspensions first
    private var sortedAlerts: [AlertResponse] {
        alerts.sorted { a, b in
            if a.isSuspension != b.isSuspension { return a.isSuspension }
            return false
        }
    }

    /// Check if any alert is a full suspension
    private var hasFullSuspension: Bool {
        alerts.contains { $0.isFullSuspension }
    }

    /// Primary color for the alerts section
    private var primaryColor: Color {
        hasFullSuspension ? .red : .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header - tappable
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: hasFullSuspension ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(primaryColor)
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
                ForEach(sortedAlerts.prefix(2)) { alert in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(alert.severityColor)
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
                            
                            // Show restoration time for suspensions
                            if let restoreTime = alert.estimatedRestorationTime {
                                Text("Reanudación: \(restoreTime)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(alert.isFullSuspension ? .red : .orange)
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
                ForEach(sortedAlerts) { alert in
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
                        
                        // Show restoration time for suspensions
                        if let restoreTime = alert.estimatedRestorationTime {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.caption2)
                                Text("Reanudación estimada: \(restoreTime)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(alert.isFullSuspension ? .red : .orange)
                            .padding(.top, 2)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(alert.severityColor.opacity(0.15))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(primaryColor.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Connections Section

struct ConnectionsSectionView: View {
    let stop: Stop
    let dataService: DataService
    let transportModes: [TransportModeInfo]
    let stopLatitude: Double
    let stopLongitude: Double

    @State private var linesLoaded = false

    /// All badges ordered: Cercanías → Metro → Metro Ligero → Tranvía → Funicular
    private var allBadges: [(name: String, colorHex: String)] {
        var badges: [(String, String)] = []

        // 1. Cercanías
        let cercaniasLines = stop.correspondences?.tren ?? parseLines(stop.corTren)
        for line in cercaniasLines {
            let color = dataService.getLineColor(by: line) ?? ""
            badges.append((formatBadgeName(line, type: "Cercanías"), color))
        }

        // 2. Metro
        let metroLines = stop.correspondences?.metro ?? parseLines(stop.corMetro)
        for line in metroLines {
            let color = dataService.getLineColor(by: line) ?? ""
            badges.append((formatBadgeName(line, type: "Metro"), color))
        }

        // 3. Metro Ligero
        let mlLines = stop.correspondences?.ml ?? parseLines(stop.corMl)
        for line in mlLines {
            let color = dataService.getLineColor(by: line) ?? ""
            badges.append((formatBadgeName(line, type: "ML"), color))
        }

        // 4. Tranvía
        let tramLines = stop.correspondences?.tranvia ?? parseLines(stop.corTranvia)
        for line in tramLines {
            let color = dataService.getLineColor(by: line) ?? ""
            badges.append((formatBadgeName(line, type: "TRAM"), color))
        }
        
        // 5. Funicular
        let funicularLines = stop.correspondences?.funicular ?? parseLines(stop.corFunicular)
        for line in funicularLines {
            badges.append((formatBadgeName(line, type: "Funicular"), "#000000"))
        }

        return badges
    }

    private func formatBadgeName(_ name: String, type: String) -> String {
        if name.lowercased() == "true" {
            return type
        }
        return name
    }

    var body: some View {
        let badges = allBadges

        Group {
            if !badges.isEmpty {
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
                        ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
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
    var airQualityData: [String: TrainAirQuality] = [:]

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
                    if let _ = dataService.error {
                        // API Error (e.g. 504 Gateway Timeout from Renfe)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        Text("Sin conexion con el operador")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("El servidor de transporte no responde. Intentalo de nuevo mas tarde.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else if !NetworkMonitor.shared.isConnected {
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

                    NavigationLink(destination: TrainDetailView(
                        arrival: departure,
                        lineColor: lineColor,
                        dataService: dataService,
                        airQuality: departure.vehicleLabel.flatMap { airQualityData[$0] }
                    )) {
                        ArrivalRowView(
                            arrival: departure,
                            dataService: dataService,
                            airQuality: departure.vehicleLabel.flatMap { airQualityData[$0] }
                        )
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
    let parentStopId: String
    let dataService: DataService
    let locationService: LocationService
    let favoritesManager: FavoritesManager?
    
    @State private var selectedStop: Stop?
    @State private var loadingStopId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.green)
                Text("Estaciones cercanas a pie")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            ForEach(correspondences.filter { $0.toStopId != parentStopId }, id: \.identifiableId) { correspondence in
                Button {
                    Task {
                        loadingStopId = correspondence.toStopId
                        // Try to get from cache or fetch from API
                        if let stop = await dataService.fetchStopDetails(stopId: correspondence.toStopId) {
                            selectedStop = stop
                        }
                        loadingStopId = nil
                    }
                } label: {
                    ZStack {
                        CorrespondenceRow(correspondence: correspondence)
                        
                        if loadingStopId == correspondence.toStopId {
                            ProgressView()
                                .padding()
                                .background(.regularMaterial)
                                .cornerRadius(8)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .navigationDestination(item: $selectedStop) { stop in
            StopDetailView(
                stop: stop,
                dataService: dataService,
                locationService: locationService,
                favoritesManager: favoritesManager
            )
        }
    }
}

struct CorrespondenceRow: View {
    let correspondence: CorrespondenceInfo
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(correspondence.toStopName ?? "Estación cercana")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.leading)

                if let lines = correspondence.toLines {
                    Text(lines)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("\(max(1, (correspondence.walkTimeS ?? 0) / 60)) min")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                if let distance = correspondence.distanceM {
                    Text("\(distance) m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.leading, 4)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
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
                province: "Madrid",
                accesibilidad: "Accesible",
                hasParking: true,
                hasBusConnection: true,
                hasMetroConnection: true,
                corMetro: "L1",
                corMl: nil,
                corTren: "C1, C3, C4",
                corTranvia: nil
            ),
            dataService: DataService(),
            locationService: LocationService(),
            favoritesManager: nil
        )
    }
}
