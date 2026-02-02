//
//  MainTabView.swift
//  WatchTrans iOS
//
//  Created by Juan Macias Gomez on 21/1/26.
//

import SwiftUI
import SwiftData
import CoreLocation

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    // User preferences
    @AppStorage("autoRefreshEnabled") private var autoRefreshEnabled = true

    @State private var locationService = LocationService()
    @State private var dataService = DataService()
    @State private var favoritesManager: FavoritesManager?
    @State private var refreshTimer: Timer?
    @State private var lastKnownProvince: String?
    @State private var refreshTrigger = UUID()

    // Control de carga inicial para evitar duplicados
    @State private var isInitialLoadComplete = false
    @State private var isLoadingData = false

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Home (Favoritos + Cercanas)
            HomeView(
                dataService: dataService,
                locationService: locationService,
                favoritesManager: favoritesManager,
                refreshTrigger: refreshTrigger
            )
            .tabItem {
                Label("Inicio", systemImage: "house.fill")
            }
            .tag(0)

            // Tab 2: Search
            SearchView(
                dataService: dataService,
                locationService: locationService,
                favoritesManager: favoritesManager
            )
            .tabItem {
                Label("Buscar", systemImage: "magnifyingglass")
            }
            .tag(1)

            // Tab 3: Lines
            LinesListView(
                dataService: dataService,
                locationService: locationService,
                favoritesManager: favoritesManager
            )
            .tabItem {
                Label("Lineas", systemImage: "list.bullet")
            }
            .tag(2)

            // Tab 4: Journey Planner
            JourneyPlannerView(
                dataService: dataService,
                locationService: locationService
            )
            .tabItem {
                Label("Planificar", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
            }
            .tag(3)

            // Tab 5: Settings/More
            SettingsView(dataService: dataService)
            .tabItem {
                Label("Otros", systemImage: "ellipsis")
            }
            .tag(4)
        }
        .task {
            await loadData()
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
                DebugLog.log("📱 [iOS] App activa")
                // Solo iniciar auto-refresh si la carga inicial ya termino
                if isInitialLoadComplete {
                    DebugLog.log("📱 [iOS] Iniciando auto-refresh (carga inicial completa)")
                    startAutoRefresh()
                    // Check if location changed while in background
                    Task {
                        await checkAndUpdateLocation()
                    }
                } else {
                    DebugLog.log("📱 [iOS] ⏳ Esperando carga inicial antes de auto-refresh")
                }
            case .inactive, .background:
                DebugLog.log("📱 [iOS] App en background - deteniendo auto-refresh")
                stopAutoRefresh()
            @unknown default:
                break
            }
        }
        .onChange(of: autoRefreshEnabled) { _, newValue in
            if newValue {
                DebugLog.log("📱 [iOS] Auto-refresh activado")
                startAutoRefresh()
            } else {
                DebugLog.log("📱 [iOS] Auto-refresh desactivado")
                stopAutoRefresh()
            }
        }
    }

    // MARK: - Auto Refresh

    private func startAutoRefresh() {
        stopAutoRefresh() // Cancel existing timer

        // Only start if auto-refresh is enabled in settings
        guard autoRefreshEnabled else {
            DebugLog.log("📱 [iOS] Auto-refresh desactivado en ajustes")
            return
        }

        // NO iniciar si la carga inicial no ha terminado
        guard isInitialLoadComplete else {
            DebugLog.log("📱 [iOS] ⏳ Auto-refresh pospuesto - carga inicial en progreso")
            return
        }

        DebugLog.log("📱 [iOS] ✅ Iniciando timer de auto-refresh")
        refreshTimer = Timer.scheduledTimer(withTimeInterval: APIConfiguration.autoRefreshInterval, repeats: true) { _ in
            Task { @MainActor in
                // Clear arrival cache to force fresh data
                dataService.clearArrivalCache()
                // Trigger UI refresh for arrivals
                refreshTrigger = UUID()
                await checkAndUpdateLocation()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    /// Check if location changed (different province) and reload data if needed
    private func checkAndUpdateLocation() async {
        // No ejecutar si la carga inicial esta en progreso
        guard !isLoadingData else {
            DebugLog.log("📱 [iOS] checkAndUpdateLocation: ⏳ Saltando - carga inicial en progreso")
            return
        }

        guard let currentLocation = locationService.currentLocation else {
            DebugLog.log("📱 [iOS] checkAndUpdateLocation: No hay ubicacion actual")
            return
        }

        let lat = currentLocation.coordinate.latitude
        let lon = currentLocation.coordinate.longitude

        // If we don't have data yet, load it
        if dataService.currentLocation == nil {
            DebugLog.log("📱 [iOS] checkAndUpdateLocation: No hay datos, cargando...")
            await dataService.fetchTransportData(latitude: lat, longitude: lon)
            lastKnownProvince = dataService.currentLocation?.provinceName
            return
        }

        // Solo recargar si la ubicacion cambio significativamente
        // No hacer reload completo en cada refresh - solo limpiar cache de arrivals
        let savedLocation = SharedStorage.shared.getLocation()
        if let saved = savedLocation {
            let distance = abs(lat - saved.latitude) + abs(lon - saved.longitude)
            if distance < 0.01 {
                // Ubicacion similar - no recargar datos de transporte
                DebugLog.log("📱 [iOS] checkAndUpdateLocation: Ubicacion similar, omitiendo recarga")
                return
            }
        }

        // Ubicacion cambio significativamente - recargar
        DebugLog.log("📱 [iOS] checkAndUpdateLocation: 🔄 Ubicacion cambio, recargando...")
        await dataService.fetchTransportData(latitude: lat, longitude: lon)

        let newProvince = dataService.currentLocation?.provinceName
        if newProvince != lastKnownProvince {
            DebugLog.log("📱 [iOS] ⚠️ PROVINCIA CAMBIO: \(lastKnownProvince ?? "nil") -> \(newProvince ?? "nil")")
            lastKnownProvince = newProvince

            // Save new location for Widget
            SharedStorage.shared.saveLocation(latitude: lat, longitude: lon)
            if let location = dataService.currentLocation {
                let networkName = location.primaryNetworkName ?? location.provinceName
                SharedStorage.shared.saveNucleo(name: networkName, id: 0)
            }
        }
    }

    private func loadData() async {
        // Evitar carga duplicada
        guard !isLoadingData else {
            DebugLog.log("📱 [iOS] ⚠️ loadData() ya en progreso - ignorando")
            return
        }
        isLoadingData = true

        DebugLog.log("📱 [iOS] ========== INICIANDO APP ==========")

        // FASE 1: CARGA RAPIDA - Stops desde cache o API
        if let savedLocation = SharedStorage.shared.getLocation() {
            DebugLog.log("📱 [iOS] ✅ Ubicacion guardada: (\(savedLocation.latitude), \(savedLocation.longitude))")
            await dataService.fetchTransportData(latitude: savedLocation.latitude, longitude: savedLocation.longitude)
            DebugLog.log("📱 [iOS] ✅ Stops cargados: \(dataService.stops.count)")

            // Save network info for Widget
            if let location = dataService.currentLocation {
                let networkName = location.primaryNetworkName ?? location.provinceName
                SharedStorage.shared.saveNucleo(name: networkName, id: 0)
            }
        } else {
            DebugLog.log("📱 [iOS] ⚠️ No hay ubicacion guardada - esperando GPS...")
        }

        // FASE 2: PREFETCH ARRIVALS (paralelo, pero esperamos resultado)
        // Esto llena el cache antes de mostrar la UI
        await prefetchArrivalsForHomeView()

        // FASE 3: MOSTRAR UI
        isLoadingData = false
        isInitialLoadComplete = true
        DebugLog.log("📱 [iOS] ========== UI LISTA ==========")
        startAutoRefresh()

        // FASE 4: BACKGROUND - Verificar ubicacion GPS
        Task {
            await requestAndUpdateLocation()
        }

        // FASE 5: BACKGROUND (diferido) - Cache offline
        if NetworkMonitor.shared.isConnected {
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 segundos
                await dataService.cacheOfflineSchedulesForFavorites()
            }
        }

        DebugLog.log("📱 [iOS] ========== BACKGROUND TASKS INICIADAS ==========")
    }

    /// Prefetch arrivals for favorites, frequent stops, and nearby stops (runs in background)
    private func prefetchArrivalsForHomeView() async {
        var stopIds = Set<String>()

        // Add favorite stops
        if let manager = favoritesManager {
            for favorite in manager.favorites {
                stopIds.insert(favorite.stopId)
            }
        }

        // Add frequent stops (top 5)
        let frequentStops = FrequentStopsService.shared.getSuggestedStops().prefix(5)
        for frequent in frequentStops {
            stopIds.insert(frequent.id)
        }

        // Add nearby stops (top 5) - sorted by distance
        let nearbyStops: [Stop]
        if let location = locationService.currentLocation {
            nearbyStops = dataService.stops
                .sorted { $0.distance(from: location) < $1.distance(from: location) }
                .filter { stop in !stopIds.contains(stop.id) }  // Exclude already added
                .prefix(5)
                .map { $0 }
        } else {
            // No location - just take first 5 stops
            nearbyStops = Array(dataService.stops.prefix(5))
        }
        for stop in nearbyStops {
            stopIds.insert(stop.id)
        }

        guard !stopIds.isEmpty else { return }

        DebugLog.log("📱 [iOS] 🚀 Prefetching arrivals para \(stopIds.count) paradas (favoritos + frecuentes + cercanas)...")

        await withTaskGroup(of: Void.self) { group in
            for stopId in stopIds {
                group.addTask {
                    _ = await self.dataService.fetchArrivals(for: stopId)
                }
            }
        }

        // Trigger UI refresh
        refreshTrigger = UUID()
        DebugLog.log("📱 [iOS] ✅ Prefetch completado")
    }

    /// Request location permission and update data if location changed
    private func requestAndUpdateLocation() async {
        // Request location permission if needed
        DebugLog.log("📱 [iOS] Authorization status: \(locationService.authorizationStatus.rawValue)")
        if locationService.authorizationStatus == .notDetermined {
            DebugLog.log("📱 [iOS] Solicitando permisos de ubicacion...")
            locationService.requestPermission()

            // Wait for authorization (max 5 seconds - reduced from 10)
            var authWaitCount = 0
            while locationService.authorizationStatus == CLAuthorizationStatus.notDetermined && authWaitCount < 10 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                authWaitCount += 1
            }
        }

        // Start location updates if authorized
        guard locationService.authorizationStatus == CLAuthorizationStatus.authorizedWhenInUse ||
              locationService.authorizationStatus == CLAuthorizationStatus.authorizedAlways else {
            DebugLog.log("📱 [iOS] ⚠️ Ubicacion no autorizada")
            return
        }

        DebugLog.log("📱 [iOS] Iniciando actualizacion de ubicacion...")
        locationService.startUpdating()

        // Wait for location (max 3 seconds - reduced from 5)
        var locationWaitCount = 0
        while locationService.currentLocation == nil && locationWaitCount < 6 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            locationWaitCount += 1
        }

        guard let currentLocation = locationService.currentLocation else {
            DebugLog.log("📱 [iOS] ⚠️ No se pudo obtener ubicacion GPS")
            return
        }

        let lat = currentLocation.coordinate.latitude
        let lon = currentLocation.coordinate.longitude
        DebugLog.log("📱 [iOS] Ubicacion GPS obtenida: (\(lat), \(lon))")

        // Save new location
        SharedStorage.shared.saveLocation(latitude: lat, longitude: lon)

        // Check if we need to reload (different province or no data yet)
        let savedLocation = SharedStorage.shared.getLocation()
        let distanceFromSaved: Double
        if let saved = savedLocation {
            // Calculate rough distance (degrees)
            distanceFromSaved = abs(lat - saved.latitude) + abs(lon - saved.longitude)
        } else {
            distanceFromSaved = 999 // Force reload
        }

        // Reload if moved significantly (> 0.01 degrees ~ 1km) or no data
        if distanceFromSaved > 0.01 || dataService.stops.isEmpty {
            DebugLog.log("📱 [iOS] 🔄 Ubicacion cambio significativamente, recargando datos...")
            await dataService.fetchTransportData(latitude: lat, longitude: lon)

            if let location = dataService.currentLocation {
                let networkName = location.primaryNetworkName ?? location.provinceName
                SharedStorage.shared.saveNucleo(name: networkName, id: 0)
                lastKnownProvince = location.provinceName
            }
        } else {
            DebugLog.log("📱 [iOS] ✅ Ubicacion similar, no es necesario recargar")
        }
    }
}

#Preview {
    MainTabView()
}
