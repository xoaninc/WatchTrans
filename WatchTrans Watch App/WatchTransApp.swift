//
//  WatchTransApp.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//

import SwiftUI
import SwiftData
import WatchKit

@main
struct WatchTrans_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Favorite.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - App Delegate for Background Tasks

class AppDelegate: NSObject, WKApplicationDelegate {

    /// Called when the app launches
    func applicationDidFinishLaunching() {
        // Schedule the first background refresh
        BackgroundRefreshService.shared.scheduleNextRefresh()
        print("✅ [AppDelegate] App launched, background refresh scheduled")
    }

    /// Handle background tasks
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let refreshTask as WKApplicationRefreshBackgroundTask:
                // Handle background refresh
                print("🔄 [AppDelegate] Handling WKApplicationRefreshBackgroundTask")
                Task {
                    await BackgroundRefreshService.shared.handleBackgroundRefresh(task: refreshTask)
                }

            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Handle snapshot refresh (for dock)
                snapshotTask.setTaskCompleted(
                    restoredDefaultState: true,
                    estimatedSnapshotExpiration: Date.distantFuture,
                    userInfo: nil
                )

            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Handle URL session completion
                urlSessionTask.setTaskCompletedWithSnapshot(false)

            default:
                // Mark unknown tasks as completed
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
