//
//  ContentView.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//  Redesigned to match original spec
//

import SwiftUI
import SwiftData
import WatchKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var locationService = LocationService()
    @State private var dataService = DataService()
    @State private var favoritesManager: FavoritesManager?
    @State private var refreshTimer: Timer?
    @State private var refreshTrigger = UUID()  // Changes to trigger refresh

    // Network monitoring
    private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Offline banner (shown when no connection)
                    if !networkMonitor.isConnected {
                        OfflineBanner()
                    }

                    // Favorites Section (max 5)
                    if let manager = favoritesManager, !manager.favorites.isEmpty {
                        FavoritesSectionView(
                            favoritesManager: manager,
                            dataService: dataService,
                            locationService: locationService,
                            refreshTrigger: refreshTrigger
                        )
                    }

                    // Recommended Section
                    RecommendedSectionView(
                        dataService: dataService,
                        locationService: locationService,
                        favoritesManager: favoritesManager,
                        refreshTrigger: refreshTrigger
                    )

                    // Check Lines Button
                    NavigationLink(destination: LinesView(dataService: dataService, locationService: locationService)) {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("Check Lines")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            }
            .navigationTitle(dataService.currentLocation?.displayName ?? "WatchTrans")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadData()
        }
        .refreshable {
            // Clear arrival cache to force fresh data
            dataService.clearArrivalCache()
            await loadData()
            // Haptic feedback when refresh completes
            WKInterfaceDevice.current().play(.success)
        }
        .onAppear {
            if favoritesManager == nil {
                favoritesManager = FavoritesManager(modelContext: modelContext)
            }
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

    // MARK: - Auto Refresh (every 50 seconds)

    private func startAutoRefresh() {
        stopAutoRefresh() // Cancel existing timer
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 50, repeats: true) { _ in
            Task { @MainActor in
                // Check if nucleo changed
                await checkAndUpdateNucleo()

                dataService.clearArrivalCache()
                refreshTrigger = UUID()  // Trigger UI refresh
            }
        }
    }

    /// Check if user moved to a different location and reload data if needed
    private func checkAndUpdateNucleo() async {
        guard let location = locationService.currentLocation else { return }

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        // Check if current location context is different from previous
        // Since we use province-based detection now, we just reload on significant moves
        // The API will return the correct province for the new location
        let currentProvince = dataService.currentLocation?.provinceName

        // For now, we reload data on every check to ensure freshness
        // The API handles province detection via PostGIS
        if currentProvince == nil {
            await loadData()
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func loadData() async {
        print("🏠 [ContentView] ========== LOAD DATA ==========")

        if locationService.authorizationStatus == .notDetermined {
            print("🏠 [ContentView] Requesting location permission...")
            locationService.requestPermission()
        }

        locationService.startUpdating()
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Pass user's coordinates to load nearby stops
        let lat = locationService.currentLocation?.coordinate.latitude
        let lon = locationService.currentLocation?.coordinate.longitude
        print("🏠 [ContentView] Location: lat=\(lat ?? 0), lon=\(lon ?? 0)")

        // Save location for Widget to use (via App Group shared storage)
        if let latitude = lat, let longitude = lon {
            SharedStorage.shared.saveLocation(latitude: latitude, longitude: longitude)
        }

        // Fetch transport data (this will detect province from coordinates)
        await dataService.fetchTransportData(latitude: lat, longitude: lon)

        // Debug: Show result
        print("🏠 [ContentView] ========== LOAD RESULT ==========")
        print("🏠 [ContentView] currentLocation: \(dataService.currentLocation?.provinceName ?? "nil")")
        print("🏠 [ContentView] Lines: \(dataService.lines.count)")
        print("🏠 [ContentView] Stops: \(dataService.stops.count)")

        // Save location info for Widget AFTER fetching (so we have the correct province)
        if let location = dataService.currentLocation {
            print("🏠 [ContentView] Saving province to Widget: \(location.provinceName)")
            SharedStorage.shared.saveNucleo(name: location.provinceName, id: 0)
        }
    }
}

// MARK: - Favorites Section

struct FavoritesSectionView: View {
    let favoritesManager: FavoritesManager
    let dataService: DataService
    let locationService: LocationService
    let refreshTrigger: UUID

    // Favorites now just show all saved favorites (stops are loaded by coordinates)
    var favoriteStops: [Stop] {
        let allFavorites = favoritesManager.getFavoriteStops(from: dataService.stops)
        return Array(allFavorites.prefix(5)) // Max 5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                Text("Favorites")
                    .font(.headline)
                Spacer()
                Text("\(favoriteStops.count)/5")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            // Favorite stops
            ForEach(favoriteStops) { stop in
                StopCardView(
                    stop: stop,
                    dataService: dataService,
                    locationService: locationService,
                    favoritesManager: favoritesManager,
                    refreshTrigger: refreshTrigger
                )
            }
        }
    }
}

// MARK: - Recommended Section

struct RecommendedSectionView: View {
    let dataService: DataService
    let locationService: LocationService
    let favoritesManager: FavoritesManager?
    let refreshTrigger: UUID

    // Stops are already filtered by coordinates from the API
    // They come from the user's province/nucleo automatically
    var recommendedStops: [Stop] {
        var stops: [Stop] = []
        var seenNames: Set<String> = []  // Deduplicate by name (multiple platforms same station)
        let favoriteIds = favoritesManager?.favorites.map { $0.stopId } ?? []

        // Sort all stops by distance first
        let sortedByDistance: [Stop]
        if let location = locationService.currentLocation {
            sortedByDistance = dataService.stops.sorted {
                $0.distance(from: location) < $1.distance(from: location)
            }
        } else {
            sortedByDistance = dataService.stops
        }

        // Add stops, skipping duplicates by name and favorites
        for stop in sortedByDistance {
            // Skip if already have a stop with this name (different platform)
            if seenNames.contains(stop.name) {
                continue
            }
            // Skip favorites
            if favoriteIds.contains(stop.id) {
                continue
            }

            stops.append(stop)
            seenNames.insert(stop.name)

            // Max 3 stops
            if stops.count >= 3 {
                break
            }
        }

        return stops
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
                    .font(.caption)
                Text("Recommended")
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            if recommendedStops.isEmpty {
                Text("No recommendations available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                // Recommended stops
                ForEach(recommendedStops) { stop in
                    StopCardView(
                        stop: stop,
                        dataService: dataService,
                        locationService: locationService,
                        favoritesManager: favoritesManager,
                        refreshTrigger: refreshTrigger
                    )
                }
            }
        }
    }
}

// MARK: - Stop Card

struct StopCardView: View {
    let stop: Stop
    let dataService: DataService
    let locationService: LocationService
    let favoritesManager: FavoritesManager?
    let refreshTrigger: UUID

    @State private var arrivals: [Arrival] = []
    @State private var alerts: [AlertResponse] = []
    @State private var isLoadingArrivals = false

    var body: some View {
        NavigationLink(destination: StopDetailView(
            stop: stop,
            dataService: dataService,
            locationService: locationService,
            favoritesManager: favoritesManager
        )) {
            VStack(alignment: .leading, spacing: 8) {
                // Stop header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(stop.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            // Alert indicator
                            if !alerts.isEmpty {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }

                        if let location = locationService.currentLocation {
                            Text(stop.formattedDistance(from: location))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Add/Remove favorite button
                    if let manager = favoritesManager {
                        Button {
                            // Haptic feedback for favorite action
                            WKInterfaceDevice.current().play(.click)

                            if manager.isFavorite(stopId: stop.id) {
                                manager.removeFavorite(stopId: stop.id)
                            } else if manager.favorites.count < manager.maxFavorites {
                                _ = manager.addFavorite(stop: stop)
                            }
                        } label: {
                            Image(systemName: manager.isFavorite(stopId: stop.id) ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundStyle(manager.isFavorite(stopId: stop.id) ? .yellow : .gray)
                        }
                        .buttonStyle(.plain)
                    }

                    // Chevron to indicate it's tappable
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .cornerRadius(12)

                // Alert banner (if any)
                if let firstAlert = alerts.first {
                    AlertBannerView(alert: firstAlert, alertCount: alerts.count)
                }

                // Arrivals preview (2 max)
                VStack(spacing: 8) {
                    if isLoadingArrivals {
                        ProgressView()
                            .padding()
                    } else if arrivals.isEmpty {
                        Text("No departures available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(arrivals.prefix(2)) { arrival in
                            // Use routeColor from API, fallback to searching by lineId
                            let lineColor: Color = {
                                if let hex = arrival.routeColor {
                                    return Color(hex: hex) ?? .blue
                                }
                                return dataService.getLine(by: arrival.lineId)?.color ?? .blue
                            }()
                            ArrivalCard(arrival: arrival, lineColor: lineColor)
                        }

                        // Show "more" indicator if there are more departures
                        if arrivals.count > 2 {
                            Text("Tap for \(arrivals.count - 2) more...")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .buttonStyle(.plain)
        .task(id: refreshTrigger) {
            await loadData()
        }
    }

    private func loadData() async {
        isLoadingArrivals = true
        async let arrivalsTask = dataService.fetchArrivals(for: stop.id)
        async let alertsTask = dataService.fetchAlertsForStop(stopId: stop.id)
        arrivals = await arrivalsTask
        alerts = await alertsTask
        isLoadingArrivals = false
    }
}

// MARK: - Alert Banner View

struct AlertBannerView: View {
    let alert: AlertResponse
    let alertCount: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)

            Text(alertText)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer()

            if alertCount > 1 {
                Text("+\(alertCount - 1)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(8)
    }

    private var alertText: String {
        // Use header if available, otherwise truncate description
        if let header = alert.headerText, !header.isEmpty {
            return header
        }

        let description = alert.descriptionText ?? "Alerta de servicio"
        if description.count > 60 {
            return String(description.prefix(57)) + "..."
        }
        return description
    }
}

#Preview {
    ContentView()
}
