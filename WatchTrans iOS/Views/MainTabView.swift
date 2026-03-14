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

    // Deep Link State
    struct DeepLinkItem: Identifiable {
        let id: String // The stop ID
    }
    @State private var deepLinkItem: DeepLinkItem?

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Inicio
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

            // Tab 2: Mapa
            FullMapView(dataService: dataService, locationService: locationService)
            .tabItem {
                Label("Mapa", systemImage: "map.fill")
            }
            .tag(1)

            // Tab 3: Buscar
            UnifiedSearchView(
                dataService: dataService,
                locationService: locationService,
                favoritesManager: favoritesManager
            )
            .tabItem {
                Label("Buscar", systemImage: "magnifyingglass")
            }
            .tag(2)

            // Tab 4: Lineas
            LinesListView(
                dataService: dataService,
                locationService: locationService,
                favoritesManager: favoritesManager
            )
            .tabItem {
                Label("Líneas", systemImage: "list.bullet")
            }
            .tag(3)

            // Tab 5: Otros
            SettingsView(dataService: dataService)
            .tabItem {
                Label("Otros", systemImage: "ellipsis")
            }
            .tag(4)
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .sheet(item: $deepLinkItem) { item in
            StopLoaderView(
                stopId: item.id,
                dataService: dataService,
                locationService: locationService,
                favoritesManager: favoritesManager
            )
        }
        .task {
            await loadData()
        }
        // ... (Rest of modifiers)
        .onAppear {
            if favoritesManager == nil {
                favoritesManager = FavoritesManager(modelContext: modelContext)
            }
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if isInitialLoadComplete {
                    startAutoRefresh()
                    Task {
                        await checkAndUpdateLocation()
                    }
                }
            case .inactive, .background:
                stopAutoRefresh()
            @unknown default:
                break
            }
        }
        .onChange(of: autoRefreshEnabled) { _, newValue in
            if newValue {
                startAutoRefresh()
            } else {
                stopAutoRefresh()
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        // Schema: watchtrans://stop/{stop_id}
        guard url.scheme == "watchtrans" else { return }
        
        if url.host == "stop" {
            let pathComponents = url.pathComponents
            // pathComponents usually ["/", "STOP_ID"]
            if pathComponents.count > 1 {
                let stopId = pathComponents[1]
                self.deepLinkItem = DeepLinkItem(id: stopId)
            } else if let id = url.query?.replacingOccurrences(of: "id=", with: "") {
                // Fallback for query param style: watchtrans://stop?id=STOP_ID
                self.deepLinkItem = DeepLinkItem(id: id)
            }
        }
    }

    // MARK: - Refresh Logic
    private func startAutoRefresh() {
        stopAutoRefresh()
        guard autoRefreshEnabled && isInitialLoadComplete else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: APIConfiguration.autoRefreshInterval, repeats: true) { _ in
            Task { @MainActor in
                dataService.clearArrivalCache()
                refreshTrigger = UUID()
                await checkAndUpdateLocation()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func checkAndUpdateLocation() async {
        guard !isLoadingData, let currentLocation = locationService.currentLocation else { return }
        let lat = currentLocation.coordinate.latitude
        let lon = currentLocation.coordinate.longitude
        if dataService.currentLocation == nil {
            await dataService.fetchTransportData(latitude: lat, longitude: lon)
            lastKnownProvince = dataService.currentLocation?.provinceName
            return
        }
        let savedLocation = SharedStorage.shared.getLocation()
        if let saved = savedLocation {
            let distance = abs(lat - saved.latitude) + abs(lon - saved.longitude)
            if distance < 0.01 { return }
        }
        await dataService.fetchTransportData(latitude: lat, longitude: lon)
        let newProvince = dataService.currentLocation?.provinceName
        if newProvince != lastKnownProvince {
            lastKnownProvince = newProvince
            SharedStorage.shared.saveLocation(latitude: lat, longitude: lon)
            if let location = dataService.currentLocation {
                let networkName = location.primaryNetworkName ?? location.provinceName
                SharedStorage.shared.saveNucleo(name: networkName, id: 0)
            }
        }
    }

    private func loadData() async {
        guard !isLoadingData else { return }
        isLoadingData = true
        if let savedLocation = SharedStorage.shared.getLocation() {
            await dataService.fetchTransportData(latitude: savedLocation.latitude, longitude: savedLocation.longitude)
            if let location = dataService.currentLocation {
                let networkName = location.primaryNetworkName ?? location.provinceName
                SharedStorage.shared.saveNucleo(name: networkName, id: 0)
            }
        }
        await prefetchArrivalsForHomeView()
        isLoadingData = false
        isInitialLoadComplete = true
        startAutoRefresh()
        Task { await requestAndUpdateLocation() }
        if NetworkMonitor.shared.isConnected {
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await dataService.cacheOfflineSchedulesForFavorites()
            }
        }
    }

    private func prefetchArrivalsForHomeView() async {
        var stopIds = Set<String>()
        if let manager = favoritesManager {
            for favorite in manager.favorites {
                stopIds.insert(favorite.stopId)
            }
        }
        guard !stopIds.isEmpty else { return }
        await withTaskGroup(of: Void.self) { group in
            for stopId in stopIds {
                group.addTask { _ = await self.dataService.fetchArrivals(for: stopId) }
            }
        }
        refreshTrigger = UUID()
    }

    private func requestAndUpdateLocation() async {
        if locationService.authorizationStatus == .notDetermined {
            locationService.requestPermission()
            var authWaitCount = 0
            while locationService.authorizationStatus == .notDetermined && authWaitCount < 10 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                authWaitCount += 1
            }
        }
        guard locationService.authorizationStatus == .authorizedWhenInUse ||
              locationService.authorizationStatus == .authorizedAlways else { return }
        locationService.startUpdating()
        var locationWaitCount = 0
        while locationService.currentLocation == nil && locationWaitCount < 6 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            locationWaitCount += 1
        }
        guard let currentLocation = locationService.currentLocation else { return }
        let lat = currentLocation.coordinate.latitude
        let lon = currentLocation.coordinate.longitude
        SharedStorage.shared.saveLocation(latitude: lat, longitude: lon)
        let savedLocation = SharedStorage.shared.getLocation()
        let distanceFromSaved = (savedLocation != nil) ? abs(lat - savedLocation!.latitude) + abs(lon - savedLocation!.longitude) : 999
        if distanceFromSaved > 0.01 || dataService.stops.isEmpty {
            await dataService.fetchTransportData(latitude: lat, longitude: lon)
            if let location = dataService.currentLocation {
                let networkName = location.primaryNetworkName ?? location.provinceName
                SharedStorage.shared.saveNucleo(name: networkName, id: 0)
                lastKnownProvince = location.provinceName
            }
        }
    }
}

// MARK: - Deep Link Support

struct StopLoaderView: View {
    let stopId: String
    let dataService: DataService
    let locationService: LocationService
    let favoritesManager: FavoritesManager?
    
    @State private var stop: Stop?
    @State private var isLoading = true
    @State private var error: String?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Cargando parada...")
                            .foregroundStyle(.secondary)
                    }
                } else if let stop = stop {
                    StopDetailView(
                        stop: stop,
                        dataService: dataService,
                        locationService: locationService,
                        favoritesManager: favoritesManager
                    )
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error ?? "Parada no encontrada")
                            .font(.headline)
                        Button("Cerrar") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .toolbar {
                // Add close button only if showing detail (StopDetailView might have its own toolbar)
                // But since we are in a sheet, we usually need a top-left close button if not provided
                if stop != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cerrar") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .task {
            await loadStop()
        }
    }
    
    private func loadStop() async {
        // 1. Try from cache
        if let cached = dataService.getStop(by: stopId) {
            stop = cached
            isLoading = false
            return
        }
        
        // 2. Try fetch from API
        if let fetched = await dataService.fetchStopDetails(stopId: stopId) {
            stop = fetched
            isLoading = false
        } else {
            isLoading = false
            error = "No se pudo cargar la parada \(stopId)"
        }
    }
}