import Foundation
import UserNotifications
import Combine
import UIKit
import SwiftData

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    
    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Permission Management
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                isAuthorized = granted
            }
            print("Notification permission granted: \(granted)")
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Habit Notifications
    
    func scheduleHabitReminder(habitId: UUID, habitName: String, reminderTime: Date, daysOfWeek: [Int]) {
        // Cancel existing notifications for this habit
        cancelHabitReminder(habitId: habitId)
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
        
        guard let hour = components.hour, let minute = components.minute else {
            print("Invalid reminder time")
            return
        }
        
        // If no specific days are set, schedule for every day
        let scheduledDays = daysOfWeek.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : daysOfWeek
        
        // Schedule a notification for each day of the week
        for day in scheduledDays {
            var dateComponents = DateComponents()
            dateComponents.weekday = day // 1 = Sunday, 2 = Monday, etc.
            dateComponents.hour = hour
            dateComponents.minute = minute
            
            let content = UNMutableNotificationContent()
            content.title = "Time for your habit!"
            content.body = habitName
            content.sound = .default
            content.categoryIdentifier = "HABIT_REMINDER"
            content.userInfo = ["habitId": habitId.uuidString, "type": "habit"]
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let identifier = "habit-\(habitId.uuidString)-day\(day)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to schedule habit notification: \(error)")
                } else {
                    print("Scheduled habit notification for \(habitName) on day \(day) at \(hour):\(minute)")
                }
            }
        }
    }
    
    func cancelHabitReminder(habitId: UUID) {
        // Cancel all notifications for this habit (all 7 possible days)
        let identifiers = (1...7).map { "habit-\(habitId.uuidString)-day\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("Cancelled habit notifications for \(habitId)")
    }
    
    // MARK: - Task Deadline Notifications
    
    func scheduleTaskDeadline(taskId: UUID, taskTitle: String, dueDate: Date) {
        // Cancel existing notification for this task
        cancelTaskDeadline(taskId: taskId)
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: dueDate)
        components.hour = 9  // Notify at 9 AM on due date
        components.minute = 0
        
        let content = UNMutableNotificationContent()
        content.title = "Task Due Today"
        content.body = taskTitle
        content.sound = .default
        content.categoryIdentifier = "TASK_DEADLINE"
        content.userInfo = ["taskId": taskId.uuidString, "type": "task"]
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "task-\(taskId.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule task notification: \(error)")
            } else {
                print("Scheduled task deadline notification for '\(taskTitle)' on \(dueDate)")
            }
        }
    }
    
    func cancelTaskDeadline(taskId: UUID) {
        let identifier = "task-\(taskId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("Cancelled task notification for \(taskId)")
    }
    
    // MARK: - Mood Check-in Notifications
    
    func scheduleMoodCheckIn(enabled: Bool) {
        if !enabled {
            cancelMoodCheckIn()
            return
        }
        
        var dateComponents = DateComponents()
        dateComponents.hour = 20  // 8 PM
        dateComponents.minute = 0
        
        let content = UNMutableNotificationContent()
        content.title = "Evening Check-in"
        content.body = "How are you feeling today? Take a moment to check in."
        content.sound = .default
        content.categoryIdentifier = "MOOD_CHECKIN"
        content.userInfo = ["type": "mood"]
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let identifier = "mood-checkin-daily"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule mood check-in notification: \(error)")
            } else {
                print("Scheduled daily mood check-in at 8 PM")
            }
        }
    }
    
    func cancelMoodCheckIn() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["mood-checkin-daily"])
        print("Cancelled mood check-in notifications")
    }
    
    // MARK: - Weekly Review Notifications
    
    func scheduleWeeklyReview(enabled: Bool) {
        if !enabled {
            cancelWeeklyReview()
            return
        }
        
        var dateComponents = DateComponents()
        dateComponents.weekday = 1  // Sunday
        dateComponents.hour = 18  // 6 PM
        dateComponents.minute = 0
        
        let content = UNMutableNotificationContent()
        content.title = "Weekly Review Time"
        content.body = "Reflect on your week and plan for the next one."
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_REVIEW"
        content.userInfo = ["type": "review"]
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let identifier = "weekly-review-sunday"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule weekly review notification: \(error)")
            } else {
                print("Scheduled weekly review every Sunday at 6 PM")
            }
        }
    }
    
    func cancelWeeklyReview() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weekly-review-sunday"])
        print("Cancelled weekly review notifications")
    }
    
    // MARK: - Debug Helper
    
    func listPendingNotifications() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        print("📋 Pending Notifications (\(requests.count)):")
        for request in requests {
            print("  - \(request.identifier): \(request.content.title) - \(request.content.body)")
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                print("    Trigger: \(trigger.dateComponents)")
            }
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("Cancelled all notifications")
    }
}
