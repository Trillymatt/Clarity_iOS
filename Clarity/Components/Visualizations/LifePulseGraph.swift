import SwiftUI
import Charts

// MARK: - Life Pulse Graph
struct LifePulseGraph: View {
    let pulseData: [LifePulseDataPoint]
    
    var maxValue: Double {
        let maxCompletions = pulseData.map { $0.taskCount + $0.habitCount }.max() ?? 10
        // Scale completions by 10 to make them visible alongside score (0-100)
        let scaledMaxCompletions = Double(maxCompletions) * 10 * 1.2
        return max(scaledMaxCompletions, 100)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Life Pulse")
                        .font(.clarityTitle)
                    
                    Text("Daily activity & overall score")
                        .font(.clarityCaption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Legend
                HStack(spacing: 16) {
                    LegendItem(color: .clarityTeal, label: "Completions")
                    LegendItem(color: .clarityPurple, label: "Clarity Score")
                }
            }
            
            // Chart
            if !pulseData.isEmpty {
                Chart {
                    // Series 1: Completions (scaled by 10 for visibility)
                    ForEach(pulseData) { point in
                        AreaMark(
                            x: .value("Day", point.day),
                            y: .value("Value", Double(point.taskCount + point.habitCount) * 10)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.clarityTeal.opacity(0.3),
                                    Color.clarityTeal.opacity(0.1),
                                    Color.clarityTeal.opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.monotone)
                        
                        LineMark(
                            x: .value("Day", point.day),
                            y: .value("Value", Double(point.taskCount + point.habitCount) * 10),
                            series: .value("Series", "Completions")
                        )
                        .foregroundStyle(Color.clarityTeal)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .interpolationMethod(.monotone)
                        
                        PointMark(
                            x: .value("Day", point.day),
                            y: .value("Value", Double(point.taskCount + point.habitCount) * 10)
                        )
                        .foregroundStyle(Color.clarityTeal)
                        .symbolSize(80)
                    }
                    
                    // Series 2: Clarity Score (0-100 scale)
                    ForEach(pulseData) { point in
                        LineMark(
                            x: .value("Day", point.day),
                            y: .value("Value", point.clarityScore),
                            series: .value("Series", "Score")
                        )
                        .foregroundStyle(Color.clarityPurple)
                        .lineStyle(StrokeStyle(lineWidth: 3, dash: [8, 4]))
                        .interpolationMethod(.monotone)
                        
                        PointMark(
                            x: .value("Day", point.day),
                            y: .value("Value", point.clarityScore)
                        )
                        .foregroundStyle(Color.clarityPurple)
                        .symbol {
                            Circle()
                                .strokeBorder(Color.clarityPurple, lineWidth: 2)
                                .background(Circle().fill(Color.clarityBackground))
                                .frame(width: 10, height: 10)
                        }
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                            .foregroundStyle(.secondary.opacity(0.2))
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYScale(domain: 0...maxValue)
                
                // Bottom note
                HStack {
                    Spacer()
                    Text("Completions scaled ×10 for visibility")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                .padding(.top, 4)
            } else {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Complete tasks and habits to see your pulse")
                        .font(.clarityCaption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color.clarityCard)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Legend Item
struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Data Point
struct LifePulseDataPoint: Identifiable {
    let id = UUID()
    let day: String
    let taskCount: Int
    let habitCount: Int
    let clarityScore: Double
}

// MARK: - Data Generator
class LifePulseDataGenerator {
    static func generateWeekData(
        tasks: [TaskItem],
        checkins: [HabitCheckin],
        habits: [Habit],
        moodEntries: [MoodEntry],
        moments: [LifeMoment],
        transactions: [Transaction]
    ) -> [LifePulseDataPoint] {
        generateData(days: 7, strideBy: 1, tasks: tasks, checkins: checkins, habits: habits, moodEntries: moodEntries, moments: moments, transactions: transactions)
    }

    /// General-purpose version behind generateWeekData — `days` is the
    /// lookback window, `strideBy` samples every Nth day (1 = daily, 7 =
    /// weekly) so a year-long view doesn't try to plot 365 points.
    static func generateData(
        days: Int,
        strideBy: Int,
        tasks: [TaskItem],
        checkins: [HabitCheckin],
        habits: [Habit],
        moodEntries: [MoodEntry],
        moments: [LifeMoment],
        transactions: [Transaction]
    ) -> [LifePulseDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        var dataPoints: [LifePulseDataPoint] = []
        var hasData = false

        let offsets = stride(from: days - 1, through: 0, by: -strideBy)
        for dayOffset in offsets {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            // Day label
            let dayLabel: String
            if dayOffset == 0 {
                dayLabel = "Today"
            } else if strideBy >= 7 {
                dayLabel = date.formatted(.dateTime.month(.abbreviated).day())
            } else {
                let weekdayIndex = calendar.component(.weekday, from: date) - 1
                dayLabel = calendar.shortWeekdaySymbols[weekdayIndex]
            }

            // Count completed tasks
            let completedTasks = tasks.filter {
                guard let completedDate = $0.completedDate else { return false }
                return $0.isCompleted && completedDate >= dayStart && completedDate < dayEnd
            }.count
            if completedTasks > 0 { hasData = true }

            // Count completed habit check-ins
            let completedHabits = checkins.filter {
                $0.isCompleted && $0.date >= dayStart && $0.date < dayEnd
            }.count
            if completedHabits > 0 { hasData = true }

            // Calculate day's clarity score
            let dayTasks = tasks.filter {
                guard let dueDate = $0.dueDate else { return false }
                return dueDate >= dayStart && dueDate < dayEnd
            }
            let dayMoods = moodEntries.filter { $0.date >= dayStart && $0.date < dayEnd }
            let dayMoments = moments.filter { $0.date >= dayStart && $0.date < dayEnd }
            let dayTransactions = transactions.filter { $0.date >= dayStart && $0.date < dayEnd }
            let dayCheckins = checkins.filter { $0.date >= dayStart && $0.date < dayEnd }

            let clarityScore = ClarityScoreCalculator.calculateFullScore(
                tasks: dayTasks,
                habits: habits,
                checkins: dayCheckins,
                moodEntries: dayMoods,
                moments: dayMoments,
                transactions: dayTransactions
            )
            if clarityScore.totalScore > 0 { hasData = true }

            dataPoints.append(LifePulseDataPoint(
                day: dayLabel,
                taskCount: completedTasks,
                habitCount: completedHabits,
                clarityScore: clarityScore.totalScore
            ))
        }

        return hasData ? dataPoints : []
    }
}

// MARK: - Preview
#Preview {
    let mockData = [
        LifePulseDataPoint(day: "Mon", taskCount: 3, habitCount: 5, clarityScore: 65),
        LifePulseDataPoint(day: "Tue", taskCount: 5, habitCount: 4, clarityScore: 72),
        LifePulseDataPoint(day: "Wed", taskCount: 2, habitCount: 6, clarityScore: 58),
        LifePulseDataPoint(day: "Thu", taskCount: 7, habitCount: 7, clarityScore: 85),
        LifePulseDataPoint(day: "Fri", taskCount: 4, habitCount: 5, clarityScore: 70),
        LifePulseDataPoint(day: "Sat", taskCount: 6, habitCount: 3, clarityScore: 68),
        LifePulseDataPoint(day: "Today", taskCount: 3, habitCount: 4, clarityScore: 62)
    ]
    
    LifePulseGraph(pulseData: mockData)
        .padding()
}
