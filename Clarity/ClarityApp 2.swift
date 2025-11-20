import SwiftUI
import SwiftData

// This file intentionally does not declare an @main App to avoid duplicate entry points.
// It exposes a shared ModelContainer that can be used by the real App entry elsewhere.

@MainActor
public let sharedModelContainer: ModelContainer = {
    let schema = Schema([
        TaskItem.self,
        Habit.self,
        HabitCheckin.self,
        JournalEntry.self,
        LifeMoment.self,
        Transaction.self,
        FinancialGoal.self,
        LifeAreaScore.self
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    do {
        return try ModelContainer(for: schema, configurations: [configuration])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()
