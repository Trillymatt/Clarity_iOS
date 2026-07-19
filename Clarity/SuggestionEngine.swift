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
    
    // MARK: - Task Suggestions
    
    struct TaskSuggestion: Identifiable {
        let id = UUID()
        let name: String
        let emoji: String
        let icon: String
        let category: TaskCategory
        let reason: String?
    }
    
    /// All possible task suggestions organized by category and context
    private let taskSuggestionsByCategory: [TaskCategory: [TaskSuggestion]] = [
        .work: [
            TaskSuggestion(name: "Clear inbox to zero", emoji: "📧", icon: "envelope.fill", category: .work, reason: nil),
            TaskSuggestion(name: "Review project status", emoji: "📊", icon: "chart.bar.fill", category: .work, reason: nil),
            TaskSuggestion(name: "Schedule team meeting", emoji: "👥", icon: "person.2.fill", category: .work, reason: nil),
            TaskSuggestion(name: "Update documentation", emoji: "📝", icon: "doc.text.fill", category: .work, reason: nil),
            TaskSuggestion(name: "Follow up on pending items", emoji: "📋", icon: "list.bullet", category: .work, reason: nil),
            TaskSuggestion(name: "Prepare presentation", emoji: "🎯", icon: "rectangle.inset.filled", category: .work, reason: nil),
            TaskSuggestion(name: "Review metrics/analytics", emoji: "📈", icon: "chart.line.uptrend.xyaxis", category: .work, reason: nil),
        ],
        .school: [
            TaskSuggestion(name: "Review lecture notes", emoji: "📚", icon: "book.fill", category: .school, reason: nil),
            TaskSuggestion(name: "Start assignment", emoji: "✏️", icon: "pencil", category: .school, reason: nil),
            TaskSuggestion(name: "Study for exam", emoji: "🎓", icon: "graduationcap.fill", category: .school, reason: nil),
            TaskSuggestion(name: "Research topic", emoji: "🔍", icon: "magnifyingglass", category: .school, reason: nil),
            TaskSuggestion(name: "Practice problems", emoji: "🧮", icon: "function", category: .school, reason: nil),
            TaskSuggestion(name: "Meet with study group", emoji: "👨‍🎓", icon: "person.3.fill", category: .school, reason: nil),
            TaskSuggestion(name: "Office hours visit", emoji: "🏫", icon: "building.columns.fill", category: .school, reason: nil),
        ],
        .personal: [
            TaskSuggestion(name: "Meal prep for week", emoji: "🥗", icon: "carrot.fill", category: .personal, reason: nil),
            TaskSuggestion(name: "Call family/friend", emoji: "📞", icon: "phone.fill", category: .personal, reason: nil),
            TaskSuggestion(name: "Schedule appointment", emoji: "📅", icon: "calendar", category: .personal, reason: nil),
            TaskSuggestion(name: "Organize space", emoji: "🏠", icon: "house.fill", category: .personal, reason: nil),
            TaskSuggestion(name: "Self-care time", emoji: "🧘", icon: "figure.mind.and.body", category: .personal, reason: nil),
            TaskSuggestion(name: "Review goals", emoji: "🎯", icon: "target", category: .personal, reason: nil),
            TaskSuggestion(name: "Plan next week", emoji: "📋", icon: "list.bullet.clipboard", category: .personal, reason: nil),
        ]
    ]
    
    /// Day-specific task suggestions
    private func daySpecificTaskSuggestions() -> [TaskSuggestion] {
        let weekday = Calendar.current.component(.weekday, from: Date())
        
        switch weekday {
        case 1: // Sunday
            return [
                TaskSuggestion(name: "Plan week ahead", emoji: "📅", icon: "calendar", category: .personal, reason: "Start your week organized"),
                TaskSuggestion(name: "Meal prep", emoji: "🍱", icon: "takeoutbag.and.cup.and.straw.fill", category: .personal, reason: "Prep for busy weekdays"),
            ]
        case 2: // Monday
            return [
                TaskSuggestion(name: "Set weekly priorities", emoji: "🎯", icon: "target", category: .work, reason: "Fresh start to the week"),
                TaskSuggestion(name: "Review calendar", emoji: "👀", icon: "calendar.badge.clock", category: .work, reason: "Know what's ahead"),
            ]
        case 6: // Friday
            return [
                TaskSuggestion(name: "Week review", emoji: "📊", icon: "chart.bar.fill", category: .work, reason: "Reflect on accomplishments"),
                TaskSuggestion(name: "Clear pending items", emoji: "✅", icon: "checkmark.circle.fill", category: .work, reason: "End week strong"),
            ]
        case 7: // Saturday
            return [
                TaskSuggestion(name: "Errands", emoji: "🛒", icon: "cart.fill", category: .personal, reason: "Weekend to-dos"),
                TaskSuggestion(name: "Connect with friends", emoji: "👋", icon: "hand.wave.fill", category: .personal, reason: "Social time"),
            ]
        default:
            return []
        }
    }
    
    /// Time-of-day specific suggestions
    private func timeBasedTaskSuggestions() -> [TaskSuggestion] {
        let hour = Calendar.current.component(.hour, from: Date())
        
        if hour < 10 { // Morning
            return [
                TaskSuggestion(name: "Plan today's priorities", emoji: "☀️", icon: "sunrise.fill", category: .personal, reason: "Start day with intention"),
            ]
        } else if hour >= 16 { // Afternoon/Evening
            return [
                TaskSuggestion(name: "Review day's progress", emoji: "🌅", icon: "sunset.fill", category: .personal, reason: "End-of-day reflection"),
            ]
        }
        return []
    }
    
    /// Generate personalized task suggestions based on user's data
    /// - Parameters:
    ///   - existingTasks: User's current tasks (to understand their patterns)
    ///   - userProfile: User's profile for focus areas
    /// - Returns: Array of personalized task suggestions
    func generateTaskSuggestions(existingTasks: [TaskItem], userProfile: UserProfile?) -> [TaskSuggestion] {
        var suggestions: [TaskSuggestion] = []
        
        // Seed random with date for consistent daily suggestions
        let calendar = Calendar.current
        let dayComponent = calendar.component(.day, from: Date())
        let monthComponent = calendar.component(.month, from: Date())
        var rng = SeededRandomNumberGenerator(seed: UInt64(dayComponent * 100 + monthComponent))
        
        // 1. Add day-specific suggestions first (priority)
        suggestions.append(contentsOf: daySpecificTaskSuggestions())
        
        // 2. Add time-based suggestions
        suggestions.append(contentsOf: timeBasedTaskSuggestions())
        
        // 3. Analyze user's task patterns
        let incompleteTasks = existingTasks.filter { !$0.isCompleted }
        let categoryCount = Dictionary(grouping: incompleteTasks, by: { $0.category }).mapValues { $0.count }
        
        // Find user's primary category
        let sortedCategories = categoryCount.sorted { $0.value > $1.value }
        let primaryCategory = sortedCategories.first?.key ?? .personal
        
        // 4. Add suggestions weighted toward user's primary category
        if let categorySuggestions = taskSuggestionsByCategory[primaryCategory] {
            // Filter out tasks that are similar to what user already has
            let existingTitles = Set(existingTasks.map { $0.title.lowercased() })
            let filtered = categorySuggestions.filter { suggestion in
                !existingTitles.contains { $0.contains(suggestion.name.lowercased().prefix(10)) }
            }
            
            let withReason = filtered.prefix(3).map { task in
                TaskSuggestion(
                    name: task.name,
                    emoji: task.emoji,
                    icon: task.icon,
                    category: task.category,
                    reason: "Based on your \(primaryCategory.rawValue) focus"
                )
            }
            suggestions.append(contentsOf: withReason)
        }
        
        // 5. Add variety from other categories
        for (category, categoryTasks) in taskSuggestionsByCategory where category != primaryCategory {
            let picked = categoryTasks.shuffled(using: &rng).prefix(1)
            suggestions.append(contentsOf: picked)
        }
        
        // 6. Use focus areas from profile
        if let profile = userProfile {
            for area in profile.focusAreas.prefix(2) {
                let areaLower = area.lowercased()
                
                // Map focus areas to categories
                let matchedCategory: TaskCategory? = if areaLower.contains("career") || areaLower.contains("work") {
                    .work
                } else if areaLower.contains("school") || areaLower.contains("learn") {
                    .school
                } else {
                    .personal
                }
                
                if let cat = matchedCategory, let tasks = taskSuggestionsByCategory[cat] {
                    let areaTask = tasks.shuffled(using: &rng).first.map { task in
                        TaskSuggestion(
                            name: task.name,
                            emoji: task.emoji,
                            icon: task.icon,
                            category: task.category,
                            reason: "Supports your \(area) goal"
                        )
                    }
                    if let task = areaTask {
                        suggestions.append(task)
                    }
                }
            }
        }
        
        // Remove duplicates and shuffle with date-seed
        var seen = Set<String>()
        let unique = suggestions.filter { task in
            let isNew = !seen.contains(task.name)
            seen.insert(task.name)
            return isNew
        }
        
        // Prioritize day/time suggestions, then shuffle the rest
        let priority = unique.filter { $0.reason != nil }
        let nonPriority = unique.filter { $0.reason == nil }.shuffled(using: &rng)
        
        return Array((priority + nonPriority).prefix(8))
    }
}

// MARK: - Seeded Random Number Generator

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
