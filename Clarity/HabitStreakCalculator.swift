import Foundation

// MARK: - Habit Streak Calculator
// Single source of truth for "current streak" — used to live duplicated in
// CompactHabitCard and EnhancedHabitsTab with slightly different logic.
// Includes a one-day grace: a single missed day doesn't zero out a streak,
// only two in a row does (same idea as Duolingo's streak freeze, just
// automatic rather than a spendable resource).
enum HabitStreakCalculator {
    /// `includingToday: true` treats today as checked-in even if it isn't in
    /// `checkins` yet — needed right after inserting a new HabitCheckin,
    /// since SwiftData's @Query-backed arrays don't reflect an insert
    /// synchronously within the same call stack.
    static func currentStreak(checkins: [HabitCheckin], habitID: UUID, includingToday: Bool = false, asOf referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        var checkinDays = Set(
            checkins.filter { $0.habit?.id == habitID }.map { calendar.startOfDay(for: $0.date) }
        )
        let today = calendar.startOfDay(for: referenceDate)
        if includingToday {
            checkinDays.insert(today)
        }
        guard !checkinDays.isEmpty else { return 0 }

        var streak = 0
        var graceUsed = false
        var dayOffset = checkinDays.contains(today) ? 0 : 1

        // Bounded walk backward from today (or yesterday, if today isn't
        // logged yet) — a habit can't realistically have a multi-year streak
        // that matters here, so 400 days is a safe ceiling against any edge
        // case looping forever.
        while dayOffset < 400 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { break }
            if checkinDays.contains(day) {
                streak += 1
                dayOffset += 1
            } else if !graceUsed && streak > 0 {
                graceUsed = true
                dayOffset += 1
            } else {
                break
            }
        }

        return streak
    }
}
