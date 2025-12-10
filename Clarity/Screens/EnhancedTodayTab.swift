import SwiftUI
import SwiftData

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
    
    @State private var showAdd = false
    @State private var showCompleted = false
    @State private var selectedFilter: TaskFilter = .all
    
    // MARK: - Computed Properties
    
    var filteredTasks: [TaskItem] {
        let incompleteTasks = tasks.filter { !$0.isCompleted }
        
        switch selectedFilter {
        case .all:
            return incompleteTasks.filter { $0.isToday || ($0.dueDate != nil && Calendar.current.isDateInToday($0.dueDate!)) || $0.isInProgress }
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
        inProgressTasks.first ?? upNextTasks.first
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
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header & Score
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(Date(), format: .dateTime.weekday(.wide).day().month())
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                
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
                                Label(primary.isInProgress ? "In Progress" : "Primary Focus", systemImage: primary.isInProgress ? "arrow.triangle.2.circlepath" : "star.fill")
                                    .font(.headline)
                                    .foregroundStyle(primary.isInProgress ? Color.clarityOrange : Color.clarityOrange)
                                
                                PrimaryFocusCard(task: primary, context: context, userEmail: userEmail)
                            }
                        }
                        
                        // In Progress Section
                        if !inProgressTasks.isEmpty && inProgressTasks.first != primaryFocus {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("In Progress", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.headline)
                                    .foregroundStyle(Color.clarityOrange)
                                
                                ForEach(inProgressTasks.filter { $0.id != primaryFocus?.id }) { task in
                                    EnhancedTaskRow(task: task, context: context, userEmail: userEmail)
                                }
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
                                    EnhancedTaskRow(task: task, context: context, userEmail: userEmail)
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
                                                withAnimation {
                                                    task.isInProgress.toggle()
                                                    try? context.save()
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
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                
                                Text(selectedFilter == .all ? "All caught up!" : "No \(selectedFilter.rawValue.lowercased()) tasks")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
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
                AddTaskSheet(userEmail: userEmail)
            }
        }
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
                        if task.isCompleted { task.completedDate = Date() }
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

struct EnhancedTaskRow: View {
    let task: TaskItem
    let context: ModelContext
    let userEmail: String
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
        Button(action: { showEdit = true }) {
            HStack(spacing: 16) {
                // Checkbox
                Button(action: {
                    withAnimation {
                        task.isCompleted.toggle()
                        if task.isCompleted { 
                            task.completedDate = Date()
                            task.isInProgress = false
                        }
                        try? context.save()
                        WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
                    }
                }) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : (task.isInProgress ? "arrow.triangle.2.circlepath.circle.fill" : "circle"))
                        .font(.title2)
                        .foregroundStyle(task.isCompleted ? LinearGradient.claritySuccess : (task.isInProgress ? LinearGradient(colors: [.clarityOrange, .clarityPink], startPoint: .top, endPoint: .bottom) : LinearGradient.clarityPrimary))
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(task.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .strikethrough(task.isCompleted)
                        
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
                            .foregroundStyle(Calendar.current.isDateInToday(dueDate) ? Color.clarityOrange : .secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Start/Pause button
                Button(action: {
                    withAnimation {
                        task.isInProgress.toggle()
                        try? context.save()
                    }
                }) {
                    Image(systemName: task.isInProgress ? "pause.fill" : "play.fill")
                        .font(.caption)
                        .foregroundStyle(task.isInProgress ? Color.clarityOrange : .secondary)
                        .padding(8)
                        .background(Color.clarityCard)
                        .clipShape(Circle())
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
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEdit) {
            EditTaskSheet(task: task)
        }
    }
}
