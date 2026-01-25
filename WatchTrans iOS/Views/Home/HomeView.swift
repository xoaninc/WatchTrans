//
//  HomeView.swift
//  WatchTrans iOS
//
//  Created by Juan Macias Gomez on 21/1/26.
//

import SwiftUI
import UIKit

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
                VStack(spacing: 20) {
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
                dataService.clearArrivalCache()
                localRefreshTrigger = UUID()
            }
            .alert("Favoritos", isPresented: $showFavoriteAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(favoriteAlertMessage)
            }
        }
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
            Text("Sin conexion - Mostrando datos en cache")
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

    var nearbyStops: [Stop] {
        var stops: [Stop] = []
        var seenKeys: Set<String> = []  // Deduplicate by name + network type
        let favoriteIds = favoritesManager?.favorites.map { $0.stopId } ?? []

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
                    Text(stop.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

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
        print("📱 [StopCard] Cargando llegadas para: \(stop.name) (id: \(stop.id))")
        // Solo mostrar spinner en la primera carga, no en auto-refresh
        if !hasLoadedOnce {
            isLoading = true
        }
        arrivals = await dataService.fetchArrivals(for: stop.id)
        print("📱 [StopCard] \(stop.name): \(arrivals.count) llegadas obtenidas")
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
