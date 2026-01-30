//
//  WatchTransApp.swift
//  WatchTrans iOS
//
//  Created by Juan Macias Gomez on 21/1/26.
//

import SwiftUI
import SwiftData
import BackgroundTasks

// MARK: - App Delegate for Background Tasks

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Register background refresh task
        BackgroundRefreshService.shared.register()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background refresh when app goes to background
        BackgroundRefreshService.shared.scheduleRefresh()
    }
}

@main
struct WatchTransApp: App {
    // Use AppDelegate for background task registration
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Initialize iCloud sync on app launch
        iCloudSyncService.shared.syncOnLaunch()
    }

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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // Schedule background refresh when app goes to background
                BackgroundRefreshService.shared.scheduleRefresh()
            }
        }
    }
}
