import Foundation
import Combine

/// Manages global notification preferences using UserDefaults
class NotificationSettings: ObservableObject {
    static let shared = NotificationSettings()
    
    private let defaults = UserDefaults.standard
    
    // Keys
    private let moodCheckInKey = "notif_mood_checkin_enabled"
    private let weeklyReviewKey = "notif_weekly_review_enabled"
    
    @Published var moodCheckInEnabled: Bool {
        didSet {
            defaults.set(moodCheckInEnabled, forKey: moodCheckInKey)
            Task { @MainActor in
                NotificationManager.shared.scheduleMoodCheckIn(enabled: moodCheckInEnabled)
            }
        }
    }
    
    @Published var weeklyReviewEnabled: Bool {
        didSet {
            defaults.set(weeklyReviewEnabled, forKey: weeklyReviewKey)
            Task { @MainActor in
                NotificationManager.shared.scheduleWeeklyReview(enabled: weeklyReviewEnabled)
            }
        }
    }
    
    private init() {
        // Load saved preferences or default to true
        self.moodCheckInEnabled = defaults.object(forKey: moodCheckInKey) as? Bool ?? true
        self.weeklyReviewEnabled = defaults.object(forKey: weeklyReviewKey) as? Bool ?? true
    }
    
    func initialize() {
        // Schedule initial notifications if enabled
        Task { @MainActor in
            NotificationManager.shared.scheduleMoodCheckIn(enabled: moodCheckInEnabled)
            NotificationManager.shared.scheduleWeeklyReview(enabled: weeklyReviewEnabled)
        }
    }
}
