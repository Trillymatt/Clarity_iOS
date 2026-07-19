//
//  ClarityApp.swift
//  Clarity
//
//  Created by Matthew Norman on 11/19/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct ClarityApp: App {
    
    var sharedModelContainer: ModelContainer = {
        let schema = ClarityModelContainer.schema

        // Try persistent storage first.
        // cloudKitDatabase MUST be .none: the app's CloudKit entitlement (used by
        // CloudKitService for social features) otherwise makes SwiftData default to
        // .automatic CloudKit mirroring, whose schema validation rejects our
        // @Attribute(.unique) models and crashes every container init.
        let persistentConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

        // Check if we need to reset due to schema changes
        let currentSchemaVersion = 7 // Budget now has ownerEmail (was global before)
        let savedVersion = UserDefaults.standard.integer(forKey: "SchemaVersion")
        
        if savedVersion < currentSchemaVersion {
            print("⚠️ Schema version changed from \(savedVersion) to \(currentSchemaVersion)")
            print("🔄 Resetting database and clearing session...")
            
            // Delete database files
            let url = persistentConfiguration.url
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))
            
            // CRITICAL: Clear the session to match the database state
            AuthManager.shared.logout()
            
            UserDefaults.standard.set(currentSchemaVersion, forKey: "SchemaVersion")
            print("✅ Database and session reset complete")
        }

        // Attempt 1: Try with persistent storage
        do {
            let container = try ModelContainer(for: schema, configurations: [persistentConfiguration])
            print("✅ ModelContainer created successfully with persistent storage")
            return container
        } catch {
            print("❌ Could not create ModelContainer: \(error)")
            print("🔄 Attempting to reset data store...")
            
            // Attempt 2: Delete the store and try again
            let url = persistentConfiguration.url
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))
            
            do {
                let container = try ModelContainer(for: schema, configurations: [persistentConfiguration])
                print("✅ ModelContainer created successfully after reset")
                UserDefaults.standard.set(currentSchemaVersion, forKey: "SchemaVersion")
                return container
            } catch {
                print("❌ Could not create ModelContainer even after reset: \(error)")
                print("🔄 Falling back to in-memory storage...")
                
                // Attempt 3: Fallback to in-memory storage (app will work but won't persist data)
                let inMemoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                do {
                    let container = try ModelContainer(for: schema, configurations: [inMemoryConfiguration])
                    print("⚠️ Using IN-MEMORY storage - data will not persist!")
                    return container
                } catch {
                    // This should never happen, but if it does, we have no choice but to crash
                    print("💥 FATAL: Cannot create ModelContainer even with in-memory storage: \(error)")
                    fatalError("Critical error: Cannot initialize data storage. Please reinstall the app. Error: \(error)")
                }
            }
        }
    }()

    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .tint(Color.clarityBlue)
                .onAppear {
                    cleanupOldTasks()
                    updateNotifications()
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .background {
                        // Update notifications with latest data when leaving app
                        updateNotifications()
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func handleDeepLink(_ url: URL) {
        // Handle friend invite: 
        // 1. Custom Scheme: clarity://add-friend?email=...
        // 2. Web fallback (legacy): https://clarity-app.com/add-friend?email=...
        
        let isCustomScheme = url.scheme == "clarity" && url.host == "add-friend"
        let isWebLink = (url.host == "clarity-app.com" || url.host == "www.clarity-app.com") && url.path == "/add-friend"
        
        if isCustomScheme || isWebLink,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let email = components.queryItems?.first(where: { $0.name == "email" })?.value {
            
            // Post notification to open AddFriendSheet with pre-filled email
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenAddFriendWithEmail"),
                object: nil,
                userInfo: ["email": email]
            )
            return
        }
        
        // Handle task completion: clarity://task/complete/{taskId}
        guard url.scheme == "clarity",
              url.host == "task",
              url.pathComponents.count >= 3,
              url.pathComponents[1] == "complete" else {
            return
        }
        
        let taskIdString = url.pathComponents[2]
        guard let taskId = UUID(uuidString: taskIdString) else { return }
        
        Task { @MainActor in
            let context = ModelContext(sharedModelContainer)
            let descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { $0.id == taskId }
            )
            
            if let tasks = try? context.fetch(descriptor), let task = tasks.first {
                withAnimation {
                    task.isCompleted = true
                    task.completedDate = Date()
                    task.isInProgress = false
                    try? context.save()
                    
                    // Stop Live Activity
                    if LiveActivityManager.shared.activeTaskId == taskIdString {
                        LiveActivityManager.shared.stopTaskActivity()
                    }
                    
                    // Update widgets
                    let userEmail = task.ownerEmail
                    if !userEmail.isEmpty {
                        WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
                    }
                }
            }
        }
    }
    
    private func updateNotifications() {
        Task { @MainActor in
            // Check permissions (don't request if not already determined, just check)
            // Actually, requestAuthorization returns true if already authorized.
            let granted = await NotificationManager.shared.requestAuthorization()
            if granted {
                // Fetch tasks for real-data notifications
                let context = ModelContext(sharedModelContainer)
                let descriptor = FetchDescriptor<TaskItem>()
                if let tasks = try? context.fetch(descriptor) {
                    NotificationManager.shared.updateTasks(tasks)
                }
                
                // Initialize/Reschedule global notification settings
                // This will trigger NotificationManager to reschedule with new data
                NotificationSettings.shared.initialize()
            }
        }
    }
    
    private func cleanupOldTasks() {
        // Run in background to avoid blocking UI
        Task {
            let context = ModelContext(sharedModelContainer)
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            
            do {
                // 1. Clean up orphaned habit check-ins (check-ins with nil or deleted habits)
                let allCheckins = try context.fetch(FetchDescriptor<HabitCheckin>())
                let orphanedCheckins = allCheckins.filter { $0.habit == nil }
                
                for checkin in orphanedCheckins {
                    context.delete(checkin)
                }
                
                if !orphanedCheckins.isEmpty {
                    print("Cleaned up \(orphanedCheckins.count) orphaned habit check-ins.")
                }
                
                // 2. Fetch completed tasks older than 30 days
                let descriptor = FetchDescriptor<TaskItem>(
                    predicate: #Predicate { $0.isCompleted && $0.completedDate != nil && $0.completedDate! < cutoffDate }
                )
                let oldTasks = try context.fetch(descriptor)
                
                for task in oldTasks {
                    context.delete(task)
                }
                
                if !oldTasks.isEmpty {
                    print("Cleaned up \(oldTasks.count) old tasks.")
                }
                
                // Save all changes
                if !orphanedCheckins.isEmpty || !oldTasks.isEmpty {
                    try context.save()
                }
            } catch {
                print("Failed to cleanup: \(error)")
            }
        }
    }
}
