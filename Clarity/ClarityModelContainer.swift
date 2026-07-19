import Foundation
import SwiftData

// MARK: - Clarity Model Container
// Single source of truth for the app's SwiftData schema, so App Intents
// (which run in the main app's own process — not the widget extension —
// when invoked via Shortcuts/Siri) can open the exact same persistent store
// the app uses, without a second copy of the schema list to drift out of
// sync with ClarityApp.swift.
enum ClarityModelContainer {
    static let schema = Schema([
        UserProfile.self,
        TaskItem.self,
        Habit.self,
        HabitCheckin.self,
        JournalEntry.self,
        LifeMoment.self,
        Transaction.self,
        FinancialGoal.self,
        MoodEntry.self,
        WeeklyReview.self,
        Budget.self,
        ClarityScore.self,
        Workout.self,
        BodyMetric.self,
        AssistantMessage.self,
        UserGoals.self
    ])

    /// Opens the same store the app uses. Intended for App Intents — if the
    /// store can't be opened (e.g. mid schema-reset), the caller should fail
    /// gracefully rather than attempt any destructive recovery; that's the
    /// main app's job at launch, not a background intent's.
    static func open() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
