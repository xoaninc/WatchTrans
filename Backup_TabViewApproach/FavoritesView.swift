//
//  FavoritesView.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//

import SwiftUI

struct FavoritesView: View {
    @Binding var selectedStop: Stop?

    let favoritesManager: FavoritesManager
    let dataService: DataService
    let locationService: LocationService

    var favoriteStops: [Stop] {
        favoritesManager.getFavoriteStops(from: dataService.stops)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if favoriteStops.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "star.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("No Favorites Yet")
                            .font(.headline)

                        Text("Long-press any stop to add it to your favorites")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    // Header
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("Favorites")
                            .font(.headline)
                        Spacer()
                        Text("\(favoriteStops.count)/\(favoritesManager.maxFavorites)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Favorites list
                    ForEach(favoriteStops) { stop in
                        FavoriteStopCard(
                            stop: stop,
                            locationService: locationService,
                            onTap: {
                                selectedStop = stop
                                favoritesManager.incrementUsageCount(stopId: stop.id)
                            },
                            onRemove: {
                                favoritesManager.removeFavorite(stopId: stop.id)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FavoriteStopCard: View {
    let stop: Stop
    let locationService: LocationService
    let onTap: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)

                    Text(stop.name)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    if let location = locationService.currentLocation {
                        Text(stop.formattedDistance(from: location))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Connection indicators
                if !stop.connectionLineIds.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("\(stop.connectionLineIds.count) connections")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.regularMaterial)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove Favorite", systemImage: "star.slash")
            }
        }
    }
}
