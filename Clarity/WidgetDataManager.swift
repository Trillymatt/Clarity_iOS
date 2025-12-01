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
    
    // IMPORTANT: This matches your bundle ID (mattknorman.Clarity)
    // Make sure to add this EXACT identifier in App Groups capability for both targets
    private let appGroupIdentifier = "group.mattknorman.Clarity.shared"
    private let widgetDataKey = "widgetData"
    
    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    func saveWidgetData(_ data: WidgetData) {
        guard let encoded = try? JSONEncoder().encode(data) else {
            print("Failed to encode widget data")
            return
        }
        userDefaults?.set(encoded, forKey: widgetDataKey)
        userDefaults?.synchronize()
        
        // Tell widgets to reload
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    
    func loadWidgetData() -> WidgetData? {
        guard let data = userDefaults?.data(forKey: widgetDataKey),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return nil
        }
        return decoded
    }
}
