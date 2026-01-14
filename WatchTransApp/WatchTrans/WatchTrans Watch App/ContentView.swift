//
//  ContentView.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//  Redesigned to match original spec
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var locationService = LocationService()
    @State private var dataService = DataService()
    @State private var favoritesManager: FavoritesManager?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Favorites Section (max 5)
                    if let manager = favoritesManager, !manager.favorites.isEmpty {
                        FavoritesSectionView(
                            favoritesManager: manager,
                            dataService: dataService,
                            locationService: locationService
                        )
                    }

                    // Recommended Section
                    RecommendedSectionView(
                        dataService: dataService,
                        locationService: locationService,
                        favoritesManager: favoritesManager
                    )

                    // Check Lines Button
                    Button {
                        // TODO: Navigate to line browser
                        print("Check Lines tapped")
                    } label: {
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
            .navigationTitle("WatchTrans")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .onAppear {
            if favoritesManager == nil {
                favoritesManager = FavoritesManager(modelContext: modelContext)
            }
        }
    }

    private func loadData() async {
        if locationService.authorizationStatus == .notDetermined {
            locationService.requestPermission()
        }

        locationService.startUpdating()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await dataService.fetchTransportData()
    }
}

// MARK: - Favorites Section

struct FavoritesSectionView: View {
    let favoritesManager: FavoritesManager
    let dataService: DataService
    let locationService: LocationService

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
                    favoritesManager: favoritesManager
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

    var recommendedStops: [Stop] {
        var stops: [Stop] = []
        let favoriteIds = favoritesManager?.favorites.map { $0.stopId } ?? []

        // 1. Add nearest stop (if not in favorites)
        if let nearest = locationService.findNearestStop(from: dataService.stops),
           !favoriteIds.contains(nearest.id) {
            stops.append(nearest)
        }

        // 2. Add 2 most "frequent" stops (for now, just the first 2 that aren't favorites or nearest)
        let otherStops = dataService.stops.filter { stop in
            !favoriteIds.contains(stop.id) && !stops.contains(where: { $0.id == stop.id })
        }
        stops.append(contentsOf: Array(otherStops.prefix(2)))

        return Array(stops.prefix(3)) // Max 3
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
                        favoritesManager: favoritesManager
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

    @State private var arrivals: [Arrival] = []
    @State private var isLoadingArrivals = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Stop header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stop.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)

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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .cornerRadius(12)

            // Arrivals (always shown)
            VStack(spacing: 8) {
                if isLoadingArrivals {
                    ProgressView()
                        .padding()
                } else if arrivals.isEmpty {
                    Text("No arrivals available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(arrivals.prefix(3)) { arrival in
                        if let line = dataService.getLine(by: arrival.lineId) {
                            ArrivalCard(arrival: arrival, lineColor: line.color)
                        } else {
                            ArrivalCard(arrival: arrival, lineColor: .blue)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .task {
            await loadArrivals()
        }
    }

    private func loadArrivals() async {
        isLoadingArrivals = true
        arrivals = await dataService.fetchArrivals(for: stop.id)
        isLoadingArrivals = false
    }
}

#Preview {
    ContentView()
}
