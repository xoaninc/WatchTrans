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
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                DebugLog.log("📱 [iOS] App activa - iniciando auto-refresh")
                startAutoRefresh()
                // Check if location changed while in background
                Task {
                    await checkAndUpdateLocation()
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

        // Check if province changed by making a lightweight check
        // The API will return the province based on coordinates
        let currentProvince = dataService.currentLocation?.provinceName

        // Force reload to detect province change
        DebugLog.log("📱 [iOS] checkAndUpdateLocation: Verificando cambio de ubicacion...")
        await dataService.fetchTransportData(latitude: lat, longitude: lon)

        let newProvince = dataService.currentLocation?.provinceName
        if newProvince != currentProvince {
            DebugLog.log("📱 [iOS] ⚠️ PROVINCIA CAMBIO: \(currentProvince ?? "nil") -> \(newProvince ?? "nil")")
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
        DebugLog.log("📱 [iOS] ========== INICIANDO APP ==========")
        DebugLog.log("📱 [iOS] loadData() comenzando...")

        // Request location permission if needed
        DebugLog.log("📱 [iOS] Authorization status: \(locationService.authorizationStatus.rawValue)")
        if locationService.authorizationStatus == .notDetermined {
            DebugLog.log("📱 [iOS] Solicitando permisos de ubicacion...")
            locationService.requestPermission()
        }

        // Wait for authorization (max 10 seconds)
        var authWaitCount = 0
        while locationService.authorizationStatus == CLAuthorizationStatus.notDetermined && authWaitCount < 20 {
            DebugLog.log("📱 [iOS] Esperando autorizacion... (\(authWaitCount))")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            authWaitCount += 1
        }
        DebugLog.log("📱 [iOS] Authorization final: \(locationService.authorizationStatus.rawValue)")

        // Start location updates if authorized
        if locationService.authorizationStatus == CLAuthorizationStatus.authorizedWhenInUse ||
           locationService.authorizationStatus == CLAuthorizationStatus.authorizedAlways {
            DebugLog.log("📱 [iOS] Iniciando actualizacion de ubicacion...")
            locationService.startUpdating()

            // Wait for location (max 5 seconds)
            var locationWaitCount = 0
            while locationService.currentLocation == nil && locationWaitCount < 10 {
                DebugLog.log("📱 [iOS] Esperando ubicacion... (\(locationWaitCount))")
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                locationWaitCount += 1
            }
        } else {
            DebugLog.log("📱 [iOS] ⚠️ Ubicacion no autorizada, continuando sin ubicacion...")
        }

        // Get user's coordinates
        let lat = locationService.currentLocation?.coordinate.latitude
        let lon = locationService.currentLocation?.coordinate.longitude
        DebugLog.log("📱 [iOS] Ubicacion obtenida: lat=\(lat ?? 0), lon=\(lon ?? 0)")

        // Save location for Widget
        if let latitude = lat, let longitude = lon {
            SharedStorage.shared.saveLocation(latitude: latitude, longitude: longitude)
            DebugLog.log("📱 [iOS] Ubicacion guardada en SharedStorage")
        }

        // Fetch transport data based on location
        DebugLog.log("📱 [iOS] Obteniendo datos de transporte...")
        await dataService.fetchTransportData(latitude: lat, longitude: lon)
        DebugLog.log("📱 [iOS] Datos obtenidos: \(dataService.stops.count) paradas, \(dataService.lines.count) lineas")

        // Save network info for Widget
        if let location = dataService.currentLocation {
            let networkName = location.primaryNetworkName ?? location.provinceName
            SharedStorage.shared.saveNucleo(name: networkName, id: 0)
            DebugLog.log("📱 [iOS] Nucleo detectado: \(networkName)")
        }

        // Cache offline schedules for favorites (in background)
        if NetworkMonitor.shared.isConnected {
            Task {
                await dataService.cacheOfflineSchedulesForFavorites()
            }
        }

        DebugLog.log("📱 [iOS] ========== APP LISTA ==========")
    }
}

#Preview {
    MainTabView()
}
