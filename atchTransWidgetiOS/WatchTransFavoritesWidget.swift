//
//  WatchTransFavoritesWidget.swift
//  WatchTransWidgetExtension
//
//  Created by Conductor on 06/02/26.
//

import WidgetKit
import SwiftUI

//
//  WatchTransFavoritesWidget.swift
//  WatchTransWidgetExtension
//
//  Created by Conductor on 06/02/26.
//

import WidgetKit
import SwiftUI

#if os(iOS)

// MARK: - Models

struct FavoriteStopData: Identifiable {
    let id: String
    let name: String
    let departures: [DepartureResponse]
}

struct FavoritesEntry: TimelineEntry {
    let date: Date
    let favorites: [FavoriteStopData]
    let error: String?
}

// MARK: - Provider

struct FavoritesProvider: TimelineProvider {
    func placeholder(in context: Context) -> FavoritesEntry {
        FavoritesEntry(date: Date(), favorites: getPlaceholderFavorites(), error: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (FavoritesEntry) -> Void) {
        if context.isPreview {
            completion(FavoritesEntry(date: Date(), favorites: getPlaceholderFavorites(), error: nil))
            return
        }
        
        Task {
            let entry = await fetchEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoritesEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            // Refresh every 5 minutes to save battery (Favorites list is heavier)
            let nextUpdate = Date().addingTimeInterval(300)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    private func fetchEntry() async -> FavoritesEntry {
        // 1. Get favorites from SharedStorage
        let sharedFavorites = SharedStorage.shared.getFavorites()
        
        if sharedFavorites.isEmpty {
            return FavoritesEntry(date: Date(), favorites: [], error: "No favorites saved")
        }
        
        // 2. Fetch data for top 3 favorites
        let topFavorites = Array(sharedFavorites.prefix(3))
        // let stopIds = topFavorites.map { $0.stopId } // Unused
        
        // 3. Fetch concurrently
        return await performFetch(favorites: topFavorites)
    }
    
    private func performFetch(favorites: [SharedStorage.SharedFavorite]) async -> FavoritesEntry {
        let stopIds = favorites.map { $0.stopId }
        let results = await WidgetDataService.shared.fetchMultipleDepartures(stopIds: stopIds, limitPerStop: 4)
        
        var favoriteData: [FavoriteStopData] = []
        
        for fav in favorites {
            if let deps = results[fav.stopId] {
                favoriteData.append(FavoriteStopData(id: fav.stopId, name: fav.stopName, departures: deps))
            } else {
                favoriteData.append(FavoriteStopData(id: fav.stopId, name: fav.stopName, departures: []))
            }
        }
        
        return FavoritesEntry(date: Date(), favorites: favoriteData, error: nil)
    }
    
    private func getPlaceholderFavorites() -> [FavoriteStopData] {
        return [
            FavoriteStopData(id: "1", name: "Sol", departures: [
                DepartureResponse(tripId: "1", routeId: "C3", routeShortName: "C3", routeColor: "#813380", headsign: "Aranjuez", departureTime: "", departureSeconds: 0, minutesUntil: 2, stopSequence: 0, platform: "4", platformEstimated: false, delaySeconds: 0, realtimeDepartureTime: nil, realtimeMinutesUntil: 2, isDelayed: false, trainPosition: nil, frequencyBased: false, headwaySecs: nil, occupancyStatus: nil, occupancyPercentage: nil, occupancyPerCar: nil),
                DepartureResponse(tripId: "2", routeId: "C4", routeShortName: "C4", routeColor: "#2ca5dd", headsign: "Parla", departureTime: "", departureSeconds: 0, minutesUntil: 5, stopSequence: 0, platform: "5", platformEstimated: false, delaySeconds: 0, realtimeDepartureTime: nil, realtimeMinutesUntil: 5, isDelayed: true, trainPosition: nil, frequencyBased: false, headwaySecs: nil, occupancyStatus: nil, occupancyPercentage: nil, occupancyPerCar: nil)
            ]),
            FavoriteStopData(id: "2", name: "Atocha", departures: [
                DepartureResponse(tripId: "3", routeId: "C1", routeShortName: "C1", routeColor: "#75B6E0", headsign: "P. Pío", departureTime: "", departureSeconds: 0, minutesUntil: 8, stopSequence: 0, platform: "2", platformEstimated: false, delaySeconds: 0, realtimeDepartureTime: nil, realtimeMinutesUntil: 8, isDelayed: false, trainPosition: nil, frequencyBased: false, headwaySecs: nil, occupancyStatus: nil, occupancyPercentage: nil, occupancyPerCar: nil)
            ])
        ]
    }
}

// MARK: - Views

struct WatchTransFavoritesView: View {
    var entry: FavoritesEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = entry.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if entry.favorites.isEmpty {
                Text("Add favorites in app")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.favorites) { favorite in
                    FavoriteRow(favorite: favorite)
                    if favorite.id != entry.favorites.last?.id {
                        Divider()
                            .background(Color.white.opacity(0.2))
                    }
                }
            }
            Spacer()
        }
        .padding()
    }
}

struct FavoriteRow: View {
    let favorite: FavoriteStopData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(favorite.name)
                .font(.headline)
                .lineLimit(1)
            
            if favorite.departures.isEmpty {
                Text("No departures")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(favorite.departures.prefix(4)) { dep in
                    HStack {
                        Text(dep.routeShortName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: dep.routeColor ?? "#808080") ?? .gray)
                            )
                        
                        Text(dep.headsign ?? "")
                            .font(.caption2)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if let platform = dep.platform, !platform.isEmpty {
                            Text("Vía \(platform)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("\(dep.effectiveMinutesUntil) min")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(dep.isDelayed ? .orange : .primary)
                    }
                }
            }
        }
    }
}

// MARK: - Widget Configuration

struct WatchTransFavoritesWidget: Widget {
    let kind: String = "juan.WatchTrans.watchkitapp.Favorites"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavoritesProvider()) { entry in
            WatchTransFavoritesView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Favorites")
        .description("See departures for your favorite stops.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

#endif
