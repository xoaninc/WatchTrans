//
//  WatchTransApp.swift
//  WatchTrans iOS
//
//  Created by Juan Macias Gomez on 21/1/26.
//

import SwiftUI
import SwiftData

@main
struct WatchTransApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Favorite.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If persistent storage fails, try in-memory fallback so app doesn't crash
            DebugLog.log("⚠️ [App] ModelContainer failed: \(error). Using in-memory fallback.")
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                // This should never happen, but if it does, we have no choice
                fatalError("Could not create ModelContainer even in-memory: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
