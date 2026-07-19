import Foundation
import AppIntents
import SwiftData

// MARK: - Shared helpers

enum ClarityIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case notSignedIn
    case storeUnavailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notSignedIn: return "Open Clarity and sign in first."
        case .storeUnavailable: return "Clarity's data isn't available right now. Try opening the app first."
        }
    }
}

/// Every intent needs the same three things: the signed-in user's email, a
/// context on the app's real store, and a tool executor to act through —
/// reusing ClarityToolExecutor here instead of re-implementing each mutation
/// a second time for Shortcuts.
@MainActor
private func makeExecutor() throws -> (executor: ClarityToolExecutor, context: ModelContext, userEmail: String) {
    guard let userEmail = AuthManager.shared.getLastUserEmail() else {
        throw ClarityIntentError.notSignedIn
    }
    let container: ModelContainer
    do {
        container = try ClarityModelContainer.open()
    } catch {
        throw ClarityIntentError.storeUnavailable
    }
    let context = ModelContext(container)
    return (ClarityToolExecutor(context: context, userEmail: userEmail), context, userEmail)
}

// MARK: - Complete Task

struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete a Task"
    static var description = IntentDescription("Marks a Clarity task as done by matching its title.")

    @Parameter(title: "Task")
    var titleMatch: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (executor, _, _) = try makeExecutor()
        let result = executor.execute(name: "complete_task", argumentsJSON: "{\"title_match\":\"\(titleMatch.jsonEscaped)\"}")
        return .result(dialog: IntentDialog(stringLiteral: result.message))
    }
}

// MARK: - Log Workout

struct LogWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Workout"
    static var description = IntentDescription("Logs a workout in Clarity — run, walk, cycle, strength, yoga, swim, hiit, or other.")

    @Parameter(title: "Type", default: "run")
    var type: String

    @Parameter(title: "Duration (minutes)", default: 30)
    var durationMinutes: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (executor, _, _) = try makeExecutor()
        let args = "{\"type\":\"\(type.jsonEscaped)\",\"duration_minutes\":\(durationMinutes)}"
        let result = executor.execute(name: "log_workout", argumentsJSON: args)
        return .result(dialog: IntentDialog(stringLiteral: result.message))
    }
}

// MARK: - Check In Habit

struct CheckInHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Check In a Habit"
    static var description = IntentDescription("Logs today's check-in for a Clarity habit by matching its name.")

    @Parameter(title: "Habit")
    var habitName: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (executor, _, _) = try makeExecutor()
        let result = executor.execute(name: "log_habit_checkin", argumentsJSON: "{\"habit_name\":\"\(habitName.jsonEscaped)\"}")
        return .result(dialog: IntentDialog(stringLiteral: result.message))
    }
}

// MARK: - Log Mood

struct LogMoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Your Mood"
    static var description = IntentDescription("Logs how you're feeling in Clarity, from 1 (rough) to 5 (great).")

    @Parameter(title: "Mood (1-5)", default: 3)
    var score: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (executor, _, _) = try makeExecutor()
        let clamped = min(5, max(1, score))
        let result = executor.execute(name: "log_mood", argumentsJSON: "{\"score\":\(clamped)}")
        return .result(dialog: IntentDialog(stringLiteral: result.message))
    }
}

// MARK: - Ask Jarvis

struct AskJarvisIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Jarvis"
    static var description = IntentDescription("Ask Clarity's assistant a question or tell it to log something, hands-free.")

    @Parameter(title: "What do you want to tell Jarvis?")
    var question: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let userEmail = AuthManager.shared.getLastUserEmail() else {
            throw ClarityIntentError.notSignedIn
        }
        let container: ModelContainer
        do {
            container = try ClarityModelContainer.open()
        } catch {
            throw ClarityIntentError.storeUnavailable
        }
        let context = ModelContext(container)

        let profileDescriptor = FetchDescriptor<UserProfile>(predicate: #Predicate<UserProfile> { $0.email == userEmail })
        let profile = try? context.fetch(profileDescriptor).first
        let userContext = UserContext(
            biggestPriority: profile?.biggestPriority,
            idealDay: profile?.idealDay,
            desiredHabit: profile?.desiredHabit
        )
        let firstName = (profile?.name ?? "there").components(separatedBy: " ").first ?? "there"

        var historyDescriptor = FetchDescriptor<AssistantMessage>(
            predicate: #Predicate<AssistantMessage> { $0.ownerEmail == userEmail },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        historyDescriptor.fetchLimit = 20
        let history = (try? context.fetch(historyDescriptor)) ?? []

        let userMessage = AssistantMessage(ownerEmail: userEmail, role: "user", content: question)
        context.insert(userMessage)
        try? context.save()

        let turnResult = try await AssistantService.shared.sendMessage(
            question,
            history: history,
            userName: firstName,
            userContext: userContext,
            userEmail: userEmail,
            context: context
        )

        let summary = turnResult.actionSummaries.isEmpty ? nil : turnResult.actionSummaries.joined(separator: " · ")
        let reply = AssistantMessage(ownerEmail: userEmail, role: "assistant", content: turnResult.reply, actionSummary: summary)
        context.insert(reply)
        try? context.save()

        return .result(dialog: IntentDialog(stringLiteral: turnResult.reply))
    }
}

// MARK: - Shortcuts Provider
// Registers all of the above with the Shortcuts app / Siri automatically —
// no manual shortcut-building required.

struct ClarityShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWorkoutIntent(),
            phrases: [
                "Log a workout in \(.applicationName)",
                "Log my workout with \(.applicationName)"
            ],
            shortTitle: "Log Workout",
            systemImageName: "figure.run"
        )
        AppShortcut(
            intent: CompleteTaskIntent(),
            phrases: [
                "Complete a task in \(.applicationName)",
                "Mark a task done in \(.applicationName)"
            ],
            shortTitle: "Complete Task",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: CheckInHabitIntent(),
            phrases: [
                "Check in a habit in \(.applicationName)",
                "Log my habit with \(.applicationName)"
            ],
            shortTitle: "Check In Habit",
            systemImageName: "repeat.circle"
        )
        AppShortcut(
            intent: LogMoodIntent(),
            phrases: [
                "Log my mood in \(.applicationName)",
                "Check in my mood with \(.applicationName)"
            ],
            shortTitle: "Log Mood",
            systemImageName: "face.smiling"
        )
        AppShortcut(
            intent: AskJarvisIntent(),
            phrases: [
                "Ask Jarvis in \(.applicationName)",
                "Ask \(.applicationName) a question"
            ],
            shortTitle: "Ask Jarvis",
            systemImageName: "sparkles"
        )
    }
}

private extension String {
    /// Minimal escaping for embedding user-provided text into a hand-built
    /// JSON argument string (mirrors what ClarityToolExecutor expects from
    /// AssistantService's tool-calling loop).
    var jsonEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
