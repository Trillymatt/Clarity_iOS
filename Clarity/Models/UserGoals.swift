import Foundation
import SwiftData

// MARK: - User Goals
// One editable record per user — the targets Jarvis coaches you toward
// instead of just reporting where you stand. Replaces the hardcoded step/
// workout targets that used to live inside ClarityScoreCalculator.

@Model
final class UserGoals {
    @Attribute(.unique) var id: UUID
    var ownerEmail: String
    var dailyStepGoal: Int
    var weeklyWorkoutGoal: Int
    var dailyTaskGoal: Int
    var weeklySpendLimit: Double

    init(
        id: UUID = UUID(),
        ownerEmail: String = "",
        dailyStepGoal: Int = 8000,
        weeklyWorkoutGoal: Int = 4,
        dailyTaskGoal: Int = 3,
        weeklySpendLimit: Double = 200
    ) {
        self.id = id
        self.ownerEmail = ownerEmail
        self.dailyStepGoal = dailyStepGoal
        self.weeklyWorkoutGoal = weeklyWorkoutGoal
        self.dailyTaskGoal = dailyTaskGoal
        self.weeklySpendLimit = weeklySpendLimit
    }

    static func fetchOrCreate(context: ModelContext, ownerEmail: String) -> UserGoals {
        let descriptor = FetchDescriptor<UserGoals>(predicate: #Predicate<UserGoals> { $0.ownerEmail == ownerEmail })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let goals = UserGoals(ownerEmail: ownerEmail)
        context.insert(goals)
        try? context.save()
        return goals
    }
}
