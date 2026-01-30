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
    @State private var showFavoriteAlert = false
    @State private var favoriteAlertMessage = ""

    // Control de carga inicial para evitar duplicados
    @State private var isInitialLoadComplete = false
    @State private var isLoadingData = false

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
            // NO iniciar auto-refresh aquí - se inicia cuando loadData() termina
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // Solo iniciar auto-refresh si la carga inicial ya termino
                if isInitialLoadComplete {
                    startAutoRefresh()
                }
            case .inactive, .background:
                stopAutoRefresh()
            @unknown default:
                break
            }
        }
    }

    // MARK: - Auto Refresh

    private func startAutoRefresh() {
        stopAutoRefresh() // Cancel existing timer

        // NO iniciar si la carga inicial no ha terminado
        guard isInitialLoadComplete else {
            DebugLog.log("⌚ [Watch] ⏳ Auto-refresh pospuesto - carga inicial en progreso")
            return
        }

        DebugLog.log("⌚ [Watch] ✅ Iniciando timer de auto-refresh")
        refreshTimer = Timer.scheduledTimer(withTimeInterval: APIConfiguration.autoRefreshInterval, repeats: true) { _ in
            Task { @MainActor in
                // Check if nucleo changed
                await checkAndUpdateNucleo()

                dataService.clearArrivalCache()
                refreshTrigger = UUID()  // Trigger UI refresh
            }
        }
    }

    /// Check if location changed (different province) and reload data if needed
    private func checkAndUpdateNucleo() async {
        // No ejecutar si la carga inicial esta en progreso
        guard !isLoadingData else {
            DebugLog.log("⌚ [Watch] checkAndUpdateNucleo: ⏳ Saltando - carga inicial en progreso")
            return
        }

        guard let currentLocation = locationService.currentLocation else {
            DebugLog.log("⌚ [Watch] checkAndUpdateNucleo: No hay ubicacion actual")
            return
        }

        let lat = currentLocation.coordinate.latitude
        let lon = currentLocation.coordinate.longitude

        // If we don't have data yet, load it
        if dataService.currentLocation == nil {
            DebugLog.log("⌚ [Watch] checkAndUpdateNucleo: No hay datos, cargando...")
            await loadData()
            return
        }

        // Solo recargar si la ubicacion cambio significativamente
        let savedLocation = SharedStorage.shared.getLocation()
        if let saved = savedLocation {
            let distance = abs(lat - saved.latitude) + abs(lon - saved.longitude)
            if distance < 0.01 {
                // Ubicacion similar - no recargar datos de transporte
                DebugLog.log("⌚ [Watch] checkAndUpdateNucleo: Ubicacion similar, omitiendo recarga")
                return
            }
        }

        // Ubicacion cambio significativamente - recargar
        let currentProvince = dataService.currentLocation?.provinceName
        DebugLog.log("⌚ [Watch] checkAndUpdateNucleo: 🔄 Ubicacion cambio, recargando...")
        await dataService.fetchTransportData(latitude: lat, longitude: lon)

        let newProvince = dataService.currentLocation?.provinceName
        if newProvince != currentProvince {
            DebugLog.log("⌚ [Watch] ⚠️ PROVINCIA CAMBIO: \(currentProvince ?? "nil") -> \(newProvince ?? "nil")")

            // Save new location for Widget
            SharedStorage.shared.saveLocation(latitude: lat, longitude: lon)
            if let location = dataService.currentLocation {
                let networkName = location.primaryNetworkName ?? location.provinceName
                SharedStorage.shared.saveNucleo(name: networkName, id: 0)
            }

            // Trigger UI refresh
            refreshTrigger = UUID()
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func loadData() async {
        // Evitar carga duplicada
        guard !isLoadingData else {
            DebugLog.log("⌚ [Watch] ⚠️ loadData() ya en progreso - ignorando")
            return
        }
        isLoadingData = true

        DebugLog.log("⌚ [Watch] ========== LOAD DATA ==========")

        // FASE 1: CARGA INSTANTANEA - Usar ubicacion guardada si existe
        if let savedLocation = SharedStorage.shared.getLocation() {
            DebugLog.log("⌚ [Watch] ✅ Ubicacion guardada: (\(savedLocation.latitude), \(savedLocation.longitude))")
            await dataService.fetchTransportData(latitude: savedLocation.latitude, longitude: savedLocation.longitude)
            DebugLog.log("⌚ [Watch] ✅ Datos cargados: \(dataService.stops.count) paradas")

            if let location = dataService.currentLocation {
                let networkName = location.primaryNetworkName ?? location.provinceName
                SharedStorage.shared.saveNucleo(name: networkName, id: 0)
            }
        }

        // Marcar carga inicial como completa ANTES de iniciar tareas en background
        isLoadingData = false
        isInitialLoadComplete = true
        DebugLog.log("⌚ [Watch] ========== CARGA INICIAL COMPLETA ==========")

        // Ahora que la carga inicial termino, iniciar auto-refresh
        startAutoRefresh()

        // FASE 2: En background - Obtener ubicacion GPS y actualizar si es diferente
        Task {
            if locationService.authorizationStatus == .notDetermined {
                DebugLog.log("⌚ [Watch] Requesting location permission...")
                locationService.requestPermission()
            }

            locationService.startUpdating()
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            let lat = locationService.currentLocation?.coordinate.latitude
            let lon = locationService.currentLocation?.coordinate.longitude

            guard let latitude = lat, let longitude = lon else {
                DebugLog.log("⌚ [Watch] ⚠️ No GPS location available")
                return
            }

            DebugLog.log("⌚ [Watch] GPS Location: (\(latitude), \(longitude))")
            SharedStorage.shared.saveLocation(latitude: latitude, longitude: longitude)

            // Solo recargar si no hay datos o ubicacion cambio significativamente
            let needsReload = dataService.stops.isEmpty || {
                if let saved = SharedStorage.shared.getLocation() {
                    let dist = abs(latitude - saved.latitude) + abs(longitude - saved.longitude)
                    return dist > 0.01 // ~1km
                }
                return true
            }()

            if needsReload {
                DebugLog.log("⌚ [Watch] 🔄 Recargando datos con GPS...")
                await dataService.fetchTransportData(latitude: latitude, longitude: longitude)
            }

            // Save network info for Widget
            if let location = dataService.currentLocation {
                let networkName = location.primaryNetworkName ?? location.provinceName
                DebugLog.log("⌚ [Watch] Saving network: \(networkName)")
                SharedStorage.shared.saveNucleo(name: networkName, id: 0)
            }
        }

        DebugLog.log("⌚ [Watch] ========== LOAD COMPLETE ==========")
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

    /// Extract network type from stop ID (e.g., "RENFE_18000" -> "RENFE", "METRO_123" -> "METRO")
    private func networkType(for stop: Stop) -> String {
        if let underscore = stop.id.firstIndex(of: "_") {
            return String(stop.id.prefix(upTo: underscore))
        }
        return "OTHER"
    }

    /// Create unique key for deduplication: name + network type
    private func deduplicationKey(for stop: Stop) -> String {
        return "\(stop.name)_\(networkType(for: stop))"
    }

    // Stops are already filtered by coordinates from the API
    // They come from the user's province/nucleo automatically
    var recommendedStops: [Stop] {
        var stops: [Stop] = []
        var seenKeys: Set<String> = []  // Deduplicate by name + network type
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

        // Add stops, skipping duplicates by name+network and favorites
        for stop in sortedByDistance {
            let key = deduplicationKey(for: stop)
            // Skip if already have a stop with this name+network (different platform)
            if seenKeys.contains(key) {
                continue
            }
            // Skip favorites
            if favoriteIds.contains(stop.id) {
                continue
            }

            stops.append(stop)
            seenKeys.insert(key)

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
    @State private var hasLoadedOnce = false
    @State private var showFavoriteAlert = false
    @State private var favoriteAlertMessage = ""

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
                            } else {
                                let result = manager.addFavorite(stop: stop)
                                switch result {
                                case .success:
                                    break
                                case .limitReached:
                                    favoriteAlertMessage = "Limite de \(manager.maxFavorites) favoritos"
                                    showFavoriteAlert = true
                                case .alreadyExists:
                                    break
                                case .saveFailed:
                                    favoriteAlertMessage = "Error al guardar"
                                    showFavoriteAlert = true
                                }
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
        .alert("Favoritos", isPresented: $showFavoriteAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(favoriteAlertMessage)
        }
    }

    private func loadData() async {
        // CACHE-FIRST: Mostrar datos en cache inmediatamente
        if let cached = dataService.getStaleCachedArrivals(for: stop.id), !cached.isEmpty {
            arrivals = cached
            hasLoadedOnce = true
        } else if !hasLoadedOnce {
            isLoadingArrivals = true
        }

        // Actualizar con datos frescos en paralelo
        async let arrivalsTask = dataService.fetchArrivals(for: stop.id)
        async let alertsTask = dataService.fetchAlertsForStop(stopId: stop.id)
        arrivals = await arrivalsTask
        alerts = await alertsTask
        hasLoadedOnce = true
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
