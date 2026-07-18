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
        let schema = Schema([
            UserProfile.self,
            TaskItem.self,
            Habit.self,
            HabitCheckin.self,
            JournalEntry.self,
            LifeMoment.self,
            Transaction.self,
            FinancialGoal.self,
            LifeAreaScore.self,
            MoodEntry.self,
            WeeklyReview.self,
            Budget.self,
            Insight.self,
            ClarityScore.self,
            Workout.self,
            BodyMetric.self,
            AssistantMessage.self
        ])

        // Try persistent storage first
        let persistentConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // Check if we need to reset due to schema changes
        let currentSchemaVersion = 4 // Jarvis redesign: fitness + assistant models added
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
            // This prevents UserDefaults from having an email while SwiftData has no profile
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
                let inMemoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .tint(Color.clarityBlue)
                .onAppear {
                    cleanupOldTasks()
                    initializeNotifications()
                }
        }
        .modelContainer(sharedModelContainer)
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
    
    private func initializeNotifications() {
        Task { @MainActor in
            // Request notification permissions
            let granted = await NotificationManager.shared.requestAuthorization()
            if granted {
                // Initialize global notification settings (mood check-in, weekly review)
                NotificationSettings.shared.initialize()
            }
        }
    }
}
