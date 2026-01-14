//
//  ContentView.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var locationService = LocationService()
    @State private var dataService = DataService()
    @State private var favoritesManager: FavoritesManager?
    @State private var selectedStop: Stop?

    var body: some View {
        TabView {
            // Home - Nearest stop arrivals
            HomeView(
                locationService: locationService,
                dataService: dataService,
                favoritesManager: favoritesManager,
                selectedStop: $selectedStop
            )
            .containerBackground(.black, for: .tabView)

            // Favorites
            if let manager = favoritesManager {
                FavoritesView(
                    selectedStop: $selectedStop,
                    favoritesManager: manager,
                    dataService: dataService,
                    locationService: locationService
                )
                .containerBackground(.black, for: .tabView)
            }
        }
        .tabViewStyle(.verticalPage)
        .onAppear {
            if favoritesManager == nil {
                favoritesManager = FavoritesManager(modelContext: modelContext)
            }
        }
        .onChange(of: selectedStop) { _, newStop in
            // When a favorite is selected, show its arrivals
            if newStop != nil {
                // Navigate to home view with selected stop
                // This will be handled in HomeView
            }
        }
    }
}

struct HomeView: View {
    let locationService: LocationService
    let dataService: DataService
    let favoritesManager: FavoritesManager?
    @Binding var selectedStop: Stop?

    @State private var arrivals: [Arrival] = []
    @State private var nearestStop: Stop?
    @State private var showAddedToFavorites = false

    var currentStop: Stop? {
        selectedStop ?? nearestStop
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if dataService.isLoading {
                        ProgressView("Loading...")
                            .padding()
                    } else if let stop = currentStop {
                        // Stop info header
                        VStack(spacing: 8) {
                            HStack {
                                Text(stop.name)
                                    .font(.title3)
                                    .fontWeight(.bold)

                                Spacer()

                                // Favorite button
                                if let manager = favoritesManager {
                                    if manager.isFavorite(stopId: stop.id) {
                                        Button {
                                            manager.removeFavorite(stopId: stop.id)
                                        } label: {
                                            Image(systemName: "star.fill")
                                                .foregroundStyle(.yellow)
                                        }
                                        .buttonStyle(.plain)
                                    } else if manager.favorites.count < manager.maxFavorites {
                                        Button {
                                            if manager.addFavorite(stop: stop) {
                                                showAddedToFavorites = true
                                            }
                                        } label: {
                                            Image(systemName: "star")
                                                .foregroundStyle(.gray)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            if let location = locationService.currentLocation {
                                Text(stop.formattedDistance(from: location))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 8)

                        if showAddedToFavorites {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text("Added to Favorites")
                                    .font(.caption)
                            }
                            .padding(8)
                            .background(.regularMaterial)
                            .cornerRadius(8)
                            .transition(.scale)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        showAddedToFavorites = false
                                    }
                                }
                            }
                        }

                        Divider()
                            .padding(.horizontal)

                        // Arrivals list
                        if arrivals.isEmpty {
                            Text("No arrivals available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding()
                        } else {
                            ForEach(arrivals) { arrival in
                                if let line = dataService.getLine(by: arrival.lineId) {
                                    ArrivalCard(arrival: arrival, lineColor: line.color)
                                } else {
                                    ArrivalCard(arrival: arrival, lineColor: .blue)
                                }
                            }
                        }
                    } else {
                        // No location or stop found
                        VStack(spacing: 12) {
                            Image(systemName: "location.slash")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)

                            Text("No nearby stops")
                                .font(.headline)

                            Text("Make sure location services are enabled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button("Retry") {
                                Task {
                                    await loadData()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    }
                }
                .padding(.horizontal, 8)
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
        .onChange(of: selectedStop) { _, newStop in
            if let stop = newStop {
                Task {
                    await loadArrivals(for: stop)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        // Request location permission if needed
        if locationService.authorizationStatus == .notDetermined {
            locationService.requestPermission()
        }

        // Start location updates
        locationService.startUpdating()

        // Wait a moment for location to be available
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Fetch transport data
        await dataService.fetchTransportData()

        // Find nearest stop (only if no stop is selected from favorites)
        if selectedStop == nil {
            if let nearest = locationService.findNearestStop(from: dataService.stops) {
                nearestStop = nearest
                await loadArrivals(for: nearest)
            }
        }
    }

    private func loadArrivals(for stop: Stop) async {
        arrivals = await dataService.fetchArrivals(for: stop.id)
    }
}

#Preview {
    ContentView()
}
