//
//  SearchView.swift
//  WatchTrans iOS
//
//  Created by Juan Macias Gomez on 21/1/26.
//

import SwiftUI
import CoreLocation

struct SearchView: View {
    let dataService: DataService
    let locationService: LocationService
    let favoritesManager: FavoritesManager?

    @State private var searchText = ""
    @State private var searchResults: [StopDisplay] = []
    @State private var recentStopIds: [String] = []
    @State private var isSearching = false

    // Debounce timer
    @State private var searchTask: Task<Void, Never>?

    // Recent stops persistence
    private let recentStopsKey = "recentViewedStops"
    private let maxRecentStops = 5

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
                            ForEach(searchResults) { display in
                                NavigationLink(destination: StopDetailViewWithTracking(
                                    display: display,
                                    dataService: dataService,
                                    locationService: locationService,
                                    favoritesManager: favoritesManager,
                                    onViewedLongEnough: { addRecentStop(display.recentKey) }
                                )) {
                                    SearchResultRow(display: display, locationService: locationService, dataService: dataService)
                                }
                            }
                        }
                    }
                } else {
                    // Recent stops (viewed > 5 seconds)
                    if !recentStops.isEmpty {
                        Section("Paradas recientes") {
                            ForEach(recentStops) { display in
                                NavigationLink(destination: StopDetailViewWithTracking(
                                    display: display,
                                    dataService: dataService,
                                    locationService: locationService,
                                    favoritesManager: favoritesManager,
                                    onViewedLongEnough: { addRecentStop(display.recentKey) }
                                )) {
                                    SearchResultRow(display: display, locationService: locationService, dataService: dataService)
                                }
                            }
                            .onDelete { indexSet in
                                let idsToRemove = indexSet.map { recentStops[$0].recentKey }
                                recentStopIds.removeAll { idsToRemove.contains($0) }
                                saveRecentStops()
                            }
                        }
                    }

                    // Popular stops (when no search)
                    Section("Estaciones principales") {
                        ForEach(popularStops) { display in
                            NavigationLink(destination: StopDetailViewWithTracking(
                                display: display,
                                dataService: dataService,
                                locationService: locationService,
                                favoritesManager: favoritesManager,
                                onViewedLongEnough: { addRecentStop(display.recentKey) }
                            )) {
                                SearchResultRow(display: display, locationService: locationService, dataService: dataService)
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
                    try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce (faster)
                    if !Task.isCancelled && !newValue.isEmpty {
                        await performSearch(query: newValue)
                    }
                }
            }
            .navigationTitle("Buscar")
        }
        .onAppear {
            loadRecentStops()
            if let location = locationService.currentLocation {
                Task {
                    await dataService.fetchLinesIfNeeded(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                }
            }
        }
    }

    // MARK: - Transport Type Filter

    /// Check if display matches enabled transport types
    private func displayMatchesEnabledTypes(_ display: StopDisplay, enabledTypes: Set<TransportType>) -> Bool {
        if enabledTypes.isEmpty { return true }
        return enabledTypes.contains(display.transportType)
    }

    // MARK: - Popular Stops

    private var popularStops: [StopDisplay] {
        let enabledTypes = DataService.getEnabledTransportTypes()
        let filteredStops = dataService.stops

        // Prefer hub stops from server (isHub flag)
        let hubStops = filteredStops.filter { $0.isHub }
        let baseStops = hubStops.isEmpty ? filteredStops : hubStops

        let sortedStops: [Stop]
        if let location = locationService.currentLocation {
            sortedStops = baseStops.sorted { $0.distance(from: location) < $1.distance(from: location) }
        } else {
            sortedStops = baseStops.sorted { $0.name < $1.name }
        }

        let displays = sortedStops.prefix(10).flatMap { dataService.makeStopDisplays(for: $0) }
        return displays.filter { displayMatchesEnabledTypes($0, enabledTypes: enabledTypes) }
    }

    // MARK: - Search

    @MainActor
    private func performSearch(query: String) async {
        guard query.count >= 1 else {
            searchResults = []
            return
        }

        isSearching = true
        let results = await dataService.searchStops(query: query)
        // Apply transport type filter
        let enabledTypes = DataService.getEnabledTransportTypes()
        let displays = results.flatMap { dataService.makeStopDisplays(for: $0) }
        searchResults = displays.filter { displayMatchesEnabledTypes($0, enabledTypes: enabledTypes) }
        isSearching = false
    }

    // MARK: - Recent Stops

    /// Convert stop IDs to Stop objects
    private var recentStops: [StopDisplay] {
        recentStopIds.compactMap { entry in
            let (stopId, transportType) = parseRecentStopId(entry)
            guard let stop = dataService.getStop(by: stopId) else { return nil }
            let displays = dataService.makeStopDisplays(for: stop)
            if let transportType = transportType {
                return displays.first { $0.transportType == transportType } ?? displays.first
            }
            return displays.first
        }
    }

    private func loadRecentStops() {
        recentStopIds = UserDefaults.standard.stringArray(forKey: recentStopsKey) ?? []
    }

    private func saveRecentStops() {
        UserDefaults.standard.set(recentStopIds, forKey: recentStopsKey)
    }

    private func addRecentStop(_ stopKey: String) {
        // Remove if already exists
        recentStopIds.removeAll { $0 == stopKey }

        // Add at beginning
        recentStopIds.insert(stopKey, at: 0)

        // Keep only max items
        if recentStopIds.count > maxRecentStops {
            recentStopIds = Array(recentStopIds.prefix(maxRecentStops))
        }

        saveRecentStops()
    }

    private func parseRecentStopId(_ value: String) -> (String, TransportType?) {
        let parts = value.split(separator: "|", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            return (parts[0], TransportType(rawValue: parts[1]))
        }
        return (value, nil)
    }
}

// MARK: - StopDetailView with Time Tracking

/// Wrapper that tracks viewing time and calls callback after 5 seconds
struct StopDetailViewWithTracking: View {
    let display: StopDisplay
    let dataService: DataService
    let locationService: LocationService
    let favoritesManager: FavoritesManager?
    let onViewedLongEnough: () -> Void

    @State private var viewStartTime: Date?
    @State private var hasTriggered = false

    private let minimumViewTime: TimeInterval = 5.0

    var body: some View {
        StopDetailView(
            stop: display.stop,
            display: display,
            dataService: dataService,
            locationService: locationService,
            favoritesManager: favoritesManager
        )
        .onAppear {
            viewStartTime = Date()
            hasTriggered = false
        }
        .onDisappear {
            guard !hasTriggered,
                  let startTime = viewStartTime else { return }

            let viewDuration = Date().timeIntervalSince(startTime)
            if viewDuration >= minimumViewTime {
                hasTriggered = true
                onViewedLongEnough()
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let display: StopDisplay
    let locationService: LocationService
    let dataService: DataService

    // Default colors for connection badges
    private let defaultMetroColor = "#ED1C24"
    private let defaultMlColor = "#3A7DDA"
    private let defaultCercaniasColor = "#75B2E0"
    private let defaultTranviaColor = "#E4002B"

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

    /// Parse comma-separated line string into array
    private func parseLines(_ value: String?) -> [String] {
        guard let value = value, !value.isEmpty else { return [] }
        return value.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// All connection badges: Cercanías → Metro → Metro Ligero → Tranvía
    private var connectionBadges: [(name: String, color: Color)] {
        var badges: [(String, Color)] = []

        // Train connections (Cercanías, FEVE, etc.)
        for line in parseLines(display.stop.corTren) {
            let color = dataService.getLine(by: line)?.color ?? Color(hex: defaultCercaniasColor) ?? .blue
            badges.append((line, color))
        }

        // Metro connections
        for line in parseLines(display.stop.corMetro) {
            let color = dataService.getLine(by: line)?.color ?? Color(hex: defaultMetroColor) ?? .red
            badges.append((line, color))
        }

        // Metro Ligero connections
        for line in parseLines(display.stop.corMl) {
            let color = dataService.getLine(by: line)?.color ?? Color(hex: defaultMlColor) ?? .blue
            badges.append((line, color))
        }

        // Tranvía connections
        for line in parseLines(display.stop.corTranvia) {
            let color = dataService.getLine(by: line)?.color ?? Color(hex: defaultTranviaColor) ?? .red
            badges.append((line, color))
        }

        return badges
    }

    /// Check if stop has any connections to show
    private var hasConnections: Bool {
        !connectionBadges.isEmpty
    }

    var body: some View {
        HStack(spacing: 12) {
            // Transport logo from API
            LogoImageView(
                type: display.transportType,
                nucleo: dataService.currentLocation?.provinceName ?? (display.stop.province ?? ""),
                height: 28
            )
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(display.stop.name)
                    .font(.body)
                    .fontWeight(.medium)

                // Connection badges (Metro, Cercanías, Tranvía, ML)
                if hasConnections {
                    FlowLayout(spacing: 4) {
                        ForEach(Array(connectionBadges.prefix(6).enumerated()), id: \.offset) { _, badge in
                            Text(badge.name)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badge.color)
                                .cornerRadius(4)
                        }
                        if connectionBadges.count > 6 {
                            Text("+\(connectionBadges.count - 6)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Distance
            if let location = locationService.currentLocation {
                Text(display.stop.formattedDistance(from: location))
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
