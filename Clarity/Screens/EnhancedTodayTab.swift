import SwiftUI
import SwiftData

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
    
    // MARK: - Computed Properties
    
    var todaysTasks: [TaskItem] {
        tasks.filter {
            !$0.isCompleted && ($0.isToday || ($0.dueDate != nil && Calendar.current.isDateInToday($0.dueDate!)))
        }
    }
    
    var primaryFocus: TaskItem? {
        todaysTasks.first
    }
    
    var upNextTasks: [TaskItem] {
        Array(todaysTasks.dropFirst())
    }
    
    var completedTasks: [TaskItem] {
        tasks.filter { $0.isCompleted }
    }
    
    var focusScore: Double {
        if todaysTasks.isEmpty && completedTasks.isEmpty { return 0 }
        let total = Double(todaysTasks.count + completedTasks.filter { $0.isToday || ($0.dueDate != nil && Calendar.current.isDateInToday($0.dueDate!)) }.count)
        if total == 0 { return 0 }
        let completed = Double(completedTasks.filter { $0.isToday || ($0.dueDate != nil && Calendar.current.isDateInToday($0.dueDate!)) }.count)
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
                    VStack(alignment: .leading, spacing: 32) {
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
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        if todaysTasks.isEmpty {
                            let hasCompletedTasks = !completedTasks.filter({ $0.isToday || ($0.dueDate != nil && Calendar.current.isDateInToday($0.dueDate!)) }).isEmpty
                            SuggestedTasksView(
                                userEmail: userEmail,
                                title: hasCompletedTasks ? "All caught up!" : "No tasks yet",
                                subtitle: hasCompletedTasks ? "Ready for more? Here are some suggestions." : "Here are some suggestions to get started"
                            )
                            .padding(.horizontal)
                        } else {
                            // Primary Focus Card
                            if let primary = primaryFocus {
                                VStack(alignment: .leading, spacing: 16) {
                                    Label("Primary Focus", systemImage: "star.fill")
                                        .font(.headline)
                                        .foregroundStyle(Color.clarityOrange)
                                        .padding(.horizontal)
                                    
                                    PrimaryFocusCard(task: primary, context: context)
                                        .padding(.horizontal)
                                }
                            }
                            
                            // Up Next
                            if !upNextTasks.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Up Next")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal)
                                    
                                    ForEach(upNextTasks) { task in
                                        EnhancedTaskRow(task: task, context: context)
                                            .padding(.horizontal)
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                Button(role: .destructive) {
                                                    context.delete(task)
                                                    try? context.save()
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                            }
                        }
                        
                        // Completed Tasks
                        let todaysCompleted = completedTasks.filter { $0.isToday || ($0.dueDate != nil && Calendar.current.isDateInToday($0.dueDate!)) }
                        if !todaysCompleted.isEmpty {
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
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color.clarityCard.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                                
                                if showCompleted {
                                    ForEach(todaysCompleted) { task in
                                        EnhancedTaskRow(task: task, context: context)
                                            .padding(.horizontal)
                                            .opacity(0.6)
                                    }
                                }
                            }
                            .padding(.top, 10)
                        }
                        
                        Spacer(minLength: 80)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
    @State private var showEdit = false
    
    var body: some View {
        Button(action: { showEdit = true }) {
            HStack(spacing: 16) {
                // Checkbox
                Button(action: {
                    withAnimation {
                        task.isCompleted.toggle()
                        if task.isCompleted { task.completedDate = Date() }
                        try? context.save()
                    }
                }) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(task.isCompleted ? LinearGradient.claritySuccess : LinearGradient.clarityPrimary)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .strikethrough(task.isCompleted)
                    
                    if let dueDate = task.dueDate {
                        Text(dueDate, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color.clarityCard)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEdit) {
            EditTaskSheet(task: task)
        }
    }
}
