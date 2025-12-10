import Foundation
import SwiftData

/// Generates dynamic, context-aware suggestions based on user's existing data
class SuggestionEngine {
    static let shared = SuggestionEngine()
    
    // MARK: - Context Data
    
    struct UserContextData {
        var existingHabits: [String] = []
        var habitCategories: Set<String> = [] // "health", "mindfulness", "productivity", "learning"
        var recentMomentTypes: [MomentType] = []
        var daysSinceLastGratitude: Int = 999
        var taskCategoryBreakdown: [String: Int] = [:]
        var spendingByCategory: [TransactionCategory: Double] = [:]
        var averageTransactionAmount: Double = 0
        var focusAreas: [String] = []
    }
    
    // MARK: - Habit Suggestions
    
    struct HabitSuggestion: Identifiable {
        let id = UUID()
        let name: String
        let emoji: String
        let icon: String
        let category: String
        let reason: String?
    }
    
    /// All possible habit suggestions organized by category
    private let allHabitSuggestions: [String: [HabitSuggestion]] = [
        "health": [
            HabitSuggestion(name: "Drink Water", emoji: "💧", icon: "drop.fill", category: "health", reason: nil),
            HabitSuggestion(name: "Morning Exercise", emoji: "🏃", icon: "figure.run", category: "health", reason: nil),
            HabitSuggestion(name: "Healthy Sleep", emoji: "😴", icon: "bed.double.fill", category: "health", reason: nil),
            HabitSuggestion(name: "Stretch", emoji: "🤸", icon: "figure.flexibility", category: "health", reason: nil),
            HabitSuggestion(name: "Take Vitamins", emoji: "💊", icon: "pills.fill", category: "health", reason: nil),
            HabitSuggestion(name: "Walk 10k Steps", emoji: "👟", icon: "figure.walk", category: "health", reason: nil),
        ],
        "mindfulness": [
            HabitSuggestion(name: "Meditation", emoji: "🧘", icon: "figure.mind.and.body", category: "mindfulness", reason: nil),
            HabitSuggestion(name: "Gratitude Journal", emoji: "📝", icon: "heart.text.square.fill", category: "mindfulness", reason: nil),
            HabitSuggestion(name: "Deep Breathing", emoji: "🌬️", icon: "wind", category: "mindfulness", reason: nil),
            HabitSuggestion(name: "Digital Detox", emoji: "📵", icon: "iphone.slash", category: "mindfulness", reason: nil),
            HabitSuggestion(name: "Morning Quiet Time", emoji: "🌅", icon: "sun.horizon.fill", category: "mindfulness", reason: nil),
        ],
        "learning": [
            HabitSuggestion(name: "Read Daily", emoji: "📚", icon: "book.fill", category: "learning", reason: nil),
            HabitSuggestion(name: "Learn Something New", emoji: "🎓", icon: "graduationcap.fill", category: "learning", reason: nil),
            HabitSuggestion(name: "Practice Skill", emoji: "🎯", icon: "target", category: "learning", reason: nil),
            HabitSuggestion(name: "Listen to Podcast", emoji: "🎧", icon: "headphones", category: "learning", reason: nil),
            HabitSuggestion(name: "Language Practice", emoji: "🗣️", icon: "character.bubble.fill", category: "learning", reason: nil),
        ],
        "productivity": [
            HabitSuggestion(name: "Plan Tomorrow", emoji: "📋", icon: "list.bullet", category: "productivity", reason: nil),
            HabitSuggestion(name: "Time Block", emoji: "⏰", icon: "clock.fill", category: "productivity", reason: nil),
            HabitSuggestion(name: "Focus Session", emoji: "🎯", icon: "scope", category: "productivity", reason: nil),
            HabitSuggestion(name: "Review Goals", emoji: "✅", icon: "checkmark.circle.fill", category: "productivity", reason: nil),
            HabitSuggestion(name: "Inbox Zero", emoji: "📧", icon: "envelope.fill", category: "productivity", reason: nil),
        ]
    ]
    
    func generateHabitSuggestions(context: UserContextData) -> [HabitSuggestion] {
        var suggestions: [HabitSuggestion] = []
        
        // Find which categories the user is missing
        let allCategories = Set(allHabitSuggestions.keys)
        let missingCategories = allCategories.subtracting(context.habitCategories)
        
        // Prioritize suggestions from missing categories
        for category in missingCategories {
            if let categorySuggestions = allHabitSuggestions[category] {
                // Filter out habits user already has (fuzzy match)
                let filtered = categorySuggestions.filter { suggestion in
                    !context.existingHabits.contains { existing in
                        existing.lowercased().contains(suggestion.name.lowercased()) ||
                        suggestion.name.lowercased().contains(existing.lowercased())
                    }
                }
                
                // Add with a reason
                let withReason = filtered.prefix(2).map { habit in
                    HabitSuggestion(
                        name: habit.name,
                        emoji: habit.emoji,
                        icon: habit.icon,
                        category: habit.category,
                        reason: "Build a \(category) habit"
                    )
                }
                suggestions.append(contentsOf: withReason)
            }
        }
        
        // Also add some from focus areas if specified
        for area in context.focusAreas {
            let areaKey = area.lowercased()
            if let areaSuggestions = allHabitSuggestions[areaKey] {
                let filtered = areaSuggestions.filter { suggestion in
                    !context.existingHabits.contains { existing in
                        existing.lowercased().contains(suggestion.name.lowercased())
                    }
                }
                suggestions.append(contentsOf: filtered.prefix(1))
            }
        }
        
        // Shuffle and limit
        suggestions.shuffle()
        return Array(suggestions.prefix(6))
    }
    
    // MARK: - Moment Suggestions
    
    struct MomentSuggestion: Identifiable {
        let id = UUID()
        let title: String
        let emoji: String
        let icon: String
        let subtitle: String
        let type: MomentType
        let mood: Int
        let isPriority: Bool
    }
    
    /// All possible moment prompts
    private let allMomentSuggestions: [MomentSuggestion] = [
        MomentSuggestion(title: "Today's Win", emoji: "🏆", icon: "trophy.fill", subtitle: "Something you accomplished", type: .win, mood: 4, isPriority: false),
        MomentSuggestion(title: "Grateful For", emoji: "🙏", icon: "heart.fill", subtitle: "What made you smile?", type: .gratitude, mood: 4, isPriority: false),
        MomentSuggestion(title: "New Learning", emoji: "💡", icon: "lightbulb.fill", subtitle: "Something you discovered", type: .other, mood: 3, isPriority: false),
        MomentSuggestion(title: "Kind Act", emoji: "💝", icon: "gift.fill", subtitle: "How you helped someone", type: .connection, mood: 4, isPriority: false),
        MomentSuggestion(title: "Proud Moment", emoji: "⭐", icon: "star.fill", subtitle: "Something you're proud of", type: .win, mood: 4, isPriority: false),
        MomentSuggestion(title: "Connection", emoji: "🤝", icon: "person.2.fill", subtitle: "A meaningful conversation", type: .connection, mood: 4, isPriority: false),
        MomentSuggestion(title: "Challenge", emoji: "⚡", icon: "bolt.fill", subtitle: "Something difficult you faced", type: .challenge, mood: 2, isPriority: false),
        MomentSuggestion(title: "Reflection", emoji: "💭", icon: "cloud.sun.fill", subtitle: "A thought or realization", type: .other, mood: 3, isPriority: false),
    ]
    
    /// Day-specific moment prompts
    private func daySpecificPrompts() -> [MomentSuggestion] {
        let weekday = Calendar.current.component(.weekday, from: Date())
        
        switch weekday {
        case 1: // Sunday
            return [MomentSuggestion(title: "Week Ahead", emoji: "🎯", icon: "calendar", subtitle: "What's your focus this week?", type: .other, mood: 3, isPriority: true)]
        case 2: // Monday
            return [MomentSuggestion(title: "Fresh Start", emoji: "🌅", icon: "sunrise.fill", subtitle: "Set your intention for the week", type: .win, mood: 4, isPriority: true)]
        case 6: // Friday
            return [MomentSuggestion(title: "Weekly Wins", emoji: "🎉", icon: "party.popper.fill", subtitle: "What went well this week?", type: .win, mood: 4, isPriority: true)]
        case 7: // Saturday
            return [MomentSuggestion(title: "Weekend Joy", emoji: "☀️", icon: "sun.max.fill", subtitle: "Something fun you did today", type: .other, mood: 4, isPriority: true)]
        default:
            return []
        }
    }
    
    func generateMomentSuggestions(context: UserContextData) -> [MomentSuggestion] {
        var suggestions: [MomentSuggestion] = []
        
        // Add day-specific prompts first (priority)
        suggestions.append(contentsOf: daySpecificPrompts())
        
        // If user hasn't logged gratitude recently, prioritize it
        if context.daysSinceLastGratitude >= 2 {
            let gratitudePrompt = MomentSuggestion(
                title: "Grateful For",
                emoji: "🙏",
                icon: "heart.fill",
                subtitle: "Take a moment to appreciate something",
                type: .gratitude,
                mood: 4,
                isPriority: true
            )
            suggestions.insert(gratitudePrompt, at: 0)
        }
        
        // Find underrepresented moment types
        let recentTypeCounts = Dictionary(grouping: context.recentMomentTypes, by: { $0 }).mapValues { $0.count }
        let allTypes: [MomentType] = [.win, .gratitude, .connection, .challenge, .other]
        let underrepresentedTypes = allTypes.filter { recentTypeCounts[$0, default: 0] == 0 }
        
        // Add suggestions for underrepresented types
        for type in underrepresentedTypes.prefix(2) {
            if let suggestion = allMomentSuggestions.first(where: { $0.type == type }) {
                let prioritized = MomentSuggestion(
                    title: suggestion.title,
                    emoji: suggestion.emoji,
                    icon: suggestion.icon,
                    subtitle: suggestion.subtitle,
                    type: suggestion.type,
                    mood: suggestion.mood,
                    isPriority: true
                )
                suggestions.append(prioritized)
            }
        }
        
        // Fill remaining with general suggestions
        let remaining = allMomentSuggestions.filter { suggestion in
            !suggestions.contains { $0.type == suggestion.type && $0.title == suggestion.title }
        }
        suggestions.append(contentsOf: remaining.shuffled().prefix(6 - suggestions.count))
        
        // Sort: priority first, then shuffle the rest
        let priority = suggestions.filter { $0.isPriority }
        let nonPriority = suggestions.filter { !$0.isPriority }.shuffled()
        
        return Array((priority + nonPriority).prefix(8))
    }
    
    // MARK: - Finance Suggestions
    
    struct FinanceSuggestion: Identifiable {
        let id = UUID()
        let emoji: String
        let title: String
        let amount: Double
        let category: TransactionCategory
        let reason: String?
    }
    
    /// Default transaction suggestions
    private let defaultFinanceSuggestions: [FinanceSuggestion] = [
        FinanceSuggestion(emoji: "☕", title: "Coffee", amount: 6, category: .food, reason: nil),
        FinanceSuggestion(emoji: "🍽️", title: "Lunch", amount: 15, category: .food, reason: nil),
        FinanceSuggestion(emoji: "🛒", title: "Groceries", amount: 50, category: .food, reason: nil),
        FinanceSuggestion(emoji: "🚗", title: "Gas", amount: 40, category: .transport, reason: nil),
        FinanceSuggestion(emoji: "💊", title: "Pharmacy", amount: 20, category: .other, reason: nil),
        FinanceSuggestion(emoji: "🎬", title: "Entertainment", amount: 20, category: .entertainment, reason: nil),
    ]
    
    /// Time-based suggestions (1st of month = rent, etc.)
    private func timeBasedSuggestions() -> [FinanceSuggestion] {
        let day = Calendar.current.component(.day, from: Date())
        
        if day <= 5 {
            return [
                FinanceSuggestion(emoji: "🏠", title: "Rent/Mortgage", amount: 0, category: .bills, reason: "Monthly expense"),
                FinanceSuggestion(emoji: "📱", title: "Phone Bill", amount: 80, category: .bills, reason: "Monthly bill"),
            ]
        } else if day >= 25 {
            return [
                FinanceSuggestion(emoji: "💳", title: "Credit Card", amount: 0, category: .other, reason: "End of month"),
            ]
        }
        
        return []
    }
    
    func generateFinanceSuggestions(context: UserContextData) -> [FinanceSuggestion] {
        var suggestions: [FinanceSuggestion] = []
        
        // Add time-based suggestions first
        suggestions.append(contentsOf: timeBasedSuggestions())
        
        // Personalize amounts based on user's average (for future use)
        _ = context.averageTransactionAmount > 0 ? context.averageTransactionAmount : 20
        
        // Find most common categories (for future use)
        _ = context.spendingByCategory.sorted { $0.value > $1.value }.prefix(2).map { $0.key }
        
        // Add personalized defaults
        var defaults = defaultFinanceSuggestions.map { suggestion in
            // Adjust amount if user has data for this category
            if let categoryAvg = context.spendingByCategory[suggestion.category] {
                let personalizedAmount = categoryAvg / 5 // Rough estimate per transaction
                return FinanceSuggestion(
                    emoji: suggestion.emoji,
                    title: suggestion.title,
                    amount: max(5, min(personalizedAmount, 100)), // Clamp to reasonable range
                    category: suggestion.category,
                    reason: suggestion.reason
                )
            }
            return suggestion
        }
        
        // Shuffle and combine
        defaults.shuffle()
        suggestions.append(contentsOf: defaults.prefix(6 - suggestions.count))
        
        return Array(suggestions.prefix(6))
    }
    
    // MARK: - Context Building Helpers
    
    /// Categorize a habit by name
    func categorizeHabit(_ habitName: String) -> String {
        let name = habitName.lowercased()
        
        if name.contains("water") || name.contains("exercise") || name.contains("sleep") || 
           name.contains("walk") || name.contains("run") || name.contains("stretch") ||
           name.contains("vitamin") || name.contains("health") {
            return "health"
        }
        if name.contains("meditat") || name.contains("gratitude") || name.contains("journal") ||
           name.contains("breath") || name.contains("mindful") || name.contains("quiet") {
            return "mindfulness"
        }
        if name.contains("read") || name.contains("learn") || name.contains("study") ||
           name.contains("podcast") || name.contains("language") || name.contains("skill") {
            return "learning"
        }
        if name.contains("plan") || name.contains("goal") || name.contains("focus") ||
           name.contains("time") || name.contains("inbox") || name.contains("review") {
            return "productivity"
        }
        
        return "other"
    }
}
