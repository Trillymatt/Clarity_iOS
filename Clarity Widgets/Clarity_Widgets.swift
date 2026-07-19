//
//  Clarity_Widgets.swift
//  Clarity Widgets
//
//  Created by Matthew Norman on 11/29/25.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct ClarityWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClarityEntry {
        ClarityEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ClarityEntry) -> ()) {
        let data = WidgetDataManager.shared.loadWidgetData() ?? .placeholder
        let entry = ClarityEntry(date: Date(), data: data)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClarityEntry>) -> ()) {
        let currentDate = Date()
        let data = WidgetDataManager.shared.loadWidgetData() ?? .placeholder
        
        // Create entries for the next 12 hours, updating every hour
        var entries: [ClarityEntry] = []
        for hourOffset in 0..<12 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = ClarityEntry(date: entryDate, data: data)
            entries.append(entry)
        }

        // Refresh after entries expire
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct ClarityEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// MARK: - Widget Views

struct SmallClarityWidgetView: View {
    var entry: ClarityEntry
    
    var body: some View {
        VStack(spacing: 4) {
            Spacer()
            
            // Score
            Text("\(entry.data.clarityScore)")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
            
            // Label
            Text("Clarity")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            // Tasks
            Text(entry.data.taskCompletionText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
                .padding(.bottom, 8)
        }
    }
}

struct MediumClarityWidgetView: View {
    var entry: ClarityEntry
    
    var completionPercentage: Double {
        guard entry.data.todayTasksTotal > 0 else { return 0 }
        return Double(entry.data.todayTasksCompleted) / Double(entry.data.todayTasksTotal)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left side - Score
            VStack(spacing: 8) {
                Spacer()
                
                Text("\(entry.data.clarityScore)")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                
                Text("Clarity")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1)
                .padding(.vertical, 16)
            
            // Right side - Stats
            VStack(alignment: .leading, spacing: 12) {
                Spacer()
                
                // Tasks
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        Text("Tasks")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Text(entry.data.taskCompletionText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Habit
                if let habitName = entry.data.primaryHabitName {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: entry.data.primaryHabitIcon ?? "star.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                            Text(habitName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        Text("\(entry.data.primaryHabitProgress)/\(entry.data.primaryHabitGoal)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
        }
        .padding(.horizontal, 20)
    }
}

struct LargeClarityWidgetView: View {
    var entry: ClarityEntry

    var taskProgress: Double {
        Double(entry.data.tasksCompletedToday) / Double(max(1, entry.data.dailyTaskGoal))
    }

    var stepProgress: Double {
        Double(entry.data.todaySteps ?? 0) / Double(max(1, entry.data.stepGoal))
    }

    var workoutProgress: Double {
        Double(entry.data.weekWorkouts) / Double(max(1, entry.data.weeklyWorkoutGoal))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jarvis")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Today's Goals")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // Score Badge
                Text("\(entry.data.clarityScore)")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.12))
                    )
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Goal Rings
            HStack(spacing: 16) {
                goalCard(icon: "figure.walk", title: "Steps", value: entry.data.todaySteps.map { "\($0)" } ?? "—", progress: stepProgress, color: .green)
                goalCard(icon: "figure.run", title: "Workouts", value: "\(entry.data.weekWorkouts)/\(entry.data.weeklyWorkoutGoal)", progress: workoutProgress, color: .cyan)
                goalCard(icon: "checkmark.circle.fill", title: "Tasks", value: "\(entry.data.tasksCompletedToday)/\(entry.data.dailyTaskGoal)", progress: taskProgress, color: .blue)
            }
            .padding(.horizontal, 20)

            if entry.data.workoutStreak > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 13))
                    Text("\(entry.data.workoutStreak)-day workout streak")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }

            Spacer()

            // Footer
            Text("Updated \(entry.date, style: .relative)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    private func goalCard(icon: String, title: String, value: String, progress: Double, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 5)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: min(1, progress))
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.08)))
    }
}

// MARK: - Widget Configuration

struct ClarityWidget: Widget {
    let kind: String = "ClarityWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClarityWidgetProvider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Clarity")
        .description("Track your daily progress at a glance")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Entry View with Size Detection

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: ClarityEntry
    
    var body: some View {
        if #available(iOS 17.0, *) {
            Group {
                switch family {
                case .systemSmall:
                    SmallClarityWidgetView(entry: entry)
                case .systemMedium:
                    MediumClarityWidgetView(entry: entry)
                case .systemLarge:
                    LargeClarityWidgetView(entry: entry)
                default:
                    SmallClarityWidgetView(entry: entry)
                }
            }
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.04, blue: 0.1),
                        Color(red: 0.16, green: 0.08, blue: 0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.04, blue: 0.1),
                        Color(red: 0.16, green: 0.08, blue: 0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                switch family {
                case .systemSmall:
                    SmallClarityWidgetView(entry: entry)
                case .systemMedium:
                    MediumClarityWidgetView(entry: entry)
                case .systemLarge:
                    LargeClarityWidgetView(entry: entry)
                default:
                    SmallClarityWidgetView(entry: entry)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    ClarityWidget()
} timeline: {
    ClarityEntry(date: .now, data: .placeholder)
}

#Preview(as: .systemMedium) {
    ClarityWidget()
} timeline: {
    ClarityEntry(date: .now, data: .placeholder)
}

#Preview(as: .systemLarge) {
    ClarityWidget()
} timeline: {
    ClarityEntry(date: .now, data: .placeholder)
}
