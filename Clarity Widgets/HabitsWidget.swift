//
//  HabitsWidget.swift
//  Clarity Widgets
//
//  Created by Matthew Norman on 11/29/25.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Views

struct SmallHabitsWidgetView: View {
    var entry: ClarityEntry
    
    var primaryHabit: WidgetHabit? {
        entry.data.activeHabits.first
    }
    
    var progress: Double {
        guard let habit = primaryHabit, habit.goal > 0 else { return 0 }
        return Double(habit.progress) / Double(habit.goal)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text("Habits")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            if let habit = primaryHabit {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.white, lineWidth: 8)
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2) {
                        Image(systemName: habit.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                
                // Habit name
                Text(habit.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Image(systemName: "star.slash")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.4))
                Text("No habits")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(14)
    }
}

struct MediumHabitsWidgetView: View {
    var entry: ClarityEntry
    
    var topHabits: [WidgetHabit] {
        Array(entry.data.activeHabits.prefix(2))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text("Today's Habits")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            if topHabits.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "star.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                    Text("No active habits")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // Habit cards
                HStack(spacing: 12) {
                    ForEach(topHabits, id: \.id) { habit in
                        HabitCardView(habit: habit)
                    }
                }
                
                Spacer()
            }
        }
        .padding(16)
    }
}

struct LargeHabitsWidgetView: View {
    var entry: ClarityEntry
    
    var habits: [WidgetHabit] {
        Array(entry.data.activeHabits.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text("Today's Habits")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Active count
                Text("\(habits.count) active")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                    )
            }
            
            if habits.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "star.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.5))
                    Text("No active habits")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // Habit list
                VStack(spacing: 12) {
                    ForEach(habits, id: \.id) { habit in
                        HabitRowView(habit: habit)
                    }
                }
                
                Spacer()
            }
            
            // Footer
            Text("Updated \(entry.date, style: .relative)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(18)
    }
}

// MARK: - Habit Components

struct HabitCardView: View {
    let habit: WidgetHabit
    
    var progress: Double {
        guard habit.goal > 0 else { return 0 }
        return Double(habit.progress) / Double(habit.goal)
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.white, lineWidth: 6)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Image(systemName: habit.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            
            // Habit info
            VStack(spacing: 2) {
                Text(habit.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text("\(habit.progress)/\(habit.goal)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}

struct HabitRowView: View {
    let habit: WidgetHabit
    
    var progress: Double {
        guard habit.goal > 0 else { return 0 }
        return Double(habit.progress) / Double(habit.goal)
    }
    
    var progressColor: Color {
        if progress >= 1.0 { return Color.green }
        if progress >= 0.5 { return Color.white }
        return Color.orange
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(progressColor, lineWidth: 4)
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: habit.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Habit details
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text("\(habit.progress)/\(habit.goal)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(progressColor)
                                .frame(width: geometry.size.width * progress, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
            
            Spacer(minLength: 0)
            
            // Percentage
            Text("\(Int(progress * 100))%")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(minWidth: 45, alignment: .trailing)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(progress >= 1.0 ? 0.15 : 0.08))
        )
    }
}

// MARK: - Widget Configuration

struct HabitsWidget: Widget {
    let kind: String = "HabitsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClarityWidgetProvider()) { entry in
            HabitsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Habits")
        .description("Track your daily habits")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Entry View with Size Detection

struct HabitsWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: ClarityEntry
    
    var body: some View {
        if #available(iOS 17.0, *) {
            Group {
                switch family {
                case .systemSmall:
                    SmallHabitsWidgetView(entry: entry)
                case .systemMedium:
                    MediumHabitsWidgetView(entry: entry)
                case .systemLarge:
                    LargeHabitsWidgetView(entry: entry)
                default:
                    SmallHabitsWidgetView(entry: entry)
                }
            }
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [
                        Color(red: 0.9, green: 0.5, blue: 0.7),
                        Color(red: 0.7, green: 0.3, blue: 0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.9, green: 0.5, blue: 0.7),
                        Color(red: 0.7, green: 0.3, blue: 0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                switch family {
                case .systemSmall:
                    SmallHabitsWidgetView(entry: entry)
                case .systemMedium:
                    MediumHabitsWidgetView(entry: entry)
                case .systemLarge:
                    LargeHabitsWidgetView(entry: entry)
                default:
                    SmallHabitsWidgetView(entry: entry)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    HabitsWidget()
} timeline: {
    ClarityEntry(date: .now, data: .placeholder)
}

#Preview(as: .systemMedium) {
    HabitsWidget()
} timeline: {
    ClarityEntry(date: .now, data: .placeholder)
}

#Preview(as: .systemLarge) {
    HabitsWidget()
} timeline: {
    ClarityEntry(date: .now, data: .placeholder)
}
