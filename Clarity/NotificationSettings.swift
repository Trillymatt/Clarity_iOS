import Foundation
import Combine

/// Manages global notification preferences using UserDefaults
class NotificationSettings: ObservableObject {
    static let shared = NotificationSettings()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    
    // Enabled keys
    private let moodCheckInKey = "notif_mood_checkin_enabled"
    private let weeklyReviewKey = "notif_weekly_review_enabled"
    private let morningMotivationKey = "notif_morning_motivation_enabled"
    private let afternoonReminderKey = "notif_afternoon_reminder_enabled"
    private let gratitudePromptsKey = "notif_gratitude_prompts_enabled"
    private let eveningRecapKey = "notif_evening_recap_enabled"

    // Time keys
    private let moodCheckInTimeKey = "notif_mood_checkin_time"
    private let morningMotivationTimeKey = "notif_morning_motivation_time"
    private let afternoonReminderTimeKey = "notif_afternoon_reminder_time"
    private let gratitudePromptsTimeKey = "notif_gratitude_prompts_time"
    private let eveningRecapTimeKey = "notif_evening_recap_time"
    
    // MARK: - Default Times
    
    /// Create a Date for a specific hour:minute (used for defaults)
    private static func defaultTime(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
    
    // MARK: - Published Properties
    
    // Enable/Disable toggles
    @Published var moodCheckInEnabled: Bool {
        didSet {
            defaults.set(moodCheckInEnabled, forKey: moodCheckInKey)
            rescheduleNotification(.moodCheckIn)
        }
    }
    
    @Published var weeklyReviewEnabled: Bool {
        didSet {
            defaults.set(weeklyReviewEnabled, forKey: weeklyReviewKey)
            rescheduleNotification(.weeklyReview)
        }
    }
    
    @Published var morningMotivationEnabled: Bool {
        didSet {
            defaults.set(morningMotivationEnabled, forKey: morningMotivationKey)
            rescheduleNotification(.morningMotivation)
        }
    }
    
    @Published var afternoonReminderEnabled: Bool {
        didSet {
            defaults.set(afternoonReminderEnabled, forKey: afternoonReminderKey)
            rescheduleNotification(.afternoonReminder)
        }
    }
    
    @Published var gratitudePromptsEnabled: Bool {
        didSet {
            defaults.set(gratitudePromptsEnabled, forKey: gratitudePromptsKey)
            rescheduleNotification(.gratitudePrompts)
        }
    }

    @Published var eveningRecapEnabled: Bool {
        didSet {
            defaults.set(eveningRecapEnabled, forKey: eveningRecapKey)
            rescheduleNotification(.eveningRecap)
        }
    }


    // Custom times
    @Published var moodCheckInTime: Date {
        didSet {
            defaults.set(moodCheckInTime, forKey: moodCheckInTimeKey)
            rescheduleNotification(.moodCheckIn)
        }
    }
    
    @Published var morningMotivationTime: Date {
        didSet {
            defaults.set(morningMotivationTime, forKey: morningMotivationTimeKey)
            rescheduleNotification(.morningMotivation)
        }
    }
    
    @Published var afternoonReminderTime: Date {
        didSet {
            defaults.set(afternoonReminderTime, forKey: afternoonReminderTimeKey)
            rescheduleNotification(.afternoonReminder)
        }
    }
    
    @Published var gratitudePromptsTime: Date {
        didSet {
            defaults.set(gratitudePromptsTime, forKey: gratitudePromptsTimeKey)
            rescheduleNotification(.gratitudePrompts)
        }
    }

    @Published var eveningRecapTime: Date {
        didSet {
            defaults.set(eveningRecapTime, forKey: eveningRecapTimeKey)
            rescheduleNotification(.eveningRecap)
        }
    }

    // MARK: - Notification Types

    private enum NotificationType {
        case moodCheckIn
        case weeklyReview
        case morningMotivation
        case afternoonReminder
        case gratitudePrompts
        case eveningRecap
    }

    // MARK: - Initialization

    private init() {
        // Load saved preferences
        // Existing notifications default to true, new ones default to false (opt-in)
        self.moodCheckInEnabled = defaults.object(forKey: moodCheckInKey) as? Bool ?? true
        self.weeklyReviewEnabled = defaults.object(forKey: weeklyReviewKey) as? Bool ?? true
        self.morningMotivationEnabled = defaults.object(forKey: morningMotivationKey) as? Bool ?? false
        self.afternoonReminderEnabled = defaults.object(forKey: afternoonReminderKey) as? Bool ?? false
        self.gratitudePromptsEnabled = defaults.object(forKey: gratitudePromptsKey) as? Bool ?? false
        self.eveningRecapEnabled = defaults.object(forKey: eveningRecapKey) as? Bool ?? false

        // Load saved times or use defaults
        self.moodCheckInTime = defaults.object(forKey: moodCheckInTimeKey) as? Date ?? Self.defaultTime(hour: 20, minute: 0) // 8 PM
        self.morningMotivationTime = defaults.object(forKey: morningMotivationTimeKey) as? Date ?? Self.defaultTime(hour: 7, minute: 30) // 7:30 AM
        self.afternoonReminderTime = defaults.object(forKey: afternoonReminderTimeKey) as? Date ?? Self.defaultTime(hour: 14, minute: 0) // 2 PM
        self.gratitudePromptsTime = defaults.object(forKey: gratitudePromptsTimeKey) as? Date ?? Self.defaultTime(hour: 19, minute: 0) // 7 PM
        self.eveningRecapTime = defaults.object(forKey: eveningRecapTimeKey) as? Date ?? Self.defaultTime(hour: 21, minute: 0) // 9 PM
    }

    // MARK: - Scheduling

    private func rescheduleNotification(_ type: NotificationType) {
        Task { @MainActor in
            switch type {
            case .moodCheckIn:
                NotificationManager.shared.scheduleMoodCheckIn(enabled: moodCheckInEnabled, time: moodCheckInTime)
            case .weeklyReview:
                NotificationManager.shared.scheduleWeeklyReview(enabled: weeklyReviewEnabled)
            case .morningMotivation:
                NotificationManager.shared.scheduleMorningMotivation(enabled: morningMotivationEnabled, time: morningMotivationTime)
            case .afternoonReminder:
                NotificationManager.shared.scheduleAfternoonReminder(enabled: afternoonReminderEnabled, time: afternoonReminderTime)
            case .gratitudePrompts:
                NotificationManager.shared.scheduleGratitudePrompts(enabled: gratitudePromptsEnabled, time: gratitudePromptsTime)
            case .eveningRecap:
                // Content-bearing — actually recomputed by NotificationScheduler,
                // this just re-applies the enabled/time toggle with a placeholder.
                NotificationManager.shared.scheduleEveningRecap(enabled: eveningRecapEnabled, time: eveningRecapTime, summary: "Tap to see how today went.")
            }
        }
    }

    func initialize() {
        // Schedule initial notifications if enabled
        Task { @MainActor in
            NotificationManager.shared.scheduleMoodCheckIn(enabled: moodCheckInEnabled, time: moodCheckInTime)
            NotificationManager.shared.scheduleWeeklyReview(enabled: weeklyReviewEnabled)
            NotificationManager.shared.scheduleGratitudePrompts(enabled: gratitudePromptsEnabled, time: gratitudePromptsTime)
            // Morning/afternoon/evening are data-aware and scheduled by
            // NotificationScheduler (called from ClarityApp and on scenePhase
            // changes) instead of here with placeholder zero values.
        }
    }
    
    // MARK: - Helpers
    
    /// Format a time for display
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
