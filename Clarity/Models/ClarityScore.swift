import Foundation
import SwiftData

// MARK: - Clarity Score Model
// The core identity metric of the app - measures overall life awareness and alignment

@Model
final class ClarityScore {
    var id: UUID
    var ownerEmail: String
    var date: Date
    var totalScore: Double // 0-100
    
    // Component scores
    var taskScore: Double
    var habitScore: Double
    var moodScore: Double
    var momentScore: Double
    var financeScore: Double
    
    // Metadata
    var trend: ScoreTrend
    var insights: [String]
    
    init(
        ownerEmail: String = "",
        date: Date = Date(),
        taskScore: Double = 0,
        habitScore: Double = 0,
        moodScore: Double = 0,
        momentScore: Double = 0,
        financeScore: Double = 0
    ) {
        self.id = UUID()
        self.ownerEmail = ownerEmail
        self.date = date
        self.taskScore = taskScore
        self.habitScore = habitScore
        self.moodScore = moodScore
        self.momentScore = momentScore
        self.financeScore = financeScore
        self.totalScore = 0
        self.trend = .neutral
        self.insights = []
        
        // Calculate total
        self.calculateTotalScore()
    }
    
    /// Calculate weighted total score
    func calculateTotalScore() {
        let weights: [Double] = [0.30, 0.25, 0.20, 0.15, 0.10]
        let scores = [taskScore, habitScore, moodScore, momentScore, financeScore]
        
        totalScore = zip(scores, weights).reduce(0) { $0 + ($1.0 * $1.1) }
        totalScore = min(100, max(0, totalScore)) // Clamp 0-100
    }
    
    /// Get score state based on total
    var state: ScoreState {
        switch totalScore {
        case 80...100: return .thriving
        case 60..<80: return .growing
        case 40..<60: return .adjusting
        default: return .rebuilding
        }
    }
    
    /// Get state description
    var stateDescription: String {
        switch state {
        case .thriving: return "Thriving"
        case .growing: return "Growing"
        case .adjusting: return "Adjusting"
        case .rebuilding: return "Rebuilding"
        }
    }
    
    /// Get state emoji
    var stateEmoji: String {
        switch state {
        case .thriving: return "🌟"
        case .growing: return "🌱"
        case .adjusting: return "🔄"
        case .rebuilding: return "💜"
        }
    }
}

// MARK: - Score State
enum ScoreState {
    case thriving   // 80-100
    case growing    // 60-79
    case adjusting  // 40-59
    case rebuilding // 0-39
}

// MARK: - Score Trend
enum ScoreTrend: String, Codable {
    case up
    case neutral
    case down
}

// MARK: - Clarity Score Calculator
class ClarityScoreCalculator {
    
    // Weights
    static let taskWeight = 0.30
    static let habitWeight = 0.25
    static let moodWeight = 0.20
    static let momentWeight = 0.15
    static let financeWeight = 0.10
    
    /// Calculate task score (0-100)
    static func calculateTaskScore(tasks: [TaskItem]) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: today)!
        
        // Today's tasks (heavily weighted for immediate feedback)
        let todayTasks = tasks.filter {
            guard let due = $0.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: Date())
        }
        
        // Also include tasks marked for "today" flag
        let todayFlaggedTasks = tasks.filter { $0.isToday && !$0.isCompleted }
        let allTodayTasks = Array(Set(todayTasks + todayFlaggedTasks))
        
        // Weekly tasks for overall progress
        let weekTasks = tasks.filter {
            guard let due = $0.dueDate else { return false }
            return due >= weekStart && due < endOfToday
        }
        
        // Calculate today's completion rate (70% weight)
        var todayScore: Double = 0
        if !allTodayTasks.isEmpty {
            let todayCompleted = allTodayTasks.filter { $0.isCompleted }.count
            todayScore = (Double(todayCompleted) / Double(allTodayTasks.count)) * 70
        } else {
            // If no tasks today, give baseline score
            todayScore = 50
        }
        
        // Calculate weekly completion rate (30% weight)
        var weekScore: Double = 0
        if !weekTasks.isEmpty {
            let weekCompleted = weekTasks.filter { $0.isCompleted }.count
            weekScore = (Double(weekCompleted) / Double(weekTasks.count)) * 30
        }
        
        return min(100, todayScore + weekScore)
    }
    
    /// Calculate habit score (0-100)
    static func calculateHabitScore(habits: [Habit], checkins: [HabitCheckin]) -> Double {
        guard !habits.isEmpty else { return 0 }
        
        let activeHabits = habits.filter { $0.isActive }
        guard !activeHabits.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!
        
        // Today's expected habits
        let todayCheckins = checkins.filter { checkin in
            guard let habitId = checkin.habit?.id else { return false }
            return calendar.isDate(checkin.date, inSameDayAs: Date()) && activeHabits.contains(where: { $0.id == habitId })
        }
        
        // Calculate today's completion (60% weight)
        var todayScore: Double = 0
        if !activeHabits.isEmpty {
            let todayCompleted = todayCheckins.filter { $0.isCompleted }.count
            todayScore = (Double(todayCompleted) / Double(activeHabits.count)) * 60
        }
        
        // Calculate weekly adherence (40% weight)
        var expectedWeeklyCheckins = 0
        for habit in activeHabits {
            let frequency = habit.daysOfWeek.isEmpty ? 7 : habit.daysOfWeek.count
            expectedWeeklyCheckins += frequency
        }
        
        var weekScore: Double = 0
        if expectedWeeklyCheckins > 0 {
            let weekCheckins = checkins.filter { checkin in
                guard let habitId = checkin.habit?.id else { return false }
                return checkin.date >= weekStart && checkin.isCompleted && activeHabits.contains(where: { $0.id == habitId })
            }
            weekScore = (Double(weekCheckins.count) / Double(expectedWeeklyCheckins)) * 40
        }
        
        return min(100, todayScore + weekScore)
    }
    
    /// Calculate mood score (0-100)
    static func calculateMoodScore(moodEntries: [MoodEntry]) -> Double {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date()))!
        
        let weekMoods = moodEntries.filter { $0.date >= weekStart }
        guard !weekMoods.isEmpty else { return 0 }
        
        let avgMood = weekMoods.reduce(0.0) { $0 + $1.moodScore } / Double(weekMoods.count)
        
        // Calculate volatility (stability bonus)
        let variance = weekMoods.reduce(0.0) { sum, entry in
            sum + pow(entry.moodScore - avgMood, 2)
        } / Double(weekMoods.count)
        let stabilityBonus = variance < 0.1 ? 10 : 0
        
        return min(100, (avgMood * 100) + Double(stabilityBonus))
    }
    
    /// Calculate moment score (0-100)
    static func calculateMomentScore(moments: [LifeMoment]) -> Double {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date()))!
        
        let weekMoments = moments.filter { $0.date >= weekStart }
        
        // Frequency (60 points max)
        let frequencyScore = min(60, Double(weekMoments.count) * 12)
        
        // Quality bonus for detailed notes (40 points max)
        let detailedMoments = weekMoments.filter { ($0.note?.count ?? 0) > 20 }.count
        let qualityScore = min(40, Double(detailedMoments) * 13)
        
        return min(100, frequencyScore + qualityScore)
    }
    
    /// Calculate finance score (0-100) - awareness-based
    static func calculateFinanceScore(transactions: [Transaction]) -> Double {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date()))!
        
        let weekTransactions = transactions.filter { $0.date >= weekStart }
        
        // Tracking frequency (50 points)
        let trackingScore = min(50, Double(weekTransactions.count) * 7)
        
        // Categorization (30 points)
        let categorized = weekTransactions.filter { $0.note != nil }.count
        let total = weekTransactions.count
        let categorizationScore = total > 0 ? (Double(categorized) / Double(total)) * 30.0 : 0
        
        // Consistency (20 points) - tracked at least 4 days
        let uniqueDays = Set(weekTransactions.map { calendar.startOfDay(for: $0.date) }).count
        let consistencyScore = uniqueDays >= 4 ? 20.0 : Double(uniqueDays) * 5
        
        return min(100, trackingScore + categorizationScore + consistencyScore)
    }
    
    /// Calculate complete Clarity Score
    static func calculateFullScore(
        tasks: [TaskItem],
        habits: [Habit],
        checkins: [HabitCheckin],
        moodEntries: [MoodEntry],
        moments: [LifeMoment],
        transactions: [Transaction]
    ) -> ClarityScore {
        let taskScore = calculateTaskScore(tasks: tasks)
        let habitScore = calculateHabitScore(habits: habits, checkins: checkins)
        let moodScore = calculateMoodScore(moodEntries: moodEntries)
        let momentScore = calculateMomentScore(moments: moments)
        let financeScore = calculateFinanceScore(transactions: transactions)
        
        let score = ClarityScore(
            taskScore: taskScore,
            habitScore: habitScore,
            moodScore: moodScore,
            momentScore: momentScore,
            financeScore: financeScore
        )
        
        score.calculateTotalScore()
        return score
    }
}
