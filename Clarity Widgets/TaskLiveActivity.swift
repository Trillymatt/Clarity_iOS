//
//  TaskLiveActivity.swift
//  Clarity Widgets
//
//  Dynamic Island Live Activity for in-progress tasks
//  Features Clarity's unique gradient branding
//

import ActivityKit
import WidgetKit
import SwiftUI

// Clarity brand colors for widgets
extension Color {
    static let widgetPurple = Color(red: 147/255, green: 112/255, blue: 219/255)
    static let widgetBlue = Color(red: 100/255, green: 149/255, blue: 237/255)
    static let widgetPink = Color(red: 255/255, green: 105/255, blue: 180/255)
    static let widgetTeal = Color(red: 64/255, green: 224/255, blue: 208/255)
}

struct TaskLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TaskActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            ClarityLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    // Clarity branded icon with gradient background
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.widgetBlue, Color.widgetPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: context.state.timerEndTime != nil ? "timer" : "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    ClarityTimerDisplay(
                        startTime: context.attributes.startTime,
                        timerEndTime: context.state.timerEndTime,
                        isLarge: true
                    )
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.taskTitle)
                            .font(.headline.bold())
                            .lineLimit(1)
                        
                        Text(context.state.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        // Clarity branded status pill
                        HStack(spacing: 6) {
                            if let endTime = context.state.timerEndTime {
                                if endTime > Date() {
                                    // Pulsing dot for active timer
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.widgetBlue, Color.widgetPurple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 8, height: 8)
                                    Text("Focus Mode")
                                        .font(.caption.bold())
                                        .foregroundStyle(Color.widgetPurple)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                    Text("Complete!")
                                        .font(.caption.bold())
                                        .foregroundStyle(.green)
                                }
                            } else {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.widgetBlue, Color.widgetPurple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 8, height: 8)
                                Text("Clarity Focus")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.widgetPurple)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.widgetPurple.opacity(0.15))
                        )
                        
                        Spacer()
                        
                        // App branding
                        Text("Clarity")
                            .font(.caption2.bold())
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.widgetBlue, Color.widgetPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                // Compact leading - Clarity branded icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.widgetBlue, Color.widgetPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: context.state.timerEndTime != nil ? "timer" : "sparkles")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            } compactTrailing: {
                // Compact trailing - Timer with gradient
                if let endTime = context.state.timerEndTime {
                    Text(timerInterval: context.attributes.startTime...endTime, countsDown: true)
                        .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.widgetPurple)
                        .frame(maxWidth: 60)
                } else {
                    Text(context.attributes.startTime, style: .timer)
                        .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.widgetPurple)
                        .frame(maxWidth: 60)
                }
            } minimal: {
                // Minimal view - Just the Clarity sparkle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.widgetBlue, Color.widgetPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

struct ClarityLockScreenView: View {
    let context: ActivityViewContext<TaskActivityAttributes>
    
    var body: some View {
        HStack(spacing: 16) {
            // Clarity branded icon with progress ring
            ZStack {
                // Background gradient circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.widgetBlue.opacity(0.2), Color.widgetPurple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                
                if let endTime = context.state.timerEndTime {
                    // Progress ring
                    let progress = timerProgress(startTime: context.attributes.startTime, endTime: endTime)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: endTime <= Date() ? [Color.green, Color.teal] : [Color.widgetBlue, Color.widgetPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 52, height: 52)
                }
                
                // Center icon
                Image(systemName: iconName)
                    .font(.title2.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(context.state.taskTitle)
                    .font(.headline.bold())
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // Category with colored dot
                    HStack(spacing: 4) {
                        Circle()
                            .fill(categoryColor)
                            .frame(width: 6, height: 6)
                        Text(context.state.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    ClarityTimerDisplay(
                        startTime: context.attributes.startTime,
                        timerEndTime: context.state.timerEndTime,
                        isLarge: false
                    )
                }
            }
            
            Spacer()
            
            // Finish button or status indicator
            if let endTime = context.state.timerEndTime, endTime <= Date() {
                // Timer complete - show checkmark
                Text("✓")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.green, .teal],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            } else {
                // Finish button - tap to complete task
                Link(destination: URL(string: "clarity://task/complete/\(context.attributes.taskId)")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text("Finish")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.green, Color.teal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
            }
        }
        .padding()
        .background(
            // Subtle gradient background
            LinearGradient(
                colors: [
                    Color.widgetPurple.opacity(0.05),
                    Color.widgetBlue.opacity(0.05)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .background(.ultraThinMaterial)
    }
    
    private var iconName: String {
        if let endTime = context.state.timerEndTime {
            return endTime <= Date() ? "checkmark" : "timer"
        }
        return "sparkles"
    }
    
    private var iconColors: [Color] {
        if let endTime = context.state.timerEndTime, endTime <= Date() {
            return [Color.green, Color.teal]
        }
        return [Color.widgetBlue, Color.widgetPurple]
    }
    
    private var categoryColor: Color {
        switch context.state.category.lowercased() {
        case "work": return Color.widgetBlue
        case "school": return Color.widgetPurple
        case "personal": return Color.widgetPink
        default: return Color.widgetTeal
        }
    }
    
    private func timerProgress(startTime: Date, endTime: Date) -> Double {
        let totalDuration = endTime.timeIntervalSince(startTime)
        let elapsed = Date().timeIntervalSince(startTime)
        guard totalDuration > 0 else { return 1 }
        return min(1, max(0, elapsed / totalDuration))
    }
}

// MARK: - Clarity Timer Display
struct ClarityTimerDisplay: View {
    let startTime: Date
    let timerEndTime: Date?
    var isLarge: Bool = false
    
    var body: some View {
        if let endTime = timerEndTime {
            if endTime > Date() {
                // Use timerInterval for proper countdown in Live Activities
                Text(timerInterval: startTime...endTime, countsDown: true)
                    .font(isLarge ? .title3.bold().monospacedDigit() : .caption.bold().monospacedDigit())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.widgetBlue, Color.widgetPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            } else {
                Text("Done!")
                    .font(isLarge ? .title3.bold() : .caption.bold())
                    .foregroundStyle(.green)
            }
        } else {
            // No timer, show elapsed time
            Text(startTime, style: .timer)
                .font(isLarge ? .title3.bold().monospacedDigit() : .caption.bold().monospacedDigit())
                .foregroundStyle(Color.widgetPurple)
        }
    }
}

// Legacy views for backwards compatibility
struct TimerDisplayView: View {
    let startTime: Date
    let timerEndTime: Date?
    
    var body: some View {
        ClarityTimerDisplay(startTime: startTime, timerEndTime: timerEndTime, isLarge: false)
    }
}

struct ElapsedTimeView: View {
    let startTime: Date
    
    var body: some View {
        Text(startTime, style: .timer)
            .font(.caption.monospacedDigit())
            .foregroundStyle(Color.widgetPurple)
    }
}

// MARK: - Previews
#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: TaskActivityAttributes(taskId: "1", startTime: .now)) {
    TaskLiveActivity()
} contentStates: {
    TaskActivityAttributes.ContentState(taskTitle: "Review PRs", category: "Work", elapsedSeconds: 300, timerEndTime: nil)
}

#Preview("Dynamic Island with Timer", as: .dynamicIsland(.expanded), using: TaskActivityAttributes(taskId: "1", startTime: .now)) {
    TaskLiveActivity()
} contentStates: {
    TaskActivityAttributes.ContentState(taskTitle: "Review PRs", category: "Work", elapsedSeconds: 300, timerEndTime: Date().addingTimeInterval(1500))
}

#Preview("Lock Screen", as: .content, using: TaskActivityAttributes(taskId: "1", startTime: .now)) {
    TaskLiveActivity()
} contentStates: {
    TaskActivityAttributes.ContentState(taskTitle: "Review PRs", category: "Work", elapsedSeconds: 300, timerEndTime: nil)
}
