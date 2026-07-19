import SwiftUI
import SwiftData
import ActivityKit
import Combine

// MARK: - Filter Options
enum TaskFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case school = "School"
    case work = "Work"
    case personal = "Personal"
    case inProgress = "In Progress"
    case dueToday = "Due Today"
    case upcoming = "Upcoming"
    case overdue = "Overdue"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .school: return "graduationcap.fill"
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .dueToday: return "calendar"
        case .upcoming: return "calendar.badge.clock"
        case .overdue: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .clarityBlue
        case .school: return .clarityPurple
        case .work: return .clarityBlue
        case .personal: return .clarityTeal
        case .inProgress: return .clarityOrange
        case .dueToday: return .clarityPink
        case .upcoming: return .secondary
        case .overdue: return .red
        }
    }
}

// MARK: - Enhanced Today/Focus Tab
struct EnhancedTodayTab: View {
    @Environment(\.modelContext) private var context
    let userEmail: String
    @Query private var tasks: [TaskItem]
    
    init(userEmail: String) {
        self.userEmail = userEmail
        _tasks = Query(filter: #Predicate { $0.ownerEmail == userEmail }, sort: \TaskItem.dueDate)
    }
    
    @State private var showDailyReview = false
    @Query private var habits: [Habit]
    @Query private var transactions: [Transaction]
    @Query private var moments: [LifeMoment]
    @AppStorage("lastDailyReview") private var lastDailyReviewStr: String = ""

    // MARK: - Restored Properties
    @State private var showAdd = false
    @State private var showCompleted = false
    @State private var selectedFilter: TaskFilter = .all
    @State private var taskToStart: TaskItem? = nil
    
    var filteredTasks: [TaskItem] {
        let incompleteTasks = tasks.filter { !$0.isCompleted }
        
        switch selectedFilter {
        case .all:
            return incompleteTasks.filter { 
                $0.isToday || 
                $0.isInProgress || 
                ($0.dueDate != nil && Calendar.current.isDateInToday($0.dueDate!)) ||
                $0.isOverdue
            }
        case .school:
            return incompleteTasks.filter { $0.category == .school }
        case .work:
            return incompleteTasks.filter { $0.category == .work }
        case .personal:
            return incompleteTasks.filter { $0.category == .personal }
        case .inProgress:
            return incompleteTasks.filter { $0.isInProgress }
        case .dueToday:
            return incompleteTasks.filter { $0.dueDate != nil && Calendar.current.isDateInToday($0.dueDate!) }
        case .upcoming:
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
            return incompleteTasks.filter { 
                guard let due = $0.dueDate else { return false }
                return due >= tomorrow && due <= nextWeek
            }
        case .overdue:
            let today = Calendar.current.startOfDay(for: Date())
            return incompleteTasks.filter {
                guard let due = $0.dueDate else { return false }
                return due < today
            }
        }
    }
    
    var inProgressTasks: [TaskItem] {
        filteredTasks.filter { $0.isInProgress }
    }
    
    var upNextTasks: [TaskItem] {
        filteredTasks.filter { !$0.isInProgress }
    }
    
    var primaryFocus: TaskItem? {
        inProgressTasks.first
    }
    
    var completedTasks: [TaskItem] {
        tasks.filter { $0.isCompleted }
    }
    
    var focusScore: Double {
        let todaysTasks = tasks.filter { !$0.isCompleted && ($0.isToday || ($0.dueDate != nil && Calendar.current.isDateInToday($0.dueDate!))) }
        let todaysCompleted = completedTasks.filter { $0.isToday || ($0.dueDate != nil && Calendar.current.isDateInToday($0.dueDate!)) }
        
        if todaysTasks.isEmpty && todaysCompleted.isEmpty { return 0 }
        let total = Double(todaysTasks.count + todaysCompleted.count)
        if total == 0 { return 0 }
        let completed = Double(todaysCompleted.count)
        return (completed / total) * 100
    }
    
    var scoreInsight: String {
        switch focusScore {
        case 80...: return "Outstanding focus!"
        case 60..<80: return "Good momentum"
        case 40..<60: return "Keep pushing"
        default: return "Let's find your flow"
        }
    }
    
    // Pillar Data Helpers

    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Spacer for nav bar
                        Color.clear.frame(height: 90)
                        // Header & Score
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Today's Focus")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                
                                Text(scoreInsight)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.clarityBlue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.clarityBlue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            
                            Spacer()
                            
                            FocusScoreRing(score: focusScore)
                        }
                        .padding(.top, 10)
                        
                        // Pillar Summaries removed to keep this view focused on tasks.

                        
                        // Filter Bar - edge to edge
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(TaskFilter.allCases) { filter in
                                    FilterChip(
                                        filter: filter,
                                        isSelected: selectedFilter == filter,
                                        onTap: { selectedFilter = filter }
                                    )
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                        .padding(.horizontal, -12) // Break out of parent padding
                        .padding(.vertical, 4)
                        
                        // Primary Focus Card
                        if let primary = primaryFocus {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Label("In Progress", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.headline)
                                        .foregroundStyle(Color.clarityOrange)
                                    
                                    Spacer()
                                    
                                    // Stop button
                                    Button {
                                        withAnimation {
                                            for task in inProgressTasks {
                                                task.isInProgress = false
                                            }
                                            try? context.save()
                                            // Stop Live Activity
                                            LiveActivityManager.shared.stopTaskActivity()
                                        }
                                    } label: {
                                        Text("Stop All")
                                            .font(.caption.bold())
                                            .foregroundStyle(Color.clarityOrange)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.clarityOrange.opacity(0.15))
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                PrimaryFocusCard(task: primary, context: context, userEmail: userEmail)
                                
                                // Show additional in-progress tasks
                                ForEach(inProgressTasks.filter { $0.id != primary.id }) { task in
                                    EnhancedTaskRow(task: task, context: context, userEmail: userEmail)
                                }
                            }
                        } else {
                            // Empty state - no task in progress
                            VStack(spacing: 12) {
                                Label("In Progress", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.headline)
                                    .foregroundStyle(Color.clarityOrange)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                VStack(spacing: 12) {
                                    Image(systemName: "play.circle")
                                        .font(.system(size: 36))
                                        .foregroundStyle(Color.clarityOrange.opacity(0.5))
                                    
                                    Text("No task in focus")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    
                                    Text("Tap the play button on a task below to start focusing")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                                .background(Color.clarityCard)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.clarityOrange.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                        
                        // Up Next
                        let remainingUpNext = upNextTasks.filter { $0.id != primaryFocus?.id }
                        if !remainingUpNext.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Up Next")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                
                                ForEach(remainingUpNext) { task in
                                    EnhancedTaskRow(
                                        task: task,
                                        context: context,
                                        userEmail: userEmail,
                                        onStartTask: { showDurationPickerFor(task) }
                                    )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            context.delete(task)
                                            try? context.save()
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            if task.isInProgress {
                                                // Stop task directly
                                                withAnimation {
                                                    task.isInProgress = false
                                                    task.timerStartTime = nil
                                                    task.timerDurationMinutes = nil
                                                    try? context.save()
                                                    LiveActivityManager.shared.stopTaskActivity()
                                                }
                                            } else {
                                                // Show duration picker
                                                showDurationPickerFor(task)
                                            }
                                        } label: {
                                            Label(task.isInProgress ? "Pause" : "Start", systemImage: task.isInProgress ? "pause.fill" : "play.fill")
                                        }
                                        .tint(.clarityOrange)
                                    }
                                }
                            }
                        }
                        
                        // Empty State
                        if filteredTasks.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: selectedFilter == .all ? "checkmark.seal.fill" : "tray")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.secondary)
                                
                                Text(selectedFilter == .all ? "All caught up!" : "No \(selectedFilter.rawValue.lowercased()) tasks")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }
                        
                        // Suggestions
                        if selectedFilter == .all {
                            let hasCompletedTasks = !completedTasks.filter({ $0.isToday || ($0.dueDate != nil && Calendar.current.isDateInToday($0.dueDate!)) }).isEmpty
                            SuggestedTasksView(
                                userEmail: userEmail,
                                title: filteredTasks.isEmpty ? (hasCompletedTasks ? "All caught up!" : "No tasks yet") : "More Ideas",
                                subtitle: filteredTasks.isEmpty ? (hasCompletedTasks ? "Ready for more? Here are some suggestions." : "Here are some suggestions to get started") : "Other tasks you might want to add"
                            )
                        }
                        
                        // Completed Tasks
                        let todaysCompleted = completedTasks.filter { $0.isToday || ($0.dueDate != nil && Calendar.current.isDateInToday($0.dueDate!)) }
                        if !todaysCompleted.isEmpty && selectedFilter == .all {
                            VStack(alignment: .leading, spacing: 16) {
                                Button(action: { withAnimation { showCompleted.toggle() } }) {
                                    HStack {
                                        Text("Completed")
                                            .font(.headline)
                                            .foregroundStyle(.secondary)
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 4) {
                                            Text("\(todaysCompleted.count)")
                                            Image(systemName: showCompleted ? "chevron.up" : "chevron.down")
                                        }
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 8)
                                    .background(Color.clarityCard.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                                
                                if showCompleted {
                                    ForEach(todaysCompleted) { task in
                                        EnhancedTaskRow(task: task, context: context, userEmail: userEmail)
                                            .opacity(0.6)
                                    }
                                }
                            }
                            .padding(.top, 10)
                        }
                        
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom)
                }
            }
            .navigationTitle("")
            .toolbar(.hidden)
            .onAppear {
                checkDailyReview()
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(LinearGradient.clarityPrimary)
                        .clipShape(Circle())
                        .shadow(color: Color.clarityPurple.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .padding()
            }
            .sheet(isPresented: $showAdd) {
                // Direct Add Task Sheet
                AddTaskSheet(userEmail: userEmail)
            }
            .sheet(isPresented: $showDailyReview) {
                DailyReviewView(userEmail: userEmail)
            }
            .sheet(item: $taskToStart) { task in
                DurationPickerSheet(taskTitle: task.title) { duration in
                    startTask(task, withDuration: duration)
                }
                .presentationDetents([.large])
            }
        }
    }
    
    // MARK: - Daily Review Logic
    private func checkDailyReview() {
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: today)
        
        if lastDailyReviewStr != todayStr {
            // Check if it's "Morning" (e.g., before 12 PM) - Optional, 
            // but for now let's just show it once per day when they open dashboard.
            // We can also check if there are any incomplete tasks from yesterday to make it more relevant.
            
            // For now, always trigger if not done today.
            
            // Delay slightly to let view appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showDailyReview = true
                lastDailyReviewStr = todayStr
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func startTask(_ task: TaskItem, withDuration duration: Int?) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            task.isInProgress = true
            task.timerStartTime = Date()
            task.timerDurationMinutes = duration
            try? context.save()
            
            // Start Live Activity with timer
            LiveActivityManager.shared.startTaskActivity(
                taskId: task.id.uuidString,
                title: task.title,
                category: task.category.rawValue.capitalized,
                durationMinutes: duration
            )
        }
        taskToStart = nil
    }
    
    private func showDurationPickerFor(_ task: TaskItem) {
        taskToStart = task  // This triggers the sheet via .sheet(item:)
    }
}

// MARK: - Filter Chip Component

struct FilterChip: View {
    let filter: TaskFilter
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(filter.rawValue)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? filter.color : Color.clarityCard)
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subviews

struct FocusScoreRing: View {
    let score: Double
    
    var contribution: Int {
        Int(score * ClarityScoreCalculator.taskWeight)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.clarityCard, lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(
                        LinearGradient(colors: [.clarityBlue, .clarityPurple], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.8), value: score)
                
                VStack(spacing: 0) {
                    Text("\(Int(score))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Score")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }
            .frame(width: 80, height: 80)
            
            Text("+\(contribution) pts")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.clarityCard)
                .clipShape(Capsule())
        }
    }
}

struct PrimaryFocusCard: View {
    let task: TaskItem
    let context: ModelContext
    let userEmail: String
    @State private var showEdit = false
    
    var body: some View {
        Button(action: { showEdit = true }) {
            HStack(spacing: 16) {
                // Large Checkbox
                Button(action: {
                    withAnimation {
                        task.isCompleted.toggle()
                        if task.isCompleted {
                            task.completedDate = Date()
                            task.isInProgress = false
                            // Stop Live Activity when task completed
                            if LiveActivityManager.shared.activeTaskId == task.id.uuidString {
                                LiveActivityManager.shared.stopTaskActivity()
                            }
                        }
                        try? context.save()
                        WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
                    }
                }) {
                    Circle()
                        .stroke(LinearGradient.clarityPrimary, lineWidth: 2)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .fill(LinearGradient.clarityPrimary)
                                .padding(4)
                                .opacity(task.isCompleted ? 1 : 0)
                        )
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .strikethrough(task.isCompleted)
                    
                    if let notes = task.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    if let dueDate = task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                            Text(dueDate, style: .time)
                        }
                        .font(.caption.bold())
                        .foregroundStyle(Color.clarityOrange)
                        .padding(.top, 4)
                    }
                    
                    // Timer display for in-progress tasks
                    if task.isInProgress {
                        TaskTimerView(task: task)
                            .padding(.top, 4)
                    }
                }
                
                Spacer()
            }
            .padding(20)
            .background(Color.clarityCard)
            .cornerRadius(20)
            .shadow(color: Color.clarityBlue.opacity(0.1), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(LinearGradient.clarityPrimary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEdit) {
            EditTaskSheet(task: task)
        }
    }
}

// MARK: - Timer Countdown View
struct TaskTimerView: View {
    let task: TaskItem
    var isCompact: Bool = true  // Use compact style in task rows
    
    var body: some View {
        // Use TimelineView for automatic updates every second
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            if isCompact {
                compactTimer(date: timeline.date)
            } else {
                prominentTimer(date: timeline.date)
            }
        }
    }
    
    // Compact timer for task rows
    @ViewBuilder
    private func compactTimer(date: Date) -> some View {
        if let endTime = task.timerEndTime {
            let remaining = Int(endTime.timeIntervalSince(date))
            if remaining > 0 {
                HStack(spacing: 6) {
                    // Mini progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.clarityOrange.opacity(0.2), lineWidth: 2)
                            .frame(width: 20, height: 20)
                        
                        Circle()
                            .trim(from: 0, to: timerProgress(date: date))
                            .stroke(
                                LinearGradient(colors: [.clarityOrange, .clarityPink], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 20, height: 20)
                    }
                    
                    Text(formatTime(remaining))
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(LinearGradient(colors: [.clarityOrange, .clarityPink], startPoint: .leading, endPoint: .trailing))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.clarityOrange.opacity(0.1))
                )
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "bell.fill")
                    Text("Time's up!")
                }
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.red)
                )
            }
        } else if task.isInProgress, let startTime = task.timerStartTime {
            // Show elapsed time if no duration set
            let elapsed = Int(date.timeIntervalSince(startTime))
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                Text(formatTime(elapsed))
                    .font(.subheadline.bold().monospacedDigit())
            }
            .foregroundStyle(Color.clarityOrange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.clarityOrange.opacity(0.1))
            )
        }
    }
    
    // Prominent timer for focus view
    @ViewBuilder
    private func prominentTimer(date: Date) -> some View {
        if let endTime = task.timerEndTime {
            let remaining = Int(endTime.timeIntervalSince(date))
            
            VStack(spacing: 8) {
                // Large progress ring
                ZStack {
                    Circle()
                        .stroke(Color.clarityOrange.opacity(0.15), lineWidth: 8)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: remaining > 0 ? timerProgress(date: date) : 1)
                        .stroke(
                            remaining > 0 
                                ? LinearGradient(colors: [.clarityBlue, .clarityPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 100, height: 100)
                    
                    VStack(spacing: 2) {
                        if remaining > 0 {
                            Text(formatTime(remaining))
                                .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.primary)
                            Text("remaining")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.green)
                            Text("Done!")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        } else if task.isInProgress, let startTime = task.timerStartTime {
            let elapsed = Int(date.timeIntervalSince(startTime))
            
            VStack(spacing: 4) {
                Text(formatTime(elapsed))
                    .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(LinearGradient(colors: [.clarityOrange, .clarityPink], startPoint: .leading, endPoint: .trailing))
                Text("elapsed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func timerProgress(date: Date) -> Double {
        guard let startTime = task.timerStartTime, let endTime = task.timerEndTime else { return 0 }
        let total = endTime.timeIntervalSince(startTime)
        let elapsed = date.timeIntervalSince(startTime)
        guard total > 0 else { return 1 }
        return min(1, max(0, elapsed / total))
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let absSeconds = abs(seconds)
        let hours = absSeconds / 3600
        let minutes = (absSeconds % 3600) / 60
        let secs = absSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

struct EnhancedTaskRow: View {
    let task: TaskItem
    let context: ModelContext
    let userEmail: String
    var onStartTask: (() -> Void)? = nil  // Optional callback for starting task with duration picker
    @State private var showEdit = false
    
    var categoryIcon: String {
        switch task.category {
        case .work: return "briefcase.fill"
        case .school: return "graduationcap.fill"
        case .personal: return "person.fill"
        case .other: return "folder.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Checkbox - independent button, NOT nested
            Button(action: {
                withAnimation {
                    task.isCompleted.toggle()
                    if task.isCompleted { 
                        task.completedDate = Date()
                        task.isInProgress = false
                        // Stop Live Activity when task completed
                        if LiveActivityManager.shared.activeTaskId == task.id.uuidString {
                            LiveActivityManager.shared.stopTaskActivity()
                        }
                    }
                    try? context.save()
                    WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
                }
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : (task.isInProgress ? "arrow.triangle.2.circlepath.circle.fill" : "circle"))
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? LinearGradient.claritySuccess : (task.isInProgress ? LinearGradient(colors: [.clarityOrange, .clarityPink], startPoint: .top, endPoint: .bottom) : LinearGradient.clarityPrimary))
                    .contentShape(Rectangle().size(width: 44, height: 44))
            }
            .buttonStyle(.plain)
            
            // Task info - tappable for edit
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .strikethrough(task.isCompleted)
                    
                    // Past Due badge - show prominently
                    if task.isOverdue {
                        Text("Past Due")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                    
                    if task.isInProgress {
                        Text("In Progress")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.clarityOrange)
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 8) {
                    // Category
                    HStack(spacing: 4) {
                        Image(systemName: categoryIcon)
                        Text(task.category.rawValue.capitalized)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    // Due time
                    if let dueDate = task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text(dueDate, style: .time)
                        }
                        .font(.caption)
                        .foregroundStyle(task.isOverdue ? Color.red : (Calendar.current.isDateInToday(dueDate) ? Color.clarityOrange : .secondary))
                    }
                    
                    // Timer display when in progress
                    if task.isInProgress {
                        TaskTimerView(task: task)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showEdit = true
            }
            
            Spacer()
            
            // Start/Pause button - independent button
            Button(action: {
                if task.isInProgress {
                    // Stop task directly
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        task.isInProgress = false
                        task.timerStartTime = nil
                        task.timerDurationMinutes = nil
                        try? context.save()
                        LiveActivityManager.shared.stopTaskActivity()
                    }
                } else {
                    // Show duration picker via callback, or start directly
                    if let onStart = onStartTask {
                        onStart()
                    } else {
                        // Fallback: start without timer
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            task.isInProgress = true
                            task.timerStartTime = Date()
                            try? context.save()
                            LiveActivityManager.shared.startTaskActivity(
                                taskId: task.id.uuidString,
                                title: task.title,
                                category: task.category.rawValue.capitalized
                            )
                        }
                    }
                }
            }) {
                Image(systemName: task.isInProgress ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        task.isInProgress 
                            ? AnyShapeStyle(Color.clarityOrange)
                            : AnyShapeStyle(LinearGradient(colors: [.clarityBlue, .clarityPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .clipShape(Circle())
                    .shadow(color: task.isInProgress ? Color.clarityOrange.opacity(0.3) : Color.clarityBlue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.clarityCard)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(task.isInProgress ? Color.clarityOrange.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showEdit) {
            EditTaskSheet(task: task)
        }
    }
}
