import Foundation
import SwiftData

// MARK: - Insight Model
// Represents an automatically generated micro-insight about user behavior

@Model
final class Insight {
    var id: UUID
    var type: InsightType
    var message: String
    var date: Date
    var isRead: Bool
    
    init(type: InsightType, message: String, date: Date = Date(), isRead: Bool = false) {
        self.id = UUID()
        self.type = type
        self.message = message
        self.date = date
        self.isRead = isRead
    }
}

// MARK: - Insight Type
enum InsightType: String, Codable {
    case task
    case habit
    case mood
    case finance
    case general
    case correlation // Cross-category insights
}

// MARK: - Insight Generator
class InsightGenerator {
    
    /// Generate task-related insights
    static func generateTaskInsight(completionRate: Double, tasksCompleted: Int) -> String {
        switch completionRate {
        case 0.9...:
            return "🌟 Outstanding week! You completed \(tasksCompleted) tasks."
        case 0.7..<0.9:
            return "💪 Good consistency this week."
        case 0.5..<0.7:
            return "📈 Room to improve - you're halfway there."
        case 0.3..<0.5:
            return "🔄 Let's refocus on priorities."
        default:
            return "🌱 Every journey starts somewhere."
        }
    }
    
    /// Generate habit-related insights
    static func generateHabitInsight(streak: Int, consistency: Double) -> String {
        if streak >= 7 {
            return "🔥 \(streak)-day streak! You're building momentum."
        } else if streak >= 3 {
            return "✨ \(streak) days strong. Keep it going!"
        } else if consistency > 0.7 {
            return "🎯 Strong habit adherence this week."
        } else {
            return "🌟 Small steps lead to big changes."
        }
    }
    
    /// Generate mood-related insights
    static func generateMoodInsight(averageScore: Double, volatility: Double, lowestDay: String?) -> String {
        if volatility > 0.3 {
            if let day = lowestDay {
                return "💭 Your mood dipped on \(day)."
            }
            return "🌊 Lots of ups and downs this week."
        } else if averageScore >= 0.7 {
            return "😊 Consistently positive mood this week."
        } else if averageScore >= 0.5 {
            return "😌 Steady week emotionally."
        } else {
            return "💙 Remember to be kind to yourself."
        }
    }
    
    /// Generate finance-related insights
    static func generateFinanceInsight(spendingRate: Double, topCategory: String?) -> String {
        if spendingRate > 1.2 {
            if let category = topCategory {
                return "💸 You overspent on \(category) this week."
            }
            return "💸 Spending was higher than usual."
        } else if spendingRate < 0.8 {
            return "💰 Great financial awareness this week!"
        } else {
            return "📊 On track with spending."
        }
    }
    
    /// Generate correlation insights (cross-category patterns)
    static func generateCorrelationInsight(taskScore: Double, moodScore: Double) -> String {
        if taskScore > 0.8 && moodScore > 0.7 {
            return "✨ Productivity and mood are aligned!"
        } else if taskScore < 0.4 && moodScore < 0.4 {
            return "💭 Low energy this week - rest might help."
        } else if taskScore > moodScore + 0.3 {
            return "🔄 You're productive but might need self-care."
        }
        return "🌟 Finding your rhythm."
    }
}
