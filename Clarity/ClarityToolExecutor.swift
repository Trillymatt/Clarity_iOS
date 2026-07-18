import Foundation
import SwiftData

struct ToolExecutionResult {
    /// Fed back to the model as the tool's return value.
    let message: String
    /// Shown to the user as a small confirmation chip under the reply, if any.
    let actionSummary: String?
}

/// Maps a tool name + JSON arguments (as returned by OpenAI function calling)
/// onto real SwiftData mutations, following the same model conventions as
/// the rest of the app (ownerEmail scoping, WidgetDataUpdater refresh after
/// every write).
@MainActor
final class ClarityToolExecutor {
    let context: ModelContext
    let userEmail: String

    init(context: ModelContext, userEmail: String) {
        self.context = context
        self.userEmail = userEmail
    }

    func execute(name: String, argumentsJSON: String) -> ToolExecutionResult {
        let parsed = try? JSONSerialization.jsonObject(with: Data(argumentsJSON.utf8))
        let arguments = (parsed as? [String: Any]) ?? [:]

        switch name {
        case "create_task": return createTask(arguments)
        case "complete_task": return completeTask(arguments)
        case "create_habit": return createHabit(arguments)
        case "log_habit_checkin": return logHabitCheckin(arguments)
        case "log_mood": return logMood(arguments)
        case "log_moment": return logMoment(arguments)
        case "add_transaction": return addTransaction(arguments)
        case "log_workout": return logWorkout(arguments)
        case "get_summary": return getSummary()
        default:
            return ToolExecutionResult(message: "Unknown tool: \(name)", actionSummary: nil)
        }
    }

    // MARK: - Mutating tools

    private func createTask(_ args: [String: Any]) -> ToolExecutionResult {
        guard let title = args["title"] as? String, !title.isEmpty else {
            return ToolExecutionResult(message: "Missing task title.", actionSummary: nil)
        }
        let dueInDays = integer(args, "due_in_days")
        let category = TaskCategory(rawValue: (args["category"] as? String) ?? "") ?? .other
        let isToday = dueInDays == nil || dueInDays == 0
        let dueDate = dueInDays.flatMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }

        let task = TaskItem(ownerEmail: userEmail, title: title, dueDate: isToday ? nil : dueDate, isToday: isToday, category: category)
        context.insert(task)
        save()
        return ToolExecutionResult(message: "Created task '\(title)'.", actionSummary: "Added task: \(title)")
    }

    private func completeTask(_ args: [String: Any]) -> ToolExecutionResult {
        guard let match = args["title_match"] as? String, !match.isEmpty else {
            return ToolExecutionResult(message: "Missing title to match.", actionSummary: nil)
        }
        let openTasks = fetch(TaskItem.self, predicate: #Predicate<TaskItem> { $0.ownerEmail == userEmail && !$0.isCompleted })
        guard let task = openTasks.first(where: { $0.title.localizedCaseInsensitiveContains(match) }) else {
            return ToolExecutionResult(message: "No open task found matching '\(match)'.", actionSummary: nil)
        }
        task.isCompleted = true
        task.completedDate = Date()
        save()
        return ToolExecutionResult(message: "Completed task '\(task.title)'.", actionSummary: "Completed: \(task.title)")
    }

    private func createHabit(_ args: [String: Any]) -> ToolExecutionResult {
        guard let name = args["name"] as? String, !name.isEmpty else {
            return ToolExecutionResult(message: "Missing habit name.", actionSummary: nil)
        }
        let goal = integer(args, "goal_per_day") ?? 1
        let habit = Habit(ownerEmail: userEmail, name: name, iconName: "star.fill", goalPerDay: goal, daysOfWeek: Array(0...6))
        context.insert(habit)
        save()
        return ToolExecutionResult(message: "Created habit '\(name)'.", actionSummary: "Added habit: \(name)")
    }

    private func logHabitCheckin(_ args: [String: Any]) -> ToolExecutionResult {
        guard let match = args["habit_name"] as? String, !match.isEmpty else {
            return ToolExecutionResult(message: "Missing habit name to match.", actionSummary: nil)
        }
        let habits = fetch(Habit.self, predicate: #Predicate<Habit> { $0.ownerEmail == userEmail })
        guard let habit = habits.first(where: { $0.name.localizedCaseInsensitiveContains(match) }) else {
            return ToolExecutionResult(message: "No habit found matching '\(match)'.", actionSummary: nil)
        }
        let value = integer(args, "value") ?? 1
        let checkin = HabitCheckin(ownerEmail: userEmail, habit: habit, date: Date(), value: value, isCompleted: true)
        context.insert(checkin)
        save()
        return ToolExecutionResult(message: "Logged check-in for '\(habit.name)'.", actionSummary: "Checked in: \(habit.name)")
    }

    private func logMood(_ args: [String: Any]) -> ToolExecutionResult {
        guard let score = integer(args, "score") else {
            return ToolExecutionResult(message: "Missing mood score.", actionSummary: nil)
        }
        let emotion = (args["emotion"] as? String) ?? "neutral"
        let note = args["note"] as? String
        let normalized = max(0, min(1, (Double(score) - 1) / 4))
        let entry = MoodEntry(ownerEmail: userEmail, date: Date(), moodScore: normalized, emotion: emotion, note: note)
        context.insert(entry)
        UserDefaults.standard.set(Date(), forKey: "lastMoodCheckIn")
        save()
        return ToolExecutionResult(message: "Logged mood: \(emotion) (\(score)/5).", actionSummary: "Logged mood: \(emotion)")
    }

    private func logMoment(_ args: [String: Any]) -> ToolExecutionResult {
        guard let title = args["title"] as? String, !title.isEmpty else {
            return ToolExecutionResult(message: "Missing moment title.", actionSummary: nil)
        }
        let type = MomentType(rawValue: (args["type"] as? String) ?? "") ?? .other
        let note = args["note"] as? String
        let moment = LifeMoment(ownerEmail: userEmail, date: Date(), title: title, note: note, type: type)
        context.insert(moment)
        save()
        return ToolExecutionResult(message: "Captured moment '\(title)'.", actionSummary: "Captured moment: \(title)")
    }

    private func addTransaction(_ args: [String: Any]) -> ToolExecutionResult {
        guard let amount = number(args, "amount") else {
            return ToolExecutionResult(message: "Missing transaction amount.", actionSummary: nil)
        }
        let category = TransactionCategory(rawValue: (args["category"] as? String) ?? "") ?? .other
        let note = args["note"] as? String
        let txn = Transaction(ownerEmail: userEmail, amount: amount, date: Date(), category: category, note: note)
        context.insert(txn)
        save()
        return ToolExecutionResult(
            message: "Logged $\(String(format: "%.2f", amount)) transaction.",
            actionSummary: "Logged $\(String(format: "%.2f", amount)) — \(category.rawValue.capitalized)"
        )
    }

    private func logWorkout(_ args: [String: Any]) -> ToolExecutionResult {
        let type = WorkoutType(rawValue: (args["type"] as? String) ?? "") ?? .other
        let duration = integer(args, "duration_minutes") ?? 30
        let calories = number(args, "calories")
        let distanceMiles = number(args, "distance_miles")

        let workout = Workout(ownerEmail: userEmail, type: type, date: Date(), durationMinutes: duration, caloriesBurned: calories, source: "manual")
        workout.distanceMiles = distanceMiles
        context.insert(workout)
        save()
        return ToolExecutionResult(
            message: "Logged \(duration)-minute \(type.label.lowercased()).",
            actionSummary: "Logged workout: \(type.label) (\(duration)m)"
        )
    }

    // MARK: - Read-only summary
    // The model calls this before answering data questions so it never guesses.

    private func getSummary() -> ToolExecutionResult {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) ?? Date()

        let tasks = fetch(TaskItem.self, predicate: #Predicate<TaskItem> { $0.ownerEmail == userEmail })
        let habits = fetch(Habit.self, predicate: #Predicate<Habit> { $0.ownerEmail == userEmail })
        let checkins = fetch(HabitCheckin.self, predicate: #Predicate<HabitCheckin> { $0.ownerEmail == userEmail })
        let moods = fetch(MoodEntry.self, predicate: #Predicate<MoodEntry> { $0.ownerEmail == userEmail })
        let moments = fetch(LifeMoment.self, predicate: #Predicate<LifeMoment> { $0.ownerEmail == userEmail })
        let transactions = fetch(Transaction.self, predicate: #Predicate<Transaction> { $0.ownerEmail == userEmail })
        let workouts = fetch(Workout.self, predicate: #Predicate<Workout> { $0.ownerEmail == userEmail })
        let bodyMetrics = fetch(BodyMetric.self, predicate: #Predicate<BodyMetric> { $0.ownerEmail == userEmail })

        let score = ClarityScoreCalculator.calculateFullScore(
            tasks: tasks, habits: habits, checkins: checkins, moodEntries: moods,
            moments: moments, transactions: transactions, workouts: workouts, bodyMetrics: bodyMetrics
        )

        let todayTasks = tasks.filter { !$0.isCompleted && ($0.isToday || ($0.dueDate != nil && calendar.isDateInToday($0.dueDate!))) }
        let completedToday = tasks.filter { $0.isCompleted && $0.completedDate != nil && calendar.isDateInToday($0.completedDate!) }.count
        let activeHabits = habits.filter { $0.isActive }
        let weekWorkouts = workouts.filter { $0.date >= weekStart }
        let weekSpend = transactions.filter { $0.date >= weekStart }.reduce(0) { $0 + $1.amount }
        let latestMood = moods.sorted { $0.date > $1.date }.first
        let todaySteps = bodyMetrics.first { calendar.isDateInToday($0.date) }?.steps

        let summary = """
        Clarity Score: \(Int(score.totalScore))/100 (\(score.stateDescription))
        Tasks: \(todayTasks.count) open today, \(completedToday) completed today, \(tasks.filter { !$0.isCompleted }.count) open overall
        Habits: \(activeHabits.count) active habits: \(activeHabits.map(\.name).joined(separator: ", "))
        Fitness: \(weekWorkouts.count) workouts in the last 7 days, today's steps: \(todaySteps.map(String.init) ?? "unknown")
        Mood: \(latestMood.map { "last logged '\($0.emotion)'" } ?? "not logged recently")
        Money: $\(String(format: "%.2f", weekSpend)) spent in the last 7 days
        Recent moments: \(moments.suffix(3).map(\.title).joined(separator: ", "))
        """
        return ToolExecutionResult(message: summary, actionSummary: nil)
    }

    // MARK: - Helpers

    private func fetch<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>) -> [T] {
        (try? context.fetch(FetchDescriptor<T>(predicate: predicate))) ?? []
    }

    private func number(_ args: [String: Any], _ key: String) -> Double? {
        if let value = args[key] as? Double { return value }
        if let value = args[key] as? Int { return Double(value) }
        if let value = args[key] as? NSNumber { return value.doubleValue }
        return nil
    }

    private func integer(_ args: [String: Any], _ key: String) -> Int? {
        if let value = args[key] as? Int { return value }
        if let value = args[key] as? Double { return Int(value) }
        if let value = args[key] as? NSNumber { return value.intValue }
        return nil
    }

    private func save() {
        try? context.save()
        WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
    }
}
