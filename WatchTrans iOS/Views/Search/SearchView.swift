//
//  SearchView.swift
//  WatchTrans iOS
//
//  Created by Juan Macias Gomez on 21/1/26.
//

import SwiftUI

struct SearchView: View {
    let dataService: DataService
    let locationService: LocationService
    let favoritesManager: FavoritesManager?

    @State private var searchText = ""
    @State private var searchResults: [Stop] = []
    @State private var recentSearches: [String] = []
    @State private var isSearching = false

    // Debounce timer
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                // Search results
                if !searchText.isEmpty {
                    if isSearching {
                        HStack {
                            Spacer()
                            ProgressView("Buscando...")
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    } else if searchResults.isEmpty {
                        Text("No se encontraron paradas para \"\(searchText)\"")
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    } else {
                        Section("Resultados") {
                            ForEach(searchResults) { stop in
                                NavigationLink(destination: StopDetailView(
                                    stop: stop,
                                    dataService: dataService,
                                    locationService: locationService,
                                    favoritesManager: favoritesManager
                                )) {
                                    SearchResultRow(stop: stop, locationService: locationService, dataService: dataService)
                                }
                            }
                        }
                    }
                } else {
                    // Recent searches
                    if !recentSearches.isEmpty {
                        Section("Busquedas recientes") {
                            ForEach(recentSearches, id: \.self) { query in
                                Button {
                                    searchText = query
                                    Task {
                                        await performSearch(query: query)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "clock")
                                            .foregroundStyle(.secondary)
                                        Text(query)
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                            .onDelete { indexSet in
                                recentSearches.remove(atOffsets: indexSet)
                                saveRecentSearches()
                            }
                        }
                    }

                    // Popular stops (when no search)
                    Section("Estaciones principales") {
                        ForEach(popularStops) { stop in
                            NavigationLink(destination: StopDetailView(
                                stop: stop,
                                dataService: dataService,
                                locationService: locationService,
                                favoritesManager: favoritesManager
                            )) {
                                SearchResultRow(stop: stop, locationService: locationService, dataService: dataService)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Buscar parada...")
            .onChange(of: searchText) { _, newValue in
                // Debounced search
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                    if !Task.isCancelled && !newValue.isEmpty {
                        await performSearch(query: newValue)
                    }
                }
            }
            .navigationTitle("Buscar")
        }
        .onAppear {
            loadRecentSearches()
        }
    }

    // MARK: - Popular Stops

    private var popularStops: [Stop] {
        // Return first 10 stops sorted by name
        Array(dataService.stops.sorted { $0.name < $1.name }.prefix(10))
    }

    // MARK: - Search

    @MainActor
    private func performSearch(query: String) async {
        guard query.count >= 2 else {
            searchResults = []
            return
        }

        isSearching = true
        searchResults = await dataService.searchStops(query: query)
        isSearching = false

        // Save to recent searches
        if !query.isEmpty && !searchResults.isEmpty {
            addRecentSearch(query)
        }
    }

    // MARK: - Recent Searches Persistence

    private let recentSearchesKey = "recentStopSearches"
    private let maxRecentSearches = 10

    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }

    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: recentSearchesKey)
    }

    private func addRecentSearch(_ query: String) {
        // Remove if already exists
        recentSearches.removeAll { $0.lowercased() == query.lowercased() }

        // Add at beginning
        recentSearches.insert(query, at: 0)

        // Keep only max items
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }

        saveRecentSearches()
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let stop: Stop
    let locationService: LocationService
    let dataService: DataService

    /// Format line name: "c4a" → "C4a", "l10b" → "L10b", "ml1" → "ML1"
    private func formatLineName(_ name: String) -> String {
        let lowercased = name.lowercased()

        // Handle ML prefix specially (2 chars)
        if lowercased.hasPrefix("ml") {
            let rest = String(lowercased.dropFirst(2))
            return "ML" + rest
        }

        // Handle single-char prefixes (C, L, R, T, S)
        if let first = lowercased.first, first.isLetter {
            let rest = String(lowercased.dropFirst())
            return String(first).uppercased() + rest
        }

        return name
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "tram.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(stop.name)
                    .font(.body)
                    .fontWeight(.medium)

                // Connection lines
                if !stop.connectionLineIds.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(stop.connectionLineIds.prefix(6), id: \.self) { lineId in
                            let badgeColor = dataService.getLine(by: lineId)?.color ?? .gray
                            Text(formatLineName(lineId))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badgeColor)
                                .cornerRadius(4)
                        }
                        if stop.connectionLineIds.count > 6 {
                            Text("+\(stop.connectionLineIds.count - 6)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Distance
            if let location = locationService.currentLocation {
                Text(stop.formattedDistance(from: location))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SearchView(
        dataService: DataService(),
        locationService: LocationService(),
        favoritesManager: nil
    )
}
