import Foundation

// MARK: - Habit Templates
// Quick-start presets for AddHabitSheet so building a new habit doesn't
// always start from a blank text field. Icons are deliberately limited to
// AddHabitSheet's existing icon picker set so a tapped template always shows
// as selected in that grid.

struct HabitTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let emoji: String
    let goalPerDay: Int
    /// 0-indexed Sunday...Saturday, matching AddHabitSheet's `days` convention.
    let daysOfWeek: [Int]
}

enum HabitTemplates {
    static let all: [HabitTemplate] = [
        HabitTemplate(name: "Drink Water", icon: "drop.fill", emoji: "💧", goalPerDay: 8, daysOfWeek: Array(0...6)),
        HabitTemplate(name: "Morning Run", icon: "figure.run", emoji: "🏃", goalPerDay: 1, daysOfWeek: Array(0...6)),
        HabitTemplate(name: "Read 10 Pages", icon: "book.fill", emoji: "📚", goalPerDay: 1, daysOfWeek: Array(0...6)),
        HabitTemplate(name: "Sleep 8 Hours", icon: "bed.double.fill", emoji: "😴", goalPerDay: 1, daysOfWeek: Array(0...6)),
        HabitTemplate(name: "Eat Mindfully", icon: "leaf.fill", emoji: "🌿", goalPerDay: 1, daysOfWeek: Array(0...6)),
        HabitTemplate(name: "Gratitude Note", icon: "heart.fill", emoji: "❤️", goalPerDay: 1, daysOfWeek: Array(0...6)),
        HabitTemplate(name: "Strength Training", icon: "flame.fill", emoji: "🔥", goalPerDay: 1, daysOfWeek: [1, 3, 5]),
        HabitTemplate(name: "Meditate", icon: "star.fill", emoji: "⭐", goalPerDay: 1, daysOfWeek: Array(0...6))
    ]
}
