import SwiftUI
import SwiftData

struct DailyReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let userEmail: String
    
    // Yesterday's incomplete items
    @State private var incompleteTasks: [TaskItem] = []
    
    // Today's Planning
    @State private var todaysTasks: [TaskItem] = []
    @State private var newTaskTitle: String = ""
    @Query private var allTasks: [TaskItem]
    @Query private var allHabits: [Habit]
    @Query private var allCheckins: [HabitCheckin]
    
    // State
    @State private var step = 0 // 0: Reflect, 1: Mood, 2: Plan
    
    init(userEmail: String) {
        self.userEmail = userEmail
        _allTasks = Query(filter: #Predicate { $0.ownerEmail == userEmail })
        _allHabits = Query(filter: #Predicate { $0.ownerEmail == userEmail && $0.isActive })
        _allCheckins = Query(filter: #Predicate { $0.ownerEmail == userEmail })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                VStack {
                    // Progress Bar
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in
                            Capsule()
                                .fill(i <= step ? LinearGradient.clarityPrimary : LinearGradient(colors: [.secondary.opacity(0.2)], startPoint: .leading, endPoint: .trailing))
                                .frame(height: 4)
                                .animation(.spring(), value: step)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.horizontal, 20)
                    .padding(.top, 40) // Increased top padding for better spacing
                    
                    TabView(selection: $step) {
                        reflectStep
                            .tag(0)
                        
                        moodStep
                            .tag(1)
                        
                        planStep
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    // Disable swipe to enforce flow? Or allow it. Let's allow swipe but use buttons.
                }
            }
            .onAppear(perform: loadData)
            .onDisappear {
                // Mark as seen/done for today when dismissed (swiped or closed)
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastDailyReview")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Step 1: Reflect
    var reflectStep: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Let's look back")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Any loose ends from yesterday?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)
            
            ScrollView {
                VStack(spacing: 20) {
                    if incompleteTasks.isEmpty {
                        // Empty state (Good job!)
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(LinearGradient.claritySuccess)
                                .padding()
                                .background(Color.claritySuccess.opacity(0.1))
                                .clipShape(Circle())
                            
                            Text("Fast start!")
                                .font(.title3.bold())
                            Text("No missed tasks from yesterday.")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 40)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Yesterday's Tasks")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(incompleteTasks) { task in
                                ReviewTaskRow(task: task, context: context)
                            }
                        }
                    }
                }
                .padding()
                
                // Yesterday's Habits Review
                VStack(alignment: .leading, spacing: 12) {
                    Text("Yesterday's Habits")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    let yesterdaysHabits = getHabitsForYesterday()
                    if yesterdaysHabits.isEmpty {
                        Text("No habits were scheduled for yesterday.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    } else {
                        ForEach(yesterdaysHabits) { habit in
                            ReviewHabitRow(habit: habit, date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, checkins: allCheckins, context: context, userEmail: userEmail)
                        }
                    }
                }
                .padding(.bottom)
            }
            
            Button(action: {
                withAnimation { step = 1 }
            }) {
                Text("Next: Check In")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient.clarityPrimary)
                    .cornerRadius(16)
            }
            .padding()
        }
    }
    
    // MARK: - Step 2: Mood
    var moodStep: some View {
        MoodCheckInView(userEmail: userEmail, onSave: {
            withAnimation { step = 2 }
        }, embedMode: true)
        .navigationBarHidden(true)
    }
    
    // MARK: - Step 3: Plan Today
    var planStep: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Today's Focus")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("What's the main thing today?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Quick Add Input
                    HStack(spacing: 12) {
                        TextField("Add a main task...", text: $newTaskTitle)
                            .padding(12)
                            .background(Color.clarityCard)
                            .cornerRadius(12)
                            .submitLabel(.done)
                            .onSubmit(addToToday)
                        
                        Button(action: addToToday) {
                            Image(systemName: "plus")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(LinearGradient.clarityPrimary)
                                .clipShape(Circle())
                        }
                        .disabled(newTaskTitle.isEmpty)
                    }
                    .padding(.horizontal)
                    
                    // Today's List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scheduled for Today")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        let todays = allTasks.filter { !$0.isCompleted && ($0.isToday || ($0.dueDate != nil && Calendar.current.isDateInToday($0.dueDate!))) }
                        
                        if todays.isEmpty {
                            Text("Nothing scheduled yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(todays) { task in
                                ReviewTaskRow(task: task, context: context) // Reuse row for simplicity, or make read-only
                            }
                        }
                    }
                }
                .padding(.vertical)
                
                // Today's Habits Plan
                VStack(alignment: .leading, spacing: 12) {
                    Text("Habits for Today")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    let todaysHabits = getHabitsForToday()
                    if todaysHabits.isEmpty {
                        Text("No habits scheduled for today.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    } else {
                        ForEach(todaysHabits) { habit in
                            PlanHabitRow(habit: habit)
                        }
                    }
                }
                .padding(.bottom)
            }
            
            Button(action: {
                // Mark as done for today
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastDailyReview")
                dismiss()
            }) {
                Text("Ready to go! 🚀")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient.clarityPrimary)
                    .cornerRadius(16)
            }
            .padding()
        }
    }
    
    // MARK: - Logic
    
    private func loadData() {
        // Load yesterday's tasks
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Manual filter for now since Query wrapper handles 'allTasks'
        incompleteTasks = allTasks.filter { task in
            !task.isCompleted && task.dueDate != nil && task.dueDate! < today
        }
    }
    
    private func addToToday() {
        guard !newTaskTitle.isEmpty else { return }
        
        let newTask = TaskItem(
            ownerEmail: userEmail,
            title: newTaskTitle,
            dueDate: Date(),    // Due Today
            isToday: true,
            category: .personal
        )
        context.insert(newTask)
        try? context.save()
        
        newTaskTitle = ""
    }
    
    // MARK: - Habit Helpers
    private func getHabitsForYesterday() -> [Habit] {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { return [] }
        let weekday = calendar.component(.weekday, from: yesterday) // 1=Sun
        
        return allHabits.filter { habit in
            habit.daysOfWeek.isEmpty || habit.daysOfWeek.contains(weekday)
        }
    }
    
    private func getHabitsForToday() -> [Habit] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        
        return allHabits.filter { habit in
            habit.daysOfWeek.isEmpty || habit.daysOfWeek.contains(weekday)
        }
    }
}

// MARK: - Habit Rows
struct ReviewHabitRow: View {
    let habit: Habit
    let date: Date
    let checkins: [HabitCheckin]
    let context: ModelContext
    let userEmail: String
    
    var isCheckedIn: Bool {
        let calendar = Calendar.current
        return checkins.contains {
            $0.habit?.id == habit.id && calendar.isDate($0.date, inSameDayAs: date)
        }
    }
    
    var body: some View {
        HStack {
            Text(habit.iconName == "flame.fill" ? "🔥" : "⭐") // Simplified icon mapping
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(habit.name)
                    .font(.subheadline.bold())
                Text(habit.habitType == .quit ? "Stay Clean" : "Build Routine")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isCheckedIn {
                // Success
                HStack {
                    Image(systemName: habit.habitType == .quit ? "checkmark.shield.fill" : "checkmark.circle.fill")
                        .foregroundStyle(habit.habitType == .quit ? .blue : .green)
                    Text(habit.habitType == .quit ? "Clean" : "Done")
                        .font(.caption.bold())
                        .foregroundStyle(habit.habitType == .quit ? .blue : .green)
                }
            } else {
                // Missed / Not Logged
                HStack {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.red)
                    Text(habit.habitType == .quit ? "Not Logged" : "Missed")
                        .font(.caption)
                        .foregroundStyle(.red)
                    
                    // Allow late check-in?
                    Button(habit.habitType == .quit ? "Confirm Clean" : "Complete") {
                        let checkin = HabitCheckin(
                            ownerEmail: userEmail,
                            habit: habit,
                            date: date,
                            value: 1
                        )
                        context.insert(checkin)
                        try? context.save()
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.clarityBlue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.clarityCard)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct PlanHabitRow: View {
    let habit: Habit
    
    var body: some View {
        HStack {
            Text(habit.iconName == "flame.fill" ? "🔥" : "⭐")
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(habit.name)
                    .font(.subheadline.bold())
                if habit.habitType == .quit {
                    Text("Stay strong today!")
                        .font(.caption.italic())
                        .foregroundStyle(.blue)
                }
            }
            
            Spacer()
            
            if habit.habitType == .quit {
                Image(systemName: "shield")
                    .foregroundStyle(.secondary.opacity(0.5))
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary.opacity(0.5))
            }
        }
        .padding()
        .background(Color.clarityCard.opacity(0.5))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Components (Reused)

struct ReviewTaskRow: View {
    let task: TaskItem
    let context: ModelContext
    @State private var isDone = false
    @State private var movedToToday = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(task.title)
                    .font(.subheadline.bold())
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? .secondary : .primary)
                
                if let due = task.dueDate, !task.isToday {
                    Text(due, style: .date)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if task.isToday {
                     Text("Today")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            
            Spacer()
            
            if !isDone {
                HStack(spacing: 8) {
                    if !task.isToday && !movedToToday && !Calendar.current.isDateInToday(task.dueDate ?? .distantPast) {
                        Button("Today") {
                            withAnimation {
                                task.dueDate = Date()
                                task.isToday = true
                                movedToToday = true
                                try? context.save()
                            }
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.clarityBlue.opacity(0.1))
                        .foregroundStyle(Color.clarityBlue)
                        .cornerRadius(8)
                    }
                    
                    Button {
                        withAnimation {
                            task.isCompleted = true
                            task.completedDate = Date()
                            isDone = true
                            try? context.save()
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.green)
                    }
                }
            } else {
                Text("Done")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(Color.clarityCard)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}
