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
        moodEntries: [MoodEntry]
    ) -> [Recommendation] {
        var recs: [Recommendation] = []
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? now
        let daysLeftInWeek = max(1, 7 - calendar.component(.weekday, from: now) + 1)

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

        return recs.sorted { $0.priority > $1.priority }
    }
}
