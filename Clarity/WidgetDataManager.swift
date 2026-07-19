import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Shared data structure for widget display
struct WidgetTask: Codable, Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let priority: Int // 0: Low, 1: Medium, 2: High
    let dueTime: Date?
}

struct WidgetHabit: Codable, Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let progress: Int
    let goal: Int
    let colorHex: String?
}

/// Shared data structure for widget display
struct WidgetData: Codable {
    let clarityScore: Int
    let todayTasksCompleted: Int
    let todayTasksTotal: Int
    let primaryHabitName: String?
    let primaryHabitProgress: Int
    let primaryHabitGoal: Int
    let primaryHabitIcon: String?
    let lastUpdated: Date
    
    // New fields for detailed widgets
    var upcomingTasks: [WidgetTask] = []
    var activeHabits: [WidgetHabit] = []

    // Goals + fitness — powers the Goals-focused hero widget and the
    // Fitness widget without either needing their own data fetch.
    var todaySteps: Int? = nil
    var stepGoal: Int = 8000
    var weekWorkouts: Int = 0
    var weeklyWorkoutGoal: Int = 4
    var tasksCompletedToday: Int = 0
    var dailyTaskGoal: Int = 3
    var workoutStreak: Int = 0

    var taskCompletionText: String {
        "\(todayTasksCompleted)/\(todayTasksTotal) tasks"
    }
    
    var habitProgressText: String {
        guard let name = primaryHabitName else { return "No habit" }
        return "\(primaryHabitProgress)/\(primaryHabitGoal) \(name)"
    }
    
    static var placeholder: WidgetData {
        WidgetData(
            clarityScore: 75,
            todayTasksCompleted: 3,
            todayTasksTotal: 5,
            primaryHabitName: "Drink Water",
            primaryHabitProgress: 4,
            primaryHabitGoal: 8,
            primaryHabitIcon: "drop.fill",
            lastUpdated: Date(),
            upcomingTasks: [
                WidgetTask(id: UUID(), title: "Morning Meditation", isCompleted: true, priority: 2, dueTime: Date()),
                WidgetTask(id: UUID(), title: "Team Meeting", isCompleted: false, priority: 1, dueTime: Date().addingTimeInterval(3600)),
                WidgetTask(id: UUID(), title: "Review PRs", isCompleted: false, priority: 1, dueTime: Date().addingTimeInterval(7200))
            ],
            activeHabits: [
                WidgetHabit(id: UUID(), name: "Drink Water", icon: "drop.fill", progress: 4, goal: 8, colorHex: "#4A90E2"),
                WidgetHabit(id: UUID(), name: "Read", icon: "book.fill", progress: 15, goal: 30, colorHex: "#F5A623"),
                WidgetHabit(id: UUID(), name: "Exercise", icon: "figure.run", progress: 0, goal: 45, colorHex: "#7ED321")
            ]
        )
    }
}

/// Manager for sharing data between app and widget using App Groups
class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    // IMPORTANT: This MUST match EXACTLY what is in the entitlements files for both targets
    // Check: Clarity/Clarity.entitlements AND Clarity WidgetsExtension.entitlements
    private let appGroupIdentifier = "group.com.mattknorman.Clarity.shared"
    private let widgetDataKey = "widgetData"
    
    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    func saveWidgetData(_ data: WidgetData) {
        guard let encoded = try? JSONEncoder().encode(data) else {
            print("❌ Failed to encode widget data")
            return
        }
        
        print("✅ Saving widget data: \(data.todayTasksCompleted)/\(data.todayTasksTotal) tasks, score: \(data.clarityScore)")
        print("   App Group: \(appGroupIdentifier)")
        
        userDefaults?.set(encoded, forKey: widgetDataKey)
        userDefaults?.synchronize()
        
        print("✅ Widget data saved successfully")
        
        // Tell widgets to reload
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        print("✅ Requested widget timeline reload")
        #endif
    }
    
    func loadWidgetData() -> WidgetData? {
        print("📱 Loading widget data from App Group: \(appGroupIdentifier)")
        
        guard let data = userDefaults?.data(forKey: widgetDataKey),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            print("❌ No widget data found or failed to decode")
            return nil
        }
        
        print("✅ Loaded widget data: \(decoded.todayTasksCompleted)/\(decoded.todayTasksTotal) tasks, score: \(decoded.clarityScore)")
        return decoded
    }
}
