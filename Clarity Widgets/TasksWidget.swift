//
//  TasksWidget.swift
//  Clarity Widgets
//
//  Created by Matthew Norman on 11/29/25.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Views

struct SmallTasksWidgetView: View {
    var entry: ClarityEntry
    
    var incompleteTasks: [WidgetTask] {
        entry.data.upcomingTasks.filter { !$0.isCompleted }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("Tasks")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 2)
            
            Spacer()
            
            // Task count
            VStack(spacing: 4) {
                Text("\(entry.data.todayTasksTotal - entry.data.todayTasksCompleted)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                Text("remaining")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .minimumScaleFactor(0.8)
            }
            
            Spacer()
            
            // Progress text
            Text(entry.data.taskCompletionText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .padding(16)
    }
}

struct MediumTasksWidgetView: View {
    var entry: ClarityEntry
    
    var incompleteTasks: [WidgetTask] {
        Array(entry.data.upcomingTasks.filter { !$0.isCompleted }.prefix(3))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("Today's Tasks")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text(entry.data.taskCompletionText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            if incompleteTasks.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.6))
                    Text("All done!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // Task list
                VStack(spacing: 10) {
                    ForEach(Array(incompleteTasks), id: \.id) { task in
                        TaskRowView(task: task)
                    }
                }
                Spacer()
            }
        }
        .padding(16)
    }
}

struct LargeTasksWidgetView: View {
    var entry: ClarityEntry
    
    var incompleteTasks: [WidgetTask] {
        entry.data.upcomingTasks.filter { !$0.isCompleted }
    }
    
    var completedTasks: [WidgetTask] {
        entry.data.upcomingTasks.filter { $0.isCompleted }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text("Today's Tasks")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Progress badge
                HStack(spacing: 6) {
                    Text("\(entry.data.todayTasksCompleted)/\(entry.data.todayTasksTotal)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 3)
                            .frame(width: 32, height: 32)
                        
                        Circle()
                            .trim(from: 0, to: entry.data.todayTasksTotal > 0 ? 
                                  Double(entry.data.todayTasksCompleted) / Double(entry.data.todayTasksTotal) : 0)
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))
                    }
                }
            }
            
            if incompleteTasks.isEmpty && completedTasks.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.5))
                    Text("No tasks for today")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // Incomplete tasks
                if !incompleteTasks.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(Array(incompleteTasks.prefix(5)), id: \.id) { task in
                            TaskRowView(task: task)
                        }
                    }
                }
                
                // Completed tasks (if space allows)
                if !completedTasks.isEmpty && incompleteTasks.count < 4 {
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.vertical, 4)
                    
                    VStack(spacing: 10) {
                        ForEach(Array(completedTasks.prefix(2)), id: \.id) { task in
                            TaskRowView(task: task)
                        }
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

// MARK: - Task Row Component

struct TaskRowView: View {
    let task: WidgetTask
    
    var priorityColor: Color {
        switch task.priority {
        case 2: return Color.red.opacity(0.3)
        case 1: return Color.orange.opacity(0.3)
        default: return Color.white.opacity(0.1)
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: task.isCompleted ? .bold : .medium))
                .foregroundColor(task.isCompleted ? .white.opacity(0.6) : .white)
            
            // Task title
            Text(task.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(task.isCompleted ? .white.opacity(0.5) : .white)
                .strikethrough(task.isCompleted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Spacer(minLength: 0)
            
            // Due time (optional)
            if let dueTime = task.dueTime {
                Text(dueTime, style: .time)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(task.isCompleted ? Color.white.opacity(0.08) : priorityColor)
        )
    }
}

// MARK: - Accessory Rectangular Widget View (Lock Screen / StandBy)

struct AccessoryRectangularTasksWidgetView: View {
    var entry: ClarityEntry
    
    var incompleteTasks: [WidgetTask] {
        Array(entry.data.upcomingTasks.filter { !$0.isCompleted }.prefix(2))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header row
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Tasks")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text("\(entry.data.todayTasksCompleted)/\(entry.data.todayTasksTotal)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            
            if incompleteTasks.isEmpty {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                    Text("All done!")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
            } else {
                ForEach(incompleteTasks, id: \.id) { task in
                    HStack(spacing: 4) {
                        Image(systemName: "circle")
                            .font(.system(size: 8))
                        Text(task.title)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget Configuration

struct TasksWidget: Widget {
    let kind: String = "TasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClarityWidgetProvider()) { entry in
            TasksWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Tasks")
        .description("See your tasks for today")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

// MARK: - Entry View with Size Detection

struct TasksWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: ClarityEntry
    
    var body: some View {
        if #available(iOS 17.0, *) {
            Group {
                switch family {
                case .systemSmall:
                    SmallTasksWidgetView(entry: entry)
                case .systemMedium:
                    MediumTasksWidgetView(entry: entry)
                case .systemLarge:
                    LargeTasksWidgetView(entry: entry)
                case .accessoryRectangular:
                    AccessoryRectangularTasksWidgetView(entry: entry)
                default:
                    SmallTasksWidgetView(entry: entry)
                }
            }
            .containerBackground(for: .widget) {
                if family == .accessoryRectangular {
                    Color.clear
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 0.3, green: 0.7, blue: 0.9),
                            Color(red: 0.2, green: 0.5, blue: 0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.08, blue: 0.14),
                        Color(red: 0.02, green: 0.22, blue: 0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                switch family {
                case .systemSmall:
                    SmallTasksWidgetView(entry: entry)
                case .systemMedium:
                    MediumTasksWidgetView(entry: entry)
                case .systemLarge:
                    LargeTasksWidgetView(entry: entry)
                case .accessoryRectangular:
                    AccessoryRectangularTasksWidgetView(entry: entry)
                default:
                    SmallTasksWidgetView(entry: entry)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    TasksWidget()
} timeline: {
    ClarityEntry(date: .now, data: .placeholder)
}

#Preview(as: .systemMedium) {
    TasksWidget()
} timeline: {
    ClarityEntry(date: .now, data: .placeholder)
}

#Preview(as: .systemLarge) {
    TasksWidget()
} timeline: {
    ClarityEntry(date: .now, data: .placeholder)
}
