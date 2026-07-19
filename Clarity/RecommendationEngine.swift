import Foundation
import SwiftUI

// MARK: - Recommendation
// A specific, actionable nudge grounded in real numbers — not a generic
// insight. Deterministic and local so it's always instant, no AI round trip
// needed for the thing you check first thing in the morning.

struct Recommendation: Identifiable {
    enum Domain {
        case fitness, money, tasks, habits, mood

        var color: Color {
            switch self {
            case .fitness: return .clarityGreen
            case .money: return .clarityPurple
            case .tasks: return .clarityBlue
            case .habits: return .clarityOrange
            case .mood: return .clarityPink
            }
        }

        var icon: String {
            switch self {
            case .fitness: return "figure.run"
            case .money: return "dollarsign.circle.fill"
            case .tasks: return "checkmark.circle.fill"
            case .habits: return "repeat.circle.fill"
            case .mood: return "face.smiling.fill"
            }
        }
    }

    let id = UUID()
    let domain: Domain
    let message: String
    /// Higher fires first. Alerts (over budget, streak about to break) rank
    /// above gentle progress nudges.
    let priority: Int
}

enum RecommendationEngine {
    static func generate(
        goals: UserGoals,
        tasks: [TaskItem],
        habits: [Habit],
        checkins: [HabitCheckin],
        workouts: [Workout],
        bodyMetrics: [BodyMetric],
        transactions: [Transaction],
        moodEntries: [MoodEntry],
        budgets: [Budget] = []
    ) -> [Recommendation] {
        var recs: [Recommendation] = []
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? now
        let daysLeftInWeek = max(1, 7 - calendar.component(.weekday, from: now) + 1)

        // MARK: Money — over a per-category budget this month
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let monthTransactions = transactions.filter { $0.date >= monthStart }
        for budget in budgets where budget.limit > 0 {
            let spent = monthTransactions.filter { $0.category == budget.category }.reduce(0) { $0 + $1.amount }
            if spent > budget.limit {
                recs.append(Recommendation(
                    domain: .money,
                    message: String(format: "%@ budget: $%.0f over your $%.0f monthly limit.", budget.category.rawValue.capitalized, spent - budget.limit, budget.limit),
                    priority: 85
                ))
            }
        }

        // MARK: Money — over/near weekly spending limit
        let weekSpend = transactions.filter { $0.date >= weekStart }.reduce(0) { $0 + $1.amount }
        if goals.weeklySpendLimit > 0 {
            if weekSpend > goals.weeklySpendLimit {
                let over = weekSpend - goals.weeklySpendLimit
                recs.append(Recommendation(
                    domain: .money,
                    message: String(format: "You're $%.0f over your $%.0f weekly spending limit.", over, goals.weeklySpendLimit),
                    priority: 90
                ))
            } else if weekSpend >= goals.weeklySpendLimit * 0.85 {
                let remaining = goals.weeklySpendLimit - weekSpend
                recs.append(Recommendation(
                    domain: .money,
                    message: String(format: "$%.0f left before you hit your weekly spending limit.", remaining),
                    priority: 60
                ))
            }
        }

        // MARK: Fitness — steps today
        let todaySteps = bodyMetrics.first { calendar.isDateInToday($0.date) }?.steps
        if goals.dailyStepGoal > 0 {
            if let steps = todaySteps {
                if steps < goals.dailyStepGoal && hour >= 17 {
                    let remaining = goals.dailyStepGoal - steps
                    recs.append(Recommendation(
                        domain: .fitness,
                        message: "\(remaining) more steps to hit today's \(goals.dailyStepGoal)-step goal.",
                        priority: 55
                    ))
                }
            } else if hour >= 12 {
                recs.append(Recommendation(
                    domain: .fitness,
                    message: "No step data yet today — connect Health or log a walk to track toward your goal.",
                    priority: 30
                ))
            }
        }

        // MARK: Fitness — weekly workout pace
        let weekWorkouts = workouts.filter { $0.date >= weekStart }.count
        if goals.weeklyWorkoutGoal > 0 && weekWorkouts < goals.weeklyWorkoutGoal {
            let remaining = goals.weeklyWorkoutGoal - weekWorkouts
            if remaining >= daysLeftInWeek {
                recs.append(Recommendation(
                    domain: .fitness,
                    message: "\(remaining) workout\(remaining == 1 ? "" : "s") needed in the next \(daysLeftInWeek) day\(daysLeftInWeek == 1 ? "" : "s") to hit your weekly goal of \(goals.weeklyWorkoutGoal).",
                    priority: 65
                ))
            } else if remaining > 0 {
                recs.append(Recommendation(
                    domain: .fitness,
                    message: "\(remaining) more workout\(remaining == 1 ? "" : "s") this week to reach your goal of \(goals.weeklyWorkoutGoal).",
                    priority: 35
                ))
            }
        }

        // MARK: Tasks — overdue
        let overdueTasks = tasks.filter { !$0.isCompleted && ($0.dueDate.map { $0 < today } ?? false) }
        if !overdueTasks.isEmpty {
            recs.append(Recommendation(
                domain: .tasks,
                message: "\(overdueTasks.count) overdue task\(overdueTasks.count == 1 ? "" : "s") — \(overdueTasks.first?.title ?? "one") among them.",
                priority: 80
            ))
        }

        // MARK: Tasks — today's pace toward the daily goal
        let completedToday = tasks.filter { $0.isCompleted && $0.completedDate != nil && calendar.isDateInToday($0.completedDate!) }.count
        if goals.dailyTaskGoal > 0 && completedToday < goals.dailyTaskGoal && hour >= 15 {
            let remaining = goals.dailyTaskGoal - completedToday
            recs.append(Recommendation(
                domain: .tasks,
                message: "\(remaining) more task\(remaining == 1 ? "" : "s") to hit today's goal of \(goals.dailyTaskGoal) completed.",
                priority: 45
            ))
        }

        // MARK: Habits — streak at risk
        for habit in habits where habit.isActive {
            let habitCheckins = checkins.filter { $0.habit?.id == habit.id }
            guard let lastCheckin = habitCheckins.map(\.date).max() else { continue }
            let daysSince = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastCheckin), to: today).day ?? 0
            // Only flag habits with real history — a habit checked in on at least 3 distinct days.
            let distinctDays = Set(habitCheckins.map { calendar.startOfDay(for: $0.date) }).count
            if daysSince >= 2 && distinctDays >= 3 {
                recs.append(Recommendation(
                    domain: .habits,
                    message: "'\(habit.name)' streak is at risk — last logged \(daysSince) days ago.",
                    priority: 70
                ))
                break // one streak warning at a time is plenty
            }
        }

        // MARK: Mood — no recent check-in
        let lastMood = moodEntries.map(\.date).max()
        let daysSinceMood = lastMood.map { calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: today).day ?? 0 }
        if daysSinceMood == nil || daysSinceMood! >= 3 {
            recs.append(Recommendation(
                domain: .mood,
                message: "You haven't checked in on mood in a few days — worth a moment.",
                priority: 25
            ))
        }

        // MARK: Cross-domain — do workouts actually correlate with getting more done?
        // A real (if simple) pattern check rather than a generic "you're doing great."
        // Needs at least 5 days of each kind in the last 30 to say anything meaningful.
        if let correlation = workoutTaskCorrelation(tasks: tasks, workouts: workouts, calendar: calendar, today: today) {
            recs.append(correlation)
        }

        return recs.sorted { $0.priority > $1.priority }
    }

    private static func workoutTaskCorrelation(tasks: [TaskItem], workouts: [Workout], calendar: Calendar, today: Date) -> Recommendation? {
        let windowStart = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        let workoutDays = Set(workouts.filter { $0.date >= windowStart }.map { calendar.startOfDay(for: $0.date) })
        guard workoutDays.count >= 5 else { return nil }

        let completedByDay = Dictionary(
            grouping: tasks.filter { $0.isCompleted && $0.completedDate != nil && $0.completedDate! >= windowStart },
            by: { calendar.startOfDay(for: $0.completedDate!) }
        ).mapValues { $0.count }

        var daysInWindow: [Date] = []
        var cursor = windowStart
        while cursor <= today {
            daysInWindow.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? today
        }

        let workoutDayCounts = daysInWindow.filter { workoutDays.contains($0) }.map { completedByDay[$0] ?? 0 }
        let restDayCounts = daysInWindow.filter { !workoutDays.contains($0) }.map { completedByDay[$0] ?? 0 }
        guard restDayCounts.count >= 5 else { return nil }

        let avgWorkout = Double(workoutDayCounts.reduce(0, +)) / Double(workoutDayCounts.count)
        let avgRest = Double(restDayCounts.reduce(0, +)) / Double(restDayCounts.count)

        guard avgWorkout > 0, avgWorkout >= avgRest * 1.2, avgWorkout - avgRest >= 0.5 else { return nil }

        return Recommendation(
            domain: .fitness,
            message: String(format: "You complete about %.1f more tasks on days you work out (%.1f vs %.1f avg) — worth noticing.", avgWorkout - avgRest, avgWorkout, avgRest),
            priority: 20
        )
    }
}
