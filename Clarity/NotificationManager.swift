import Foundation
import UserNotifications
import Combine
import UIKit
import SwiftData

// MARK: - Notification Message Variations

/// Rotating messages to keep notifications fresh and engaging
struct NotificationMessages {
    
    // MARK: - Mood Check-in Messages
    static let moodCheckIn = [
        ("Evening Check-in", "How are you feeling today? Take a moment to check in."),
        ("Evening Reflection 🌙", "How was your day? A quick check-in awaits."),
        ("A Minute for You", "Pause and reflect — how are you doing right now?"),
        ("Daily Check-in", "What's on your mind? Take a moment to reflect."),
        ("How's Your Day?", "End your day with a moment of self-awareness.")
    ]
    
    // MARK: - Weekly Review Messages
    static let weeklyReview = [
        ("Weekly Review Time", "Reflect on your week and plan for the next one."),
        ("Sunday Reflection", "Time to celebrate wins and learn from challenges."),
        ("Your Week in Review", "What made this week meaningful? Let's find out."),
        ("Weekly Check-in", "Look back, learn, and set intentions for next week."),
        ("Reflect & Plan", "A few minutes now sets you up for a great week ahead.")
    ]
    
    // MARK: - Habit Reminder Messages
    static let habitReminder = [
        ("Time for your habit!", "{habit} — you've got this! 💪"),
        ("Don't break the streak!", "{habit} is waiting for you."),
        ("Small Steps, Big Results", "Time for {habit}. Your future self will thank you."),
        ("Habit Time!", "{habit} — consistency is your superpower."),
        ("Keep the Momentum", "Ready for {habit}? Let's go!")
    ]
    
    // MARK: - Morning Motivation Messages
    static let morningMotivation = [
        ("Good Morning! ☀️", "You have {count} tasks today. Ready to make it count?"),
        ("Rise & Shine", "A new day, new possibilities. What will you accomplish?"),
        ("Morning Focus", "Today's priority: {task}. You've got this!"),
        ("Start Strong", "Your {count} tasks await. Let's make today great!"),
        ("Fresh Start", "Every morning is a chance to be better. Let's go!")
    ]
    
    // MARK: - Afternoon Reminder Messages
    static let afternoonReminder = [
        ("Afternoon Check", "You have {count} tasks left. Need a focus boost?"),
        ("Midday Nudge", "{count} tasks remaining — you've still got time!"),
        ("Stay on Track", "A little afternoon push: {count} tasks to go."),
        ("Power Through", "The day's not over! {count} tasks waiting for you."),
        ("Quick Check-in", "How's your focus? {count} tasks left today.")
    ]
    
    // MARK: - Gratitude Prompt Messages
    static let gratitudePrompt = [
        ("Gratitude Moment", "What's one thing you're grateful for today?"),
        ("Capture the Good 🌟", "Take a moment to appreciate something positive."),
        ("Evening Gratitude", "What made you smile today? Capture it!"),
        ("Find the Silver Lining", "Even small wins count. What went well today?"),
        ("Grateful Reflection", "Pause and think: what are you thankful for?")
    ]
    
    // MARK: - Streak Celebration Messages
    static let streakCelebrations: [Int: (String, String)] = [
        3: ("3-Day Streak! 🔥", "You're building momentum with {habit}. Keep it up!"),
        7: ("One Week Strong! 🎯", "7 days of {habit}! Consistency is your superpower."),
        14: ("Two Weeks! ⭐", "{habit} is becoming second nature. Amazing progress!"),
        21: ("21-Day Milestone! 🌟", "They say it takes 21 days to form a habit. You did it!"),
        30: ("30-Day Streak! 🏆", "One month of {habit}! You're unstoppable."),
        60: ("60 Days! 💎", "Two months strong with {habit}. Incredible dedication!"),
        100: ("100-Day Legend! 👑", "100 days of {habit}! You're an inspiration.")
    ]
    
    // MARK: - Helper to get random message
    static func random(from messages: [(String, String)]) -> (title: String, body: String) {
        let message = messages.randomElement() ?? messages[0]
        return (message.0, message.1)
    }
}

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
            
            // Use varied messages for habit reminders
            let message = NotificationMessages.random(from: NotificationMessages.habitReminder)
            
            let content = UNMutableNotificationContent()
            content.title = message.title
            content.body = message.body.replacingOccurrences(of: "{habit}", with: habitName)
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
    
    func scheduleMoodCheckIn(enabled: Bool, time: Date? = nil) {
        if !enabled {
            cancelMoodCheckIn()
            return
        }
        
        // Cancel existing before rescheduling
        cancelMoodCheckIn()
        
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        if let time = time {
            dateComponents.hour = calendar.component(.hour, from: time)
            dateComponents.minute = calendar.component(.minute, from: time)
        } else {
            dateComponents.hour = 20  // Default 8 PM
            dateComponents.minute = 0
        }
        
        // Use varied messages for mood check-in
        let message = NotificationMessages.random(from: NotificationMessages.moodCheckIn)
        
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
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
            print("Scheduled daily mood check-in at \(dateComponents.hour ?? 0):\(String(format: "%02d", dateComponents.minute ?? 0))")
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
        
        // Use varied messages for weekly review
        let message = NotificationMessages.random(from: NotificationMessages.weeklyReview)
        
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
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
    
    // MARK: - Morning Motivation Notifications
    
    func scheduleMorningMotivation(enabled: Bool, time: Date? = nil, taskCount: Int = 0, topTask: String? = nil) {
        if !enabled {
            cancelMorningMotivation()
            return
        }
        
        // Cancel existing before rescheduling
        cancelMorningMotivation()
        
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        if let time = time {
            dateComponents.hour = calendar.component(.hour, from: time)
            dateComponents.minute = calendar.component(.minute, from: time)
        } else {
            dateComponents.hour = 7  // Default 7:30 AM
            dateComponents.minute = 30
        }
        
        // Use varied messages
        let message = NotificationMessages.random(from: NotificationMessages.morningMotivation)
        var body = message.body
            .replacingOccurrences(of: "{count}", with: "\(taskCount)")
        if let task = topTask {
            body = body.replacingOccurrences(of: "{task}", with: task)
        } else {
            body = body.replacingOccurrences(of: "{task}", with: "your goals")
        }
        
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "MORNING_MOTIVATION"
        content.userInfo = ["type": "morning"]
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let identifier = "morning-motivation-daily"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule morning motivation: \(error)")
            } else {
                print("Scheduled morning motivation at \(dateComponents.hour ?? 0):\(String(format: "%02d", dateComponents.minute ?? 0))")
            }
        }
    }
    
    func cancelMorningMotivation() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morning-motivation-daily"])
        print("Cancelled morning motivation notifications")
    }
    
    // MARK: - Afternoon Reminder Notifications
    
    func scheduleAfternoonReminder(enabled: Bool, time: Date? = nil, remainingTaskCount: Int = 0) {
        if !enabled {
            cancelAfternoonReminder()
            return
        }
        
        // Cancel existing before rescheduling
        cancelAfternoonReminder()
        
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        if let time = time {
            dateComponents.hour = calendar.component(.hour, from: time)
            dateComponents.minute = calendar.component(.minute, from: time)
        } else {
            dateComponents.hour = 14  // Default 2 PM
            dateComponents.minute = 0
        }
        
        // Use varied messages
        let message = NotificationMessages.random(from: NotificationMessages.afternoonReminder)
        let body = message.body.replacingOccurrences(of: "{count}", with: "\(remainingTaskCount)")
        
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "AFTERNOON_REMINDER"
        content.userInfo = ["type": "afternoon"]
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let identifier = "afternoon-reminder-daily"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule afternoon reminder: \(error)")
            } else {
                print("Scheduled afternoon reminder at \(dateComponents.hour ?? 0):\(String(format: "%02d", dateComponents.minute ?? 0))")
            }
        }
    }
    
    func cancelAfternoonReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["afternoon-reminder-daily"])
        print("Cancelled afternoon reminder notifications")
    }
    
    // MARK: - Gratitude Prompt Notifications
    
    func scheduleGratitudePrompts(enabled: Bool, time: Date? = nil) {
        if !enabled {
            cancelGratitudePrompts()
            return
        }
        
        // Cancel existing before rescheduling
        cancelGratitudePrompts()
        
        // Schedule for Tuesday (3), Thursday (5), Saturday (7)
        let gratitudeDays = [3, 5, 7]
        
        let calendar = Calendar.current
        
        for day in gratitudeDays {
            var dateComponents = DateComponents()
            dateComponents.weekday = day
            if let time = time {
                dateComponents.hour = calendar.component(.hour, from: time)
                dateComponents.minute = calendar.component(.minute, from: time)
            } else {
                dateComponents.hour = 19  // Default 7 PM
                dateComponents.minute = 0
            }
            
            // Use varied messages
            let message = NotificationMessages.random(from: NotificationMessages.gratitudePrompt)
            
            let content = UNMutableNotificationContent()
            content.title = message.title
            content.body = message.body
            content.sound = .default
            content.categoryIdentifier = "GRATITUDE_PROMPT"
            content.userInfo = ["type": "gratitude"]
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let identifier = "gratitude-prompt-day\(day)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to schedule gratitude prompt: \(error)")
                } else {
                    print("Scheduled gratitude prompt for day \(day) at 7 PM")
                }
            }
        }
    }
    
    func cancelGratitudePrompts() {
        let identifiers = [3, 5, 7].map { "gratitude-prompt-day\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("Cancelled gratitude prompt notifications")
    }
    
    // MARK: - Streak Celebration Notifications
    
    /// Send an immediate notification celebrating a habit streak milestone
    func sendStreakCelebration(habitName: String, streakDays: Int) {
        // Check if this is a milestone streak
        guard let celebration = NotificationMessages.streakCelebrations[streakDays] else {
            return // Not a milestone, no notification
        }
        
        let content = UNMutableNotificationContent()
        content.title = celebration.0
        content.body = celebration.1.replacingOccurrences(of: "{habit}", with: habitName)
        content.sound = .default
        content.categoryIdentifier = "STREAK_CELEBRATION"
        content.userInfo = ["type": "streak", "days": streakDays]
        
        // Send immediately (with 1 second delay)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let identifier = "streak-celebration-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send streak celebration: \(error)")
            } else {
                print("🎉 Sent streak celebration for \(habitName) at \(streakDays) days!")
            }
        }
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
