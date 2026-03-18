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
    @State private var stationInterior: StationInteriorResponse?
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
    @State private var metroOperatingHours: DayOperatingHours?
    @State private var showMap = false
    @State private var detailedStop: Stop?

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

    private var stopMapHeader: some View {
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
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if showMap {
                    stopMapHeader
                } else {
                    Color(.systemGray6)
                        .frame(height: 200)
                }

                VStack(spacing: 16) {
                    // Offline banner
                    if !networkMonitor.isConnected {
                        OfflineBannerView()
                    }

                    // Stop info header
                    StopHeaderView(
                        stop: detailedStop ?? stop,
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

                    // Equipment status (elevators/escalators)
                    if !equipmentStatus.isEmpty {
                        EquipmentStatusSection(equipment: equipmentStatus, operatingHours: metroOperatingHours)
                            .padding(.horizontal)
                    }

                    // Connection badges
                    if hasConnections {
                        ConnectionsSectionView(
                            stop: stop,
                            dataService: dataService,
                            locationService: locationService,
                            favoritesManager: favoritesManager,
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

                    // Station interior (accesses, pathways, vestibules, levels)
                    if let interior = stationInterior,
                       !(interior.pathways ?? []).isEmpty || !(interior.accesses ?? []).isEmpty || !(interior.vestibules ?? []).isEmpty || !(interior.levels ?? []).isEmpty {
                        StationInteriorSection(interior: interior)
                            .padding(.horizontal)
                    }

                    // Navigate to nearest access (hidden when station-interior has accesses)
                    if !accesses.isEmpty && (stationInterior?.accesses ?? []).isEmpty {
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
                        locationService: locationService,
                        favoritesManager: favoritesManager,
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
            // Defer map rendering until after navigation transition completes
            try? await Task.sleep(for: .milliseconds(300))
            showMap = true
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

        // Load full details and arrivals sequentially (async let causes swift_task_dealloc crash)
        let fullDetails = await dataService.fetchStopDetails(stopId: stop.id, forceRefresh: true)
        let rawDepartures = await dataService.fetchArrivals(for: stop.id)

        // Update UI with full details (acercaService, serviceStatus, etc.)
        detailedStop = fullDetails
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

        // Fetch station interior (levels + pathways for stations that support it)
        stationInterior = try? await dataService.gtfsRealtimeService.fetchStationInterior(stopId: stop.id)

        // Fetch station occupancy for TMB Metro stops
        if stop.id.hasPrefix("TMB_METRO_") {
            stationOccupancy = (try? await dataService.gtfsRealtimeService.fetchStationOccupancy(stopIds: [stop.id])) ?? []
        }

        // Fetch equipment status and air quality for Metro Sevilla stops
        if stop.id.hasPrefix("METRO_SEVILLA_") {
            equipmentStatus = (try? await dataService.gtfsRealtimeService.fetchEquipmentStatus(stopId: stop.id)) ?? []
            airQualityData = (try? await dataService.gtfsRealtimeService.fetchMetroSevillaAirQuality()) ?? [:]

            // Fetch operating hours for nightly shutdown detection
            if let response = try? await dataService.gtfsRealtimeService.fetchRouteOperatingHours(routeId: "METRO_SEVILLA_L1-CE-OQ") {
                let calendar = Calendar.current
                let weekday = calendar.component(.weekday, from: Date())
                switch weekday {
                case 1: metroOperatingHours = response.sunday
                case 7: metroOperatingHours = response.saturday
                case 6: metroOperatingHours = response.friday
                default: metroOperatingHours = response.weekday
                }
            }
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

                    // Transport type of this stop
                    switch stop.transportType {
                    case .cercanias:
                        Label("Tren", systemImage: "tram.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    case .metro:
                        Label("Metro", systemImage: "tram.tunnel.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    case .tram:
                        Label("Tram", systemImage: "lightrail.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    case .metroLigero:
                        Label("Metro Ligero", systemImage: "tram.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    case .fgc:
                        Label("FGC", systemImage: "tram.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    case .euskotren:
                        Label("Euskotren", systemImage: "tram.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    case .bus:
                        Label("Bus", systemImage: "bus.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if stop.hasBusConnection {
                        Label("Bus", systemImage: "bus.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if stop.hasParking {
                        Label("Parking Bici", systemImage: "bicycle")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    if stop.wheelchairBoarding == 1 {
                        Label("Accesible", systemImage: "figure.roll")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    } else if stop.wheelchairBoarding == 2 {
                        HStack(spacing: 2) {
                            ZStack {
                                Image(systemName: "figure.roll")
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .light))
                            }
                            Text("No accesible")
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }

                // Servicio Acerca PMR (48 Renfe stations)
                if let acerca = stop.acercaService {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.roll")
                                .foregroundStyle(.blue)
                            Text("Servicio Acerca PMR")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        if let meetingPoint = acerca.meetingPoint, !meetingPoint.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Punto de encuentro: \(meetingPoint)")
                                    .font(.caption)
                            }
                        }

                        if let noticeTime = acerca.noticeTime, !noticeTime.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Aviso previo: \(noticeTime)")
                                    .font(.caption)
                            }
                        }

                        HStack(spacing: 8) {
                            if acerca.parking == true {
                                Label("Parking", systemImage: "p.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                            if acerca.anden == true {
                                Label("Anden", systemImage: "train.side.front.car")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                            if acerca.aseos == true {
                                Label("Aseos", systemImage: "toilet")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                            if acerca.vestibulo == true {
                                Label("Vestibulo", systemImage: "door.left.hand.open")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(10)
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
                                    .foregroundStyle(alert.severityColor)
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
                            .foregroundStyle(alert.severityColor)
                            .padding(.top, 2)
                        }

                        // Alternative transport
                        if let alternatives = alert.alternativeTransport, !alternatives.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Transporte alternativo")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                                ForEach(alternatives) { alt in
                                    HStack(spacing: 6) {
                                        Image(systemName: alt.icon)
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(alt.description)
                                                .font(.caption)
                                            if let from = alt.fromStation, let to = alt.toStation {
                                                Text("\(from) → \(to)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
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
    let locationService: LocationService
    let favoritesManager: FavoritesManager?
    let transportModes: [TransportModeInfo]
    let stopLatitude: Double
    let stopLongitude: Double

    @State private var linesLoaded = false
    @State private var shakeOffset: CGFloat = 0

    private enum TransportKind: String {
        case cercanias, metro, metroLigero, tram, funicular, bus
    }

    private struct ConnectionBadge: Identifiable {
        let id = UUID()
        let name: String
        let colorHex: String
        let kind: TransportKind
    }

    /// All badges ordered: Cercanías → Metro → Metro Ligero → Tranvía → Funicular
    private var allBadges: [ConnectionBadge] {
        var badges: [ConnectionBadge] = []

        // 1. Cercanías
        for line in stop.correspondences?.tren ?? parseLines(stop.corTren) {
            let color = dataService.getLineColor(by: line) ?? ""
            badges.append(ConnectionBadge(name: formatBadgeName(line, type: "Cercanías"), colorHex: color, kind: .cercanias))
        }

        // 2. Metro
        for line in stop.correspondences?.metro ?? parseLines(stop.corMetro) {
            let color = dataService.getLineColor(by: line) ?? ""
            badges.append(ConnectionBadge(name: formatBadgeName(line, type: "Metro"), colorHex: color, kind: .metro))
        }

        // 3. Metro Ligero
        for line in stop.correspondences?.ml ?? parseLines(stop.corMl) {
            let color = dataService.getLineColor(by: line) ?? ""
            badges.append(ConnectionBadge(name: formatBadgeName(line, type: "ML"), colorHex: color, kind: .metroLigero))
        }

        // 4. Tranvía
        for line in stop.correspondences?.tranvia ?? parseLines(stop.corTranvia) {
            let color = dataService.getLineColor(by: line) ?? ""
            badges.append(ConnectionBadge(name: formatBadgeName(line, type: "TRAM"), colorHex: color, kind: .tram))
        }

        // 5. Funicular
        for line in stop.correspondences?.funicular ?? parseLines(stop.corFunicular) {
            badges.append(ConnectionBadge(name: formatBadgeName(line, type: "Funicular"), colorHex: "#000000", kind: .funicular))
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
                    FlowLayout(spacing: 10) {
                        ForEach(badges) { badge in
                            if let targetStop = findCorrespondenceStop(for: badge), targetStop.id != stop.id {
                                NavigationLink(destination: StopDetailView(
                                    stop: targetStop,
                                    display: nil,
                                    dataService: dataService,
                                    locationService: locationService,
                                    favoritesManager: favoritesManager
                                )) {
                                    badgeView(badge)
                                }
                                .buttonStyle(.plain)
                            } else {
                                // Same stop or not found — shake to indicate "you're here"
                                badgeView(badge)
                                    .offset(x: shakeOffset)
                                    .onTapGesture {
                                        withAnimation(.default.speed(4).repeatCount(3, autoreverses: true)) {
                                            shakeOffset = 8
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                            shakeOffset = 0
                                        }
                                    }
                            }
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
                        linesLoaded = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func badgeView(_ badge: ConnectionBadge) -> some View {
        Text(badge.name)
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: badge.colorHex) ?? .gray)
            )
    }

    /// Find the corresponding stop for a badge by matching name and transport type
    private func findCorrespondenceStop(for badge: ConnectionBadge) -> Stop? {
        let stopName = stop.name.lowercased()
        let prefixes: [String]
        switch badge.kind {
        case .cercanias: prefixes = ["RENFE_C_", "RENFE_FEVE_", "RENFE_PROX_", "EUSKOTREN_", "FGC_", "SFM_MALLORCA_"]
        case .metro: prefixes = ["METRO_", "TMB_METRO_"]
        case .metroLigero: prefixes = ["ML_"]  // ML_29_STATION etc.
        case .tram: prefixes = ["TRAM_", "TRANVIA_"]  // TRAM_SEV_, TRAM_BCN_, TRANVIA_ZARAGOZA_
        case .funicular: prefixes = ["TMB_METRO_", "FGC_"]  // TMB FM uses TMB_METRO_, FGC FV uses FGC_
        case .bus: prefixes = ["BUS_"]
        }

        return dataService.stops.first { candidate in
            candidate.id != stop.id &&
            candidate.name.lowercased() == stopName &&
            prefixes.contains(where: { candidate.id.hasPrefix($0) })
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
    let locationService: LocationService
    let favoritesManager: FavoritesManager?
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
                        locationService: locationService,
                        favoritesManager: favoritesManager,
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
