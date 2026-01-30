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
                locationService: locationService
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
        DebugLog.log("📱 [iOS] loadData() comenzando...")

        // FASE 1: CARGA INSTANTANEA - Usar ubicacion guardada si existe
        if let savedLocation = SharedStorage.shared.getLocation() {
            DebugLog.log("📱 [iOS] ✅ Ubicacion guardada encontrada: (\(savedLocation.latitude), \(savedLocation.longitude))")
            DebugLog.log("📱 [iOS] Cargando datos con ubicacion guardada (instantaneo)...")
            await dataService.fetchTransportData(latitude: savedLocation.latitude, longitude: savedLocation.longitude)
            DebugLog.log("📱 [iOS] ✅ Datos cargados: \(dataService.stops.count) paradas, \(dataService.lines.count) lineas")

            // Save network info for Widget
            if let location = dataService.currentLocation {
                let networkName = location.primaryNetworkName ?? location.provinceName
                SharedStorage.shared.saveNucleo(name: networkName, id: 0)
                DebugLog.log("📱 [iOS] Nucleo detectado: \(networkName)")
            }
        } else {
            DebugLog.log("📱 [iOS] ⚠️ No hay ubicacion guardada - esperando GPS...")
        }

        // FASE 3.1: Prefetch arrivals de favoritos en paralelo (antes de mostrar UI)
        if let manager = favoritesManager, !manager.favorites.isEmpty {
            let favoriteIds = manager.favorites.map { $0.stopId }
            DebugLog.log("📱 [iOS] 🚀 Prefetching arrivals para \(favoriteIds.count) favoritos...")
            await withTaskGroup(of: Void.self) { group in
                for stopId in favoriteIds {
                    group.addTask {
                        _ = await dataService.fetchArrivals(for: stopId)
                    }
                }
            }
            DebugLog.log("📱 [iOS] ✅ Prefetch de favoritos completado")
        }

        // Marcar carga inicial como completa ANTES de iniciar tareas en background
        isLoadingData = false
        isInitialLoadComplete = true
        DebugLog.log("📱 [iOS] ========== CARGA INICIAL COMPLETA ==========")

        // Ahora que la carga inicial termino, iniciar auto-refresh
        startAutoRefresh()

        // FASE 2: EN PARALELO - Obtener ubicacion actual y actualizar si es diferente
        Task {
            await requestAndUpdateLocation()
        }

        // Cache offline schedules for favorites (diferido 5 segundos para no competir)
        if NetworkMonitor.shared.isConnected {
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 segundos
                DebugLog.log("📱 [iOS] 🔄 Iniciando cache de lineas offline...")
                await dataService.cacheOfflineSchedulesForFavorites()
            }
        }

        DebugLog.log("📱 [iOS] ========== APP LISTA ==========")
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
