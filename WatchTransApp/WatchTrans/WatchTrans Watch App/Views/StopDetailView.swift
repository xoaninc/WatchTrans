//
//  StopDetailView.swift
//  WatchTrans Watch App
//
//  Shows all departures from a specific stop
//

import SwiftUI
import WatchKit

struct StopDetailView: View {
    let stop: Stop
    let dataService: DataService
    let locationService: LocationService
    let favoritesManager: FavoritesManager?

    @Environment(\.scenePhase) private var scenePhase
    @State private var departures: [Arrival] = []
    @State private var alerts: [AlertResponse] = []
    @State private var isLoading = true
    @State private var refreshTimer: Timer?
    @State private var refreshTrigger = UUID()

    // Network monitoring
    private var networkMonitor = NetworkMonitor.shared

    // Explicit initializer to ensure accessible init for previews/navigation
    init(stop: Stop, dataService: DataService, locationService: LocationService, favoritesManager: FavoritesManager?) {
        self.stop = stop
        self.dataService = dataService
        self.locationService = locationService
        self.favoritesManager = favoritesManager
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Offline indicator
                if !networkMonitor.isConnected {
                    OfflineBannerCompact()
                }

                // Stop header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(stop.name)
                                .font(.headline)
                                .fontWeight(.bold)

                            if !alerts.isEmpty {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
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
                            WKInterfaceDevice.current().play(.click)
                            if manager.isFavorite(stopId: stop.id) {
                                manager.removeFavorite(stopId: stop.id)
                            } else if manager.favorites.count < manager.maxFavorites {
                                _ = manager.addFavorite(stop: stop)
                            }
                        } label: {
                            Image(systemName: manager.isFavorite(stopId: stop.id) ? "star.fill" : "star")
                                .font(.body)
                                .foregroundStyle(manager.isFavorite(stopId: stop.id) ? .yellow : .gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)

                // Alert banner (if any)
                if let firstAlert = alerts.first {
                    AlertBannerView(alert: firstAlert, alertCount: alerts.count)
                        .padding(.horizontal, 8)
                }

                // Departures section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Departures")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if !isLoading {
                            Text("\(departures.count)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 8)

                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    } else if departures.isEmpty {
                        Text("No departures available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(departures) { departure in
                            // Use routeColor from API, fallback to searching by lineId
                            let lineColor: Color = {
                                if let hex = departure.routeColor {
                                    return Color(hex: hex) ?? .blue
                                }
                                return dataService.getLine(by: departure.lineId)?.color ?? .blue
                            }()
                            NavigationLink(destination: TrainDetailView(arrival: departure, lineColor: lineColor)) {
                                ArrivalCard(arrival: departure, lineColor: lineColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .navigationTitle(abbreviateStopName(stop.name))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: refreshTrigger) {
            await loadData()
        }
        .refreshable {
            dataService.clearArrivalCache()
            await loadData()
            WKInterfaceDevice.current().play(.success)
        }
        .onAppear {
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                startAutoRefresh()
            case .inactive, .background:
                stopAutoRefresh()
            @unknown default:
                break
            }
        }
    }

    // MARK: - Auto Refresh (every 50 seconds)

    private func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 50, repeats: true) { _ in
            Task { @MainActor in
                dataService.clearArrivalCache()
                refreshTrigger = UUID()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func loadData() async {
        isLoading = true
        async let departuresTask = dataService.fetchArrivals(for: stop.id)
        async let alertsTask = dataService.fetchAlertsForStop(stopId: stop.id)
        departures = await departuresTask
        alerts = await alertsTask
        isLoading = false
    }

    /// Abbreviate long stop names for nav title
    private func abbreviateStopName(_ name: String) -> String {
        if name.count <= 15 {
            return name
        }

        var abbreviated = name
        let replacements = [
            "Chamartín-Clara Campoamor": "Chamrt.",
            "Guadalajara": "Guadljr.",
            "Aeropuerto": "Aerop.",
            "San Sebastián de los Reyes": "S.S. Reyes",
            "Alcobendas": "Alcob.",
            "Universidad": "Univ.",
            "Cercanías": "Cerc."
        ]

        for (long, short) in replacements {
            abbreviated = abbreviated.replacingOccurrences(of: long, with: short)
        }

        if abbreviated.count > 18 {
            return String(abbreviated.prefix(15)) + "..."
        }

        return abbreviated
    }
}

#Preview {
    NavigationStack {
        StopDetailView(
            stop: Stop(
                id: "RENFE_18002",
                name: "Nuevos Ministerios",
                latitude: 40.446,
                longitude: -3.692,
                connectionLineIds: [],
                province: nil,
                nucleoName: "Madrid",
                accesibilidad: "Accesible",
                hasParking: true,
                hasBusConnection: true,
                hasMetroConnection: true,
                corMetro: "6, 8, 10",
                corMl: nil,
                corCercanias: nil
            ),
            dataService: DataService(),
            locationService: LocationService(),
            favoritesManager: nil
        )
    }
}
