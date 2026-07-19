import Foundation
import SwiftData

/// Computes real data and refreshes the data-aware notifications (morning
/// brief, afternoon nudge, evening recap) so their copy actually reflects
/// today instead of a stale "0 tasks" placeholder. Each of those
/// notifications is scheduled single-shot (see NotificationManager), so this
/// is what keeps the next firing fresh — call it whenever the app becomes
/// active, which is also naturally how often a user like this actually opens
/// the app (morning / through the day / night).
enum NotificationScheduler {
    @MainActor
    static func refresh(context: ModelContext, userEmail: String) {
        guard NotificationManager.shared.isAuthorized else { return }
        let settings = NotificationSettings.shared

        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate<TaskItem> { $0.ownerEmail == userEmail }))) ?? []
        let habits = (try? context.fetch(FetchDescriptor<Habit>(predicate: #Predicate<Habit> { $0.ownerEmail == userEmail }))) ?? []
        let checkins = (try? context.fetch(FetchDescriptor<HabitCheckin>(predicate: #Predicate<HabitCheckin> { $0.ownerEmail == userEmail }))) ?? []
        let workouts = (try? context.fetch(FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.ownerEmail == userEmail }))) ?? []
        let bodyMetrics = (try? context.fetch(FetchDescriptor<BodyMetric>(predicate: #Predicate<BodyMetric> { $0.ownerEmail == userEmail }))) ?? []
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate<Transaction> { $0.ownerEmail == userEmail }))) ?? []
        let moodEntries = (try? context.fetch(FetchDescriptor<MoodEntry>(predicate: #Predicate<MoodEntry> { $0.ownerEmail == userEmail }))) ?? []
        let goals = UserGoals.fetchOrCreate(context: context, ownerEmail: userEmail)

        let calendar = Calendar.current
        let todayTasks = tasks.filter { !$0.isCompleted && ($0.isToday || ($0.dueDate != nil && calendar.isDateInToday($0.dueDate!))) }

        NotificationManager.shared.scheduleMorningMotivation(
            enabled: settings.morningMotivationEnabled,
            time: settings.morningMotivationTime,
            taskCount: todayTasks.count,
            topTask: todayTasks.first?.title
        )

        NotificationManager.shared.scheduleAfternoonReminder(
            enabled: settings.afternoonReminderEnabled,
            time: settings.afternoonReminderTime,
            remainingTaskCount: todayTasks.count
        )

        let recommendations = RecommendationEngine.generate(
            goals: goals,
            tasks: tasks,
            habits: habits,
            checkins: checkins,
            workouts: workouts,
            bodyMetrics: bodyMetrics,
            transactions: transactions,
            moodEntries: moodEntries
        )

        let completedToday = tasks.filter {
            $0.isCompleted && $0.completedDate != nil && calendar.isDateInToday($0.completedDate!)
        }.count

        let recapSummary: String
        if let topRec = recommendations.first {
            recapSummary = "\(completedToday) task\(completedToday == 1 ? "" : "s") done today. \(topRec.message)"
        } else {
            recapSummary = "\(completedToday) task\(completedToday == 1 ? "" : "s") done today — solid work. Keep it up tomorrow."
        }

        NotificationManager.shared.scheduleEveningRecap(
            enabled: settings.eveningRecapEnabled,
            time: settings.eveningRecapTime,
            summary: recapSummary
        )
    }
}
