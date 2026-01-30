//
//  HomeView.swift
//  WatchTrans iOS
//
//  Created by Juan Macias Gomez on 21/1/26.
//

import SwiftUI
import UIKit
import CoreLocation

struct HomeView: View {
    let dataService: DataService
    let locationService: LocationService
    let favoritesManager: FavoritesManager?
    let refreshTrigger: UUID

    @State private var localRefreshTrigger = UUID()
    @State private var isRefreshing = false
    @State private var showFavoriteAlert = false
    @State private var favoriteAlertMessage = ""

    // Network monitoring
    private var networkMonitor = NetworkMonitor.shared

    init(dataService: DataService, locationService: LocationService, favoritesManager: FavoritesManager?, refreshTrigger: UUID) {
        self.dataService = dataService
        self.locationService = locationService
        self.favoritesManager = favoritesManager
        self.refreshTrigger = refreshTrigger
    }

    // Effective trigger: changes when either parent (auto-refresh) or local (pull-to-refresh) changes
    private var effectiveTrigger: UUID {
        // Take first half from parent, second half from local
        let p = refreshTrigger.uuid
        let l = localRefreshTrigger.uuid
        return UUID(uuid: (p.0, p.1, p.2, p.3, p.4, p.5, p.6, p.7, l.8, l.9, l.10, l.11, l.12, l.13, l.14, l.15))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Offline banner
                    if !networkMonitor.isConnected {
                        OfflineBannerView()
                    }

                    // Location header
                    if let location = dataService.currentLocation {
                        LocationHeaderView(location: location)
                    }

                    // Favorites Section
                    if let manager = favoritesManager, !manager.favorites.isEmpty {
                        FavoritesSectionView(
                            favoritesManager: manager,
                            dataService: dataService,
                            locationService: locationService,
                            refreshTrigger: effectiveTrigger
                        )
                    }

                    // Frequent Stops Section (auto-detected)
                    FrequentStopsSectionView(
                        dataService: dataService,
                        locationService: locationService,
                        favoritesManager: favoritesManager,
                        refreshTrigger: effectiveTrigger
                    )

                    // Nearby Stops Section
                    NearbyStopsSectionView(
                        dataService: dataService,
                        locationService: locationService,
                        favoritesManager: favoritesManager,
                        refreshTrigger: effectiveTrigger
                    )
                }
                .padding()
            }
            .navigationTitle("WatchTrans")
            .refreshable {
                await refreshData()
            }
            .alert("Favoritos", isPresented: $showFavoriteAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(favoriteAlertMessage)
            }
        }
    }

    // MARK: - Pull to Refresh

    /// Refresh data from server
    private func refreshData() async {
        // Clear cache to force fresh data
        dataService.clearArrivalCache()

        // Fetch new data from server
        if let location = locationService.currentLocation {
            await dataService.fetchTransportData(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        }

        // Trigger UI update
        localRefreshTrigger = UUID()
    }
}

// MARK: - Location Header

struct LocationHeaderView: View {
    let location: LocationContext

    var body: some View {
        HStack {
            Image(systemName: "location.fill")
                .foregroundStyle(.blue)
            Text(location.displayName)
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Offline Banner

struct OfflineBannerView: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.orange)
            Text("Sin conexion - Modo offline")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Favorites Section

struct FavoritesSectionView: View {
    let favoritesManager: FavoritesManager
    let dataService: DataService
    let locationService: LocationService
    let refreshTrigger: UUID

    var favoriteStops: [Stop] {
        favoritesManager.getFavoriteStops(from: dataService.stops)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("Favoritos")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text("\(favoriteStops.count)/\(favoritesManager.maxFavorites)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if favoriteStops.isEmpty {
                Text("No tienes favoritos. Toca la estrella en una parada para agregarla.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(favoriteStops) { stop in
                    NavigationLink(destination: StopDetailView(
                        stop: stop,
                        dataService: dataService,
                        locationService: locationService,
                        favoritesManager: favoritesManager
                    )) {
                        StopCardView(
                            stop: stop,
                            dataService: dataService,
                            locationService: locationService,
                            favoritesManager: favoritesManager,
                            refreshTrigger: refreshTrigger
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Frequent Stops Section

struct FrequentStopsSectionView: View {
    let dataService: DataService
    let locationService: LocationService
    let favoritesManager: FavoritesManager?
    let refreshTrigger: UUID

    @ObservedObject private var frequentStopsService = FrequentStopsService.shared

    /// Get Stop objects for frequent stop IDs
    private var frequentStops: [(stop: Stop, pattern: String?)] {
        let favoriteIds = Set(favoritesManager?.favorites.map { $0.stopId } ?? [])
        let suggested = frequentStopsService.getSuggestedStops()

        return suggested.compactMap { frequent in
            // Skip if already a favorite
            guard !favoriteIds.contains(frequent.id) else { return nil }
            // Find the stop in dataService
            guard let stop = dataService.stops.first(where: { $0.id == frequent.id }) else { return nil }
            return (stop, frequent.patternDescription)
        }
    }

    var body: some View {
        if !frequentStops.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Section header
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.purple)
                    Text("Frecuentes")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Text("Auto")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(4)
                }

                ForEach(frequentStops, id: \.stop.id) { item in
                    NavigationLink(destination: StopDetailView(
                        stop: item.stop,
                        dataService: dataService,
                        locationService: locationService,
                        favoritesManager: favoritesManager
                    )) {
                        FrequentStopCardView(
                            stop: item.stop,
                            pattern: item.pattern,
                            dataService: dataService,
                            locationService: locationService,
                            favoritesManager: favoritesManager,
                            refreshTrigger: refreshTrigger
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Frequent Stop Card View

struct FrequentStopCardView: View {
    let stop: Stop
    let pattern: String?
    let dataService: DataService
    let locationService: LocationService
    let favoritesManager: FavoritesManager?
    let refreshTrigger: UUID

    @State private var arrivals: [Arrival] = []
    @State private var isLoading = false
    @State private var hasLoadedOnce = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stop header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        LogoImageView(
                            type: stop.transportType,
                            nucleo: dataService.currentLocation?.provinceName ?? "Madrid",
                            height: 18
                        )
                        Text(stop.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }

                    HStack(spacing: 8) {
                        if let location = locationService.currentLocation {
                            Text(stop.formattedDistance(from: location))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Pattern badge (e.g., "~08:00 L-V")
                        if let pattern = pattern {
                            Text(pattern)
                                .font(.caption2)
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }

            // Arrivals preview
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if arrivals.isEmpty {
                Text("Sin salidas proximas")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(arrivals.prefix(2)) { arrival in
                        ArrivalRowView(arrival: arrival, dataService: dataService)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
        .task(id: refreshTrigger) {
            await loadArrivals()
        }
    }

    private func loadArrivals() async {
        // CACHE-FIRST: Mostrar datos en cache inmediatamente
        if let cached = dataService.getStaleCachedArrivals(for: stop.id), !cached.isEmpty {
            arrivals = cached
            hasLoadedOnce = true
        } else if !hasLoadedOnce {
            isLoading = true
        }

        // Actualizar con datos frescos
        let fresh = await dataService.fetchArrivals(for: stop.id)
        arrivals = fresh
        hasLoadedOnce = true
        isLoading = false
    }
}

// MARK: - Nearby Stops Section

struct NearbyStopsSectionView: View {
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

    /// Check if stop matches any of the enabled transport types
    private func stopMatchesEnabledTypes(_ stop: Stop, enabledTypes: Set<TransportType>) -> Bool {
        // No filter = show all
        if enabledTypes.isEmpty { return true }

        let network = networkType(for: stop).uppercased()

        for type in enabledTypes {
            switch type {
            case .metro:
                if network == "METRO" || (stop.corMetro != nil && !stop.corMetro!.isEmpty) {
                    return true
                }
            case .metroLigero:
                if network == "ML" || (stop.corMl != nil && !stop.corMl!.isEmpty) {
                    return true
                }
            case .cercanias:
                if network == "RENFE" || (stop.corCercanias != nil && !stop.corCercanias!.isEmpty) {
                    return true
                }
            case .tram:
                if network == "TRAM" || (stop.corTranvia != nil && !stop.corTranvia!.isEmpty) {
                    return true
                }
            case .fgc:
                if network == "FGC" {
                    return true
                }
            }
        }
        return false
    }

    var nearbyStops: [Stop] {
        var stops: [Stop] = []
        var seenKeys: Set<String> = []  // Deduplicate by name + network type
        let favoriteIds = favoritesManager?.favorites.map { $0.stopId } ?? []
        let enabledTypes = DataService.getEnabledTransportTypes()

        // Sort by distance
        let sortedByDistance: [Stop]
        if let location = locationService.currentLocation {
            sortedByDistance = dataService.stops.sorted {
                $0.distance(from: location) < $1.distance(from: location)
            }
        } else {
            sortedByDistance = dataService.stops
        }

        // Filter and deduplicate by name + network type
        for stop in sortedByDistance {
            let key = deduplicationKey(for: stop)
            if seenKeys.contains(key) { continue }
            if favoriteIds.contains(stop.id) { continue }
            // Apply transport type filter
            if !stopMatchesEnabledTypes(stop, enabledTypes: enabledTypes) { continue }

            stops.append(stop)
            seenKeys.insert(key)

            if stops.count >= 5 { break }
        }

        return stops
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: "location.circle.fill")
                    .foregroundStyle(.blue)
                Text("Cercanas")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            if nearbyStops.isEmpty {
                if dataService.isLoading {
                    ProgressView("Cargando paradas cercanas...")
                        .padding()
                } else {
                    Text("No hay paradas cercanas disponibles.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            } else {
                ForEach(nearbyStops) { stop in
                    NavigationLink(destination: StopDetailView(
                        stop: stop,
                        dataService: dataService,
                        locationService: locationService,
                        favoritesManager: favoritesManager
                    )) {
                        StopCardView(
                            stop: stop,
                            dataService: dataService,
                            locationService: locationService,
                            favoritesManager: favoritesManager,
                            refreshTrigger: refreshTrigger
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Stop Card View

struct StopCardView: View {
    let stop: Stop
    let dataService: DataService
    let locationService: LocationService
    let favoritesManager: FavoritesManager?
    let refreshTrigger: UUID

    @State private var arrivals: [Arrival] = []
    @State private var isLoading = false
    @State private var hasLoadedOnce = false
    @State private var showFavoriteAlert = false
    @State private var favoriteAlertMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stop header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        LogoImageView(
                            type: stop.transportType,
                            nucleo: dataService.currentLocation?.provinceName ?? "Madrid",
                            height: 18
                        )
                        Text(stop.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }

                    if let location = locationService.currentLocation {
                        Text(stop.formattedDistance(from: location))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

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
                                break
                            case .limitReached:
                                favoriteAlertMessage = "Has alcanzado el limite de \(manager.maxFavorites) favoritos"
                                showFavoriteAlert = true
                            case .alreadyExists:
                                break
                            case .saveFailed(let error):
                                favoriteAlertMessage = "Error al guardar: \(error.localizedDescription)"
                                showFavoriteAlert = true
                            }
                        }
                    } label: {
                        Image(systemName: manager.isFavorite(stopId: stop.id) ? "star.fill" : "star")
                            .foregroundStyle(manager.isFavorite(stopId: stop.id) ? .yellow : .gray)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }

            // Arrivals preview
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if arrivals.isEmpty {
                Text("Sin salidas proximas")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(arrivals.prefix(3)) { arrival in
                        let lineColor: Color = {
                            if let hex = arrival.routeColor {
                                return Color(hex: hex) ?? .blue
                            }
                            return dataService.getLine(by: arrival.lineId)?.color ?? .blue
                        }()

                        NavigationLink(destination: TrainDetailView(arrival: arrival, lineColor: lineColor, dataService: dataService)) {
                            ArrivalRowView(arrival: arrival, dataService: dataService)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .task(id: refreshTrigger) {
            await loadArrivals()
        }
        .alert("Favoritos", isPresented: $showFavoriteAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(favoriteAlertMessage)
        }
    }

    private func loadArrivals() async {
        DebugLog.log("📱 [StopCard] Cargando llegadas para: \(stop.name) (id: \(stop.id))")

        // CACHE-FIRST: Mostrar datos en cache inmediatamente (si existen)
        if let cached = dataService.getStaleCachedArrivals(for: stop.id), !cached.isEmpty {
            arrivals = cached
            hasLoadedOnce = true
            DebugLog.log("📱 [StopCard] \(stop.name): Mostrando \(cached.count) llegadas en cache")
            // No mostrar spinner - ya tenemos datos
        } else if !hasLoadedOnce {
            isLoading = true
        }

        // Actualizar con datos frescos en background
        let fresh = await dataService.fetchArrivals(for: stop.id)
        arrivals = fresh
        DebugLog.log("📱 [StopCard] \(stop.name): \(fresh.count) llegadas frescas")
        hasLoadedOnce = true
        isLoading = false
    }
}

#Preview {
    HomeView(
        dataService: DataService(),
        locationService: LocationService(),
        favoritesManager: nil,
        refreshTrigger: UUID()
    )
}
