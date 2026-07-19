import SwiftUI
import SwiftData

// MARK: - Add Task Sheet
struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    
    let userEmail: String
    let taskToEdit: TaskItem? // Optional task for editing
    
    @State private var title = ""
    @State private var notes = ""
    @State private var dueDate: Date = Date()
    @State private var isToday = true
    @State private var category: TaskCategory = .personal
    @State private var isGenerating = false
    @State private var showAIError = false
    @State private var aiErrorMessage = ""
    @State private var generatedSubtasks: [AIService.Subtask] = []
    @State private var selectedSubtasks: Set<String> = [] // Store titles of selected subtasks
    @State private var showDeleteConfirmation = false
    @State private var notifyOnDueDate = false
    
    init(userEmail: String, taskToEdit: TaskItem? = nil) {
        self.userEmail = userEmail
        self.taskToEdit = taskToEdit
        
        // Pre-fill if editing
        if let task = taskToEdit {
            _title = State(initialValue: task.title)
            _notes = State(initialValue: task.notes ?? "")
            _isToday = State(initialValue: task.isToday)
            _category = State(initialValue: task.category)
            _dueDate = State(initialValue: task.dueDate ?? Date())
            _notifyOnDueDate = State(initialValue: task.notifyOnDueDate)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Title Input with Magic Wand
                        HStack(alignment: .top, spacing: 12) {
                            CustomTextField(icon: "checkmark.circle.fill", placeholder: "What needs to be done?", text: $title)
                            
                            // Hide AI button when editing
                            if taskToEdit == nil {
                                Button(action: generateSubtasks) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.clarityPurple.gradient)
                                            .frame(width: 50, height: 50) // Match TextField height approx
                                        
                                        if isGenerating {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "wand.and.stars")
                                                .font(.system(size: 20))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .shadow(color: Color.clarityPurple.opacity(0.3), radius: 5, x: 0, y: 2)
                                }
                                .disabled(title.isEmpty || isGenerating)
                            }
                        }
                        
                        // Category Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(TaskCategory.allCases) { cat in
                                        SelectionChip(title: cat.rawValue.capitalized, isSelected: category == cat) {
                                            withAnimation { category = cat }
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 4)
                            }
                        }
                        
                        // Due Date Quick Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("When is this due?")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            // Quick date buttons
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                DueDateButton(
                                    title: "Today",
                                    icon: "sun.max.fill",
                                    isSelected: isToday,
                                    color: .clarityOrange
                                ) {
                                    isToday = true
                                    dueDate = Date()
                                }
                                
                                DueDateButton(
                                    title: "Tomorrow",
                                    icon: "sunrise.fill",
                                    isSelected: !isToday && Calendar.current.isDateInTomorrow(dueDate),
                                    color: .clarityBlue
                                ) {
                                    isToday = false
                                    dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                                }
                                
                                DueDateButton(
                                    title: "This Week",
                                    icon: "calendar",
                                    isSelected: !isToday && isThisWeek(dueDate) && !Calendar.current.isDateInTomorrow(dueDate),
                                    color: .clarityPurple
                                ) {
                                    isToday = false
                                    // Set to end of this week (Saturday)
                                    let weekday = Calendar.current.component(.weekday, from: Date())
                                    let daysUntilSaturday = 7 - weekday
                                    dueDate = Calendar.current.date(byAdding: .day, value: daysUntilSaturday, to: Date()) ?? Date()
                                }
                                
                                DueDateButton(
                                    title: "Next Week",
                                    icon: "calendar.badge.clock",
                                    isSelected: !isToday && isNextWeek(dueDate),
                                    color: .clarityTeal
                                ) {
                                    isToday = false
                                    // Set to Monday of next week
                                    let weekday = Calendar.current.component(.weekday, from: Date())
                                    let daysUntilNextMonday = (9 - weekday) % 7 + 7
                                    dueDate = Calendar.current.date(byAdding: .day, value: daysUntilNextMonday, to: Date()) ?? Date()
                                }
                            }
                            
                            // Custom date picker (expandable)
                            DisclosureGroup("Pick a specific date") {
                                DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.graphical)
                                    .onChange(of: dueDate) { _, newValue in
                                        isToday = Calendar.current.isDateInToday(newValue)
                                    }
                            }
                            .padding()
                            .background(Color.clarityCard)
                            .cornerRadius(12)
                            
                            // Notification toggle
                            if !isToday {
                                Toggle(isOn: $notifyOnDueDate) {
                                    Label("Remind me", systemImage: "bell.fill")
                                        .font(.subheadline)
                                }
                                .tint(Color.clarityBlue)
                                .padding()
                                .background(Color.clarityCard)
                                .cornerRadius(12)
                            }
                        }
                        
                        // Generated Subtasks UI (only when creating)
                        if taskToEdit == nil && !generatedSubtasks.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Generated Subtasks")
                                    .font(.headline)
                                    .padding(.horizontal, 4)
                                
                                ForEach(generatedSubtasks, id: \.title) { subtask in
                                    HStack {
                                        Image(systemName: selectedSubtasks.contains(subtask.title) ? "checkmark.square.fill" : "square")
                                            .foregroundStyle(selectedSubtasks.contains(subtask.title) ? Color.clarityBlue : .secondary)
                                            .font(.title3)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(subtask.title)
                                                .strikethrough(!selectedSubtasks.contains(subtask.title))
                                                .foregroundStyle(selectedSubtasks.contains(subtask.title) ? .primary : .secondary)
                                            
                                            if selectedSubtasks.contains(subtask.title) {
                                                Text(dateLabel(for: subtask.suggestedOffset))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.clarityCard)
                                    .cornerRadius(12)
                                    .onTapGesture {
                                        withAnimation {
                                            if selectedSubtasks.contains(subtask.title) {
                                                selectedSubtasks.remove(subtask.title)
                                            } else {
                                                selectedSubtasks.insert(subtask.title)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Notes
                        CustomTextEditor(title: "Notes (Optional)", text: $notes)
                        
                        Spacer(minLength: 20)
                        
                        Button(action: saveTask) {
                            Text(taskToEdit == nil ? "Create Task" : "Save Changes")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        // Delete button (only when editing)
                        if taskToEdit != nil {
                            Button(action: { showDeleteConfirmation = true }) {
                                Text("Delete Task")
                                    .font(.body.bold())
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(taskToEdit == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            })
            .alert("AI Error", isPresented: $showAIError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(aiErrorMessage)
            }
            .alert("Delete Task?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteTask()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    private func saveTask() {
        if let existing = taskToEdit {
            // Update existing task
            existing.title = title
            existing.notes = notes.isEmpty ? nil : notes
            existing.isToday = isToday
            existing.dueDate = isToday ? nil : dueDate
            existing.category = category
            existing.notifyOnDueDate = notifyOnDueDate
            try? context.save()
            
            // Update widget data
            WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
            
            // Update notifications
            if !isToday && notifyOnDueDate && dueDate >= Date() {
                Task { @MainActor in
                    NotificationManager.shared.scheduleTaskDeadline(
                        taskId: existing.id,
                        taskTitle: existing.title,
                        dueDate: dueDate
                    )
                }
            } else {
                Task { @MainActor in
                    NotificationManager.shared.cancelTaskDeadline(taskId: existing.id)
                }
            }
            dismiss()
        } else {
            // Create Main Task
            let mainItem = TaskItem(
                ownerEmail: userEmail,
                title: title,
                notes: notes.isEmpty ? nil : notes,
                dueDate: isToday ? nil : dueDate,
                isCompleted: false,
                isToday: isToday,
                category: category,
                notifyOnDueDate: notifyOnDueDate
            )
            context.insert(mainItem)
            
            // Schedule notification if enabled and has future due date
            if !isToday && notifyOnDueDate && dueDate >= Date() {
                Task { @MainActor in
                    NotificationManager.shared.scheduleTaskDeadline(
                        taskId: mainItem.id,
                        taskTitle: mainItem.title,
                        dueDate: dueDate
                    )
                }
            }
            
            // Create Subtasks
            for subtask in generatedSubtasks where selectedSubtasks.contains(subtask.title) {
                // Calculate due date based on offset
                let offsetDate = Calendar.current.date(byAdding: .day, value: subtask.suggestedOffset, to: Date())
                let isSubtaskToday = subtask.suggestedOffset == 0
                
                let subItem = TaskItem(
                    ownerEmail: userEmail,
                    title: subtask.title,
                    notes: "Subtask of: \(title)",
                    dueDate: offsetDate,
                    isCompleted: false,
                    isToday: isSubtaskToday,
                    category: category
                )
                context.insert(subItem)
            }
            
            try? context.save()
            
            // Update widget data
            WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
            
            dismiss()
        }
    }
    
    private func deleteTask() {
        guard let existing = taskToEdit else { return }
        
        // Cancel notification
        Task { @MainActor in
            NotificationManager.shared.cancelTaskDeadline(taskId: existing.id)
        }
        
        context.delete(existing)
        try? context.save()
        
        // Update widget data
        WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
        
        dismiss()
    }
    
    private func generateSubtasks() {
        guard !title.isEmpty else { return }
        isGenerating = true
        
        Task {
            do {
                // Get user context from profile
                let userContext: UserContext? = if let profile = profiles.first {
                    UserContext(
                        biggestPriority: profile.biggestPriority,
                        idealDay: profile.idealDay,
                        desiredHabit: profile.desiredHabit
                    )
                } else {
                    nil
                }
                
                let result = try await AIService.shared.generateSubtasks(for: title, userContext: userContext)
                
                await MainActor.run {
                    // Update title to the refined "Project" title
                    title = result.title
                    
                    // Populate subtasks list
                    generatedSubtasks = result.subtasks
                    selectedSubtasks = Set(result.subtasks.map { $0.title }) // Select all by default
                    
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    aiErrorMessage = error.localizedDescription
                    showAIError = true
                    isGenerating = false
                }
            }
        }
    }
    
    private func dateLabel(for offset: Int) -> String {
        switch offset {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case 2...6:
            let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Full day name (e.g., "Monday")
            return formatter.string(from: date)
        default: return "In \(offset) days"
        }
    }
    
    private func isThisWeek(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    private func isNextWeek(_ date: Date) -> Bool {
        let calendar = Calendar.current
        guard let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: Date()) else { return false }
        return calendar.isDate(date, equalTo: nextWeekStart, toGranularity: .weekOfYear)
    }
}

// MARK: - Due Date Button Component
struct DueDateButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(title)
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(isSelected ? .white : color)
            .background(isSelected ? color : color.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Icon Chip for Habit Icons
struct IconChip: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isSelected ? .white : Color.clarityPurple)
                .frame(width: 56, height: 56)
                .background(isSelected ? Color.clarityPurple : Color.clarityBackground)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.clear : Color.clarityPurple.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: isSelected ? Color.clarityPurple.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Day Chip for Frequency Selection
struct DayChip: View {
    let day: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(day)
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(isSelected ? .white : color)
                .background(isSelected ? color : color.opacity(0.1))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Habit Sheet
struct AddHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query private var allCheckins: [HabitCheckin]
    
    let userEmail: String
    let habitToEdit: Habit? // Optional habit for editing
    
    @State private var name = ""
    @State private var selectedIcon = "star.fill"
    @State private var goal: Int = 1
    @State private var days: Set<Int> = Set(0...6) // Default all days
    @State private var habitType: HabitType = .build
    
    @State private var isGenerating = false
    @State private var showDeleteConfirmation = false
    
    // Notification settings
    @State private var notificationsEnabled = false
    @State private var reminderTime = Date()
    
    let icons = ["flame.fill", "drop.fill", "book.fill", "figure.run", "bed.double.fill", "leaf.fill", "heart.fill", "star.fill"]
    let weekDays = ["S", "M", "T", "W", "T", "F", "S"]
    
    init(userEmail: String, habitToEdit: Habit? = nil) {
        self.userEmail = userEmail
        self.habitToEdit = habitToEdit
        
        // Pre-fill if editing
        if let habit = habitToEdit {
            _name = State(initialValue: habit.name)
            _selectedIcon = State(initialValue: habit.iconName ?? "star.fill")
            _goal = State(initialValue: habit.goalPerDay ?? 1)
            // Convert from model format (1-7) to UI format (0-6)
            _days = State(initialValue: Set(habit.daysOfWeek.map { $0 - 1 }))
            _notificationsEnabled = State(initialValue: habit.notificationsEnabled)
            _reminderTime = State(initialValue: habit.reminderTime ?? Date())
            _habitType = State(initialValue: habit.habitType)
        }
    }
    
    var isPrimary: Bool {
        guard let habit = habitToEdit else { return false }
        return habit.displayOrder == 0
    }
    
    // Color for each day of the week
    private func dayColor(for index: Int) -> Color {
        switch index {
        case 0: return .clarityOrange  // Sunday
        case 1: return .clarityBlue    // Monday
        case 2: return .clarityPurple  // Tuesday
        case 3: return .clarityTeal    // Wednesday
        case 4: return .clarityPink    // Thursday
        case 5: return .clarityBlue    // Friday
        case 6: return .clarityOrange  // Saturday
        default: return .clarityBlue
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Habit Type Picker
                        Picker("Type", selection: $habitType) {
                            ForEach(HabitType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        // Name Input with Magic Wand
                        HStack(spacing: 12) {
                            CustomTextField(
                                icon: habitType == .build ? "tag.fill" : "xmark.circle.fill", 
                                placeholder: habitType == .build ? "What habit do you want to build?" : "What habit do you want to break?", 
                                text: $name
                            )
                            
                            // Hide AI button when editing
                            if habitToEdit == nil {
                                Button {
                                    generateHabit()
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.clarityPurple.gradient)
                                            .frame(width: 50, height: 50)
                                        
                                        if isGenerating {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "wand.and.stars")
                                                .font(.system(size: 20))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .shadow(color: Color.clarityPurple.opacity(0.3), radius: 5, x: 0, y: 2)
                                }
                                .disabled(isGenerating || name.isEmpty)
                            }
                        }

                        // Quick-start templates (only when creating fresh)
                        if habitToEdit == nil {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Quick Start")
                                    .font(.headline)
                                    .padding(.horizontal, 4)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(HabitTemplates.all) { template in
                                            Button(action: { applyTemplate(template) }) {
                                                VStack(spacing: 6) {
                                                    Text(template.emoji)
                                                        .font(.system(size: 22))
                                                    Text(template.name)
                                                        .font(.caption2.bold())
                                                        .foregroundStyle(.primary)
                                                        .lineLimit(1)
                                                }
                                                .frame(width: 84, height: 64)
                                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 4)
                                }
                            }
                        }

                        // Icon Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose an Icon")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                                ForEach(icons, id: \.self) { icon in
                                    IconChip(icon: icon, isSelected: selectedIcon == icon) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedIcon = icon
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color.clarityCard)
                            .cornerRadius(16)
                        }
                        
                        // Goal Selector - Modern Design (Only for Build habits)
                        if habitType == .build {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Daily Goal")
                                    .font(.headline)
                                    .padding(.horizontal, 4)
                                
                                HStack(spacing: 16) {
                                    Button {
                                        if goal > 1 { 
                                            withAnimation { goal -= 1 }
                                        }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(goal > 1 ? Color.clarityBlue : .secondary.opacity(0.3))
                                    }
                                    .disabled(goal <= 1)
                                    
                                    VStack(spacing: 4) {
                                        Text("\(goal)")
                                            .font(.system(size: 48, weight: .bold, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Text(goal == 1 ? "time per day" : "times per day")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(minWidth: 120)
                                    
                                    Button {
                                        if goal < 100 { 
                                            withAnimation { goal += 1 }
                                        }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(Color.clarityBlue)
                                    }
                                    .disabled(goal >= 100)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(Color.clarityCard)
                                .cornerRadius(16)
                            }
                        }
                        
                        // Frequency Selection - Colorful Day Chips
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Which days?")
                                    .font(.headline)
                                
                                Spacer()
                                
                                // Quick select buttons
                                Button("All") {
                                    withAnimation { days = Set(0...6) }
                                }
                                .font(.caption.bold())
                                .foregroundStyle(days.count == 7 ? .white : .clarityBlue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(days.count == 7 ? Color.clarityBlue : Color.clarityBlue.opacity(0.1))
                                .cornerRadius(8)
                                
                                Button("Weekdays") {
                                    withAnimation { days = Set(1...5) }
                                }
                                .font(.caption.bold())
                                .foregroundStyle(days == Set(1...5) ? .white : .clarityPurple)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(days == Set(1...5) ? Color.clarityPurple : Color.clarityPurple.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal, 4)
                            
                            HStack(spacing: 8) {
                                ForEach(0..<7) { index in
                                    DayChip(
                                        day: weekDays[index],
                                        isSelected: days.contains(index),
                                        color: dayColor(for: index)
                                    ) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if days.contains(index) {
                                                days.remove(index)
                                            } else {
                                                days.insert(index)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color.clarityCard)
                            .cornerRadius(16)
                        }
                        
                        // Reminder Section - Cleaner Design
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $notificationsEnabled) {
                                HStack(spacing: 12) {
                                    Image(systemName: "bell.badge.fill")
                                        .font(.title2)
                                        .foregroundStyle(notificationsEnabled ? Color.clarityOrange : .secondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Daily Reminder")
                                            .font(.body.bold())
                                        Text("Get nudged to complete this habit")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .tint(Color.clarityOrange)
                            .padding()
                            .background(Color.clarityCard)
                            .cornerRadius(16)
                            
                            if notificationsEnabled {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundStyle(Color.clarityOrange)
                                    
                                    Text("Remind me at")
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    DatePicker("", selection: $reminderTime, displayedComponents: [.hourAndMinute])
                                        .labelsHidden()
                                        .tint(Color.clarityOrange)
                                }
                                .padding()
                                .background(Color.clarityCard)
                                .cornerRadius(16)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        
                        Spacer(minLength: 20)
                        
                        Button(action: saveHabit) {
                            Text(habitToEdit == nil ? "Create Habit" : "Save Changes")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        // Delete button (only when editing)
                        if habitToEdit != nil {
                            // Set as Primary button
                            Button(action: setAsPrimary) {
                                HStack {
                                    Image(systemName: isPrimary ? "star.fill" : "star")
                                    Text(isPrimary ? "Primary Habit" : "Set as Primary")
                                }
                                .font(.body.bold())
                                .foregroundStyle(isPrimary ? Color.clarityOrange : .white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isPrimary ? Color.clarityOrange.opacity(0.2) : Color.clarityTeal)
                                .cornerRadius(16)
                            }
                            .disabled(isPrimary)
                            
                            Button(action: { showDeleteConfirmation = true }) {
                                Text("Delete Habit")
                                    .font(.body.bold())
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(habitToEdit == nil ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            })
            .alert("Delete Habit?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteHabit()
                }
            } message: {
                Text("This action cannot be undone. All check-in history will be lost.")
            }
        }
    }
    
    private func applyTemplate(_ template: HabitTemplate) {
        withAnimation {
            name = template.name
            selectedIcon = template.icon
            goal = template.goalPerDay
            days = Set(template.daysOfWeek)
        }
    }

    private func generateHabit() {
        guard !name.isEmpty else { return }
        isGenerating = true
        
        Task {
            do {
                // Get user context from profile
                let userContext: UserContext? = if let profile = profiles.first {
                    UserContext(
                        biggestPriority: profile.biggestPriority,
                        idealDay: profile.idealDay,
                        desiredHabit: profile.desiredHabit
                    )
                } else {
                    nil
                }
                
                let suggestion = try await AIService.shared.generateHabit(for: name, userContext: userContext)
                
                await MainActor.run {
                    withAnimation {
                        self.name = suggestion.name
                        self.selectedIcon = suggestion.iconName
                        self.goal = suggestion.goalPerDay
                        self.days = Set(suggestion.daysOfWeek)
                    }
                    isGenerating = false
                }
            } catch {
                print("AI Error: \(error)")
                await MainActor.run {
                    isGenerating = false
                }
            }
        }
    }
    
    private func saveHabit() {
        if let existing = habitToEdit {
            // Update existing habit
            existing.name = name
            existing.iconName = selectedIcon
            existing.goalPerDay = goal
            existing.daysOfWeek = days.map { $0 + 1 } // Convert UI (0-6) to model (1-7)
            existing.notificationsEnabled = notificationsEnabled
            existing.reminderTime = notificationsEnabled ? reminderTime : nil
            existing.habitType = habitType
            try? context.save()
            
            // Update notifications
            if notificationsEnabled {
                Task { @MainActor in
                    NotificationManager.shared.scheduleHabitReminder(
                        habitId: existing.id,
                        habitName: existing.name,
                        habitType: existing.habitType,
                        reminderTime: reminderTime,
                        daysOfWeek: days.map { $0 + 1 } // Convert UI (0-6) to model (1-7)
                    )
                }
            } else {
                Task { @MainActor in
                    NotificationManager.shared.cancelHabitReminder(habitId: existing.id)
                }
            }
            
            // Update widget data
            WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
        } else {
            // Create new habit - assign next available displayOrder
            let allHabits = try? context.fetch(FetchDescriptor<Habit>())
            let maxOrder = allHabits?.map { $0.displayOrder }.max() ?? -1
            
            let habit = Habit(
                ownerEmail: userEmail,
                name: name,
                iconName: selectedIcon,
                goalPerDay: goal,
                daysOfWeek: days.map { $0 + 1 }, // Convert UI (0-6) to model (1-7)
                isActive: true,
                displayOrder: maxOrder + 1,
                notificationsEnabled: notificationsEnabled,
                reminderTime: notificationsEnabled ? reminderTime : nil,
                habitType: habitType
            )
            context.insert(habit)
            try? context.save()
            
            // Schedule notifications if enabled
            if notificationsEnabled {
                Task { @MainActor in
                    NotificationManager.shared.scheduleHabitReminder(
                        habitId: habit.id,
                        habitName: habit.name,
                        habitType: habit.habitType,
                        reminderTime: reminderTime,
                        daysOfWeek: days.map { $0 + 1 } // Convert UI (0-6) to model (1-7)
                    )
                }
            }
        }
        
        // Update widget data
        WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
        
        dismiss()
    }
    
    private func setAsPrimary() {
        guard let existing = habitToEdit else { return }
        
        // Get all habits
        let allHabits = try? context.fetch(FetchDescriptor<Habit>())
        
        // Set this habit to order 0 (primary)
        existing.displayOrder = 0
        
        // Shift all other habits down
        allHabits?.forEach { habit in
            if habit.id != existing.id && habit.displayOrder < 100 {
                habit.displayOrder += 1
            }
        }
        
        try? context.save()
        dismiss()
    }
    
    private func deleteHabit() {
        guard let existing = habitToEdit else { return }
        
        // Cancel notifications
        Task { @MainActor in
            NotificationManager.shared.cancelHabitReminder(habitId: existing.id)
        }
        
        // Delete associated check-ins first
        let habitCheckins = allCheckins.filter { $0.habit?.id == existing.id }
        habitCheckins.forEach { context.delete($0) }
        
        // Then delete the habit
        context.delete(existing)
        try? context.save()
        
        // Update widget data
        WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
        
        dismiss()
    }
}

// MARK: - Add Moment Sheet
// MARK: - Add Transaction Sheet
// ... (omitted)

// MARK: - Add Moment Sheet Import
import PhotosUI

struct AddMomentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let userEmail: String
    let momentToEdit: LifeMoment? // Optional moment for editing
    var prefillTitle: String = ""
    
    @State private var title = ""
    @State private var details = ""
    @State private var date = Date()
    @State private var selectedType: MomentType = .other
    @State private var moodScore: Int = 3
    @State private var showDeleteConfirmation = false
    
    // Photo Picking
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImagesData: [Data] = []
    
    let moodEmojis = ["😢", "😕", "😐", "🙂", "😄"]
    
    init(userEmail: String, momentToEdit: LifeMoment? = nil, prefillTitle: String = "") {
        self.userEmail = userEmail
        self.momentToEdit = momentToEdit
        self.prefillTitle = prefillTitle
        
        // Pre-fill if editing
        if let moment = momentToEdit {
            _title = State(initialValue: moment.title)
            _details = State(initialValue: moment.note ?? "")
            _date = State(initialValue: moment.date)
            _selectedType = State(initialValue: moment.type)
            _moodScore = State(initialValue: Int((moment.moodScore ?? 0.5) * 4) + 1)
            _selectedImagesData = State(initialValue: moment.imagesData ?? [])
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Title Input (Central Question Style)
                        VStack(alignment: .center, spacing: 16) {
                            Text(momentToEdit == nil ? "New Moment" : "Edit Moment")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            CustomTextField(icon: "sparkles", placeholder: "What happened?", text: $title)
                                .font(.system(size: 20, weight: .medium))
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.clarityCard)
                                        .shadow(color: Color.clarityPurple.opacity(0.05), radius: 10, y: 5)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Color.clarityBlue.opacity(0.3), Color.clarityPurple.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        }
                        .padding(.top, 20)
                        
                        // Mood Selector
                        VStack(spacing: 16) {
                            Text("How did this make you feel?")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 12) {
                                ForEach(0..<5) { index in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            moodScore = index + 1
                                        }
                                    } label: {
                                        Text(moodEmojis[index])
                                            .font(.system(size: moodScore == index + 1 ? 44 : 32))
                                            .opacity(moodScore == index + 1 ? 1.0 : 0.4)
                                            .scaleEffect(moodScore == index + 1 ? 1.2 : 1.0)
                                            .frame(width: 50, height: 50)
                                            .background(
                                                Circle()
                                                    .fill(moodScore == index + 1 ? Color.clarityCard : Color.clear)
                                                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                                    .opacity(moodScore == index + 1 ? 1 : 0)
                                            )
                                    }
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color.clarityCard.opacity(0.5))
                            .cornerRadius(24)
                        }
                        
                        // Photos Picker Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Photos")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            photosPickerScrollView
                        }
                        .onChange(of: selectedItems) { _, _ in
                            Task {
                                for item in selectedItems {
                                    if let data = try? await item.loadTransferable(type: Data.self) {
                                        await MainActor.run {
                                            selectedImagesData.append(data)
                                        }
                                    }
                                }
                                selectedItems.removeAll() // Clear selection so we can add more later
                            }
                        }
                        
                        // Moment Type
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            momentTypeScrollView
                        }
                        
                        // Details
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Details")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            ZStack(alignment: .topLeading) {
                                if details.isEmpty {
                                    Text("Add more context here...")
                                        .foregroundStyle(.secondary.opacity(0.5))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                }
                                
                                TextEditor(text: $details)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                            }
                            .frame(minHeight: 120)
                            .background(Color.clarityCard)
                            .cornerRadius(20)
                        }
                        
                        // Date
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Date")
                                    .font(.headline)
                                Spacer()
                                DatePicker("", selection: $date, displayedComponents: [.date])
                                    .labelsHidden()
                                    .tint(Color.clarityPurple)
                            }
                            .padding()
                            .background(Color.clarityCard)
                            .cornerRadius(16)
                        }
                        
                        Spacer(minLength: 20)
                        
                        Button(action: saveMoment) {
                            Text(momentToEdit == nil ? "Save Moment" : "Save Changes")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        // Delete button (only when editing)
                        if momentToEdit != nil {
                            Button(action: { showDeleteConfirmation = true }) {
                                Text("Delete Moment")
                                    .font(.body.bold())
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(24)
                }
            }
            .navigationBarHidden(true) // We are using custom header
            .toolbar(content: {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            })
            .onAppear {
                if !prefillTitle.isEmpty && momentToEdit == nil {
                    title = prefillTitle
                }
            }
            .alert("Delete Moment?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteMoment()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var photosPickerScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Add Button
                PhotosPicker(selection: $selectedItems, matching: .images) {
                    VStack {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        Text("Add")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.clarityPurple)
                    .frame(width: 80, height: 80)
                    .background(Color.clarityPurple.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.clarityPurple.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
                }
                
                // Display Selected Images
                ForEach(selectedImagesData, id: \.self) { data in
                    if let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                Button(action: {
                                    withAnimation {
                                        if let index = selectedImagesData.firstIndex(of: data) {
                                            selectedImagesData.remove(at: index)
                                        }
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white, .red)
                                }
                                .padding(4),
                                alignment: .topTrailing
                            )
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var momentTypeScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(MomentType.allCases) { type in
                    SelectionChip(
                        title: type.rawValue.capitalized,
                        isSelected: selectedType == type
                    ) {
                        withAnimation { selectedType = type }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func saveMoment() {
        if let existing = momentToEdit {
            // Update existing moment
            existing.title = title
            existing.note = details.isEmpty ? nil : details
            existing.date = date
            existing.type = selectedType
            existing.moodScore = Double(moodScore - 1) / 4.0
            existing.imagesData = selectedImagesData // Save images
            try? context.save()
        } else {
            // Create new moment
            let moment = LifeMoment(
                ownerEmail: userEmail,
                date: date,
                title: title,
                note: details.isEmpty ? nil : details,
                moodScore: Double(moodScore - 1) / 4.0,
                type: selectedType,
                imagesData: selectedImagesData // Save images
            )
            context.insert(moment)
            try? context.save()
        }
        dismiss()
    }
    
    private func deleteMoment() {
        guard let existing = momentToEdit else { return }
        context.delete(existing)
        try? context.save()
        dismiss()
    }
}

#Preview {
    AddTaskSheet(userEmail: "preview@example.com")
}

// MARK: - Add Transaction Sheet
struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let userEmail: String
    var prefillAmount: Double = 0.0
    var prefillCategory: TransactionCategory = .other
    var prefillNote: String = ""
    
    @State private var amount = ""
    @State private var date = Date()
    @State private var category: TransactionCategory = .other
    @State private var note = ""
    @State private var recurring = false
    @State private var recurrenceInterval: TransactionInterval = .monthly
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Amount Input (Big & Prominent)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("$")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                TextField("0.00", text: $amount)
                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                            .background(Color.clarityCard)
                            .cornerRadius(20)
                        }
                        
                        // Category Selection (Grid)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                                ForEach(TransactionCategory.allCases) { cat in
                                    SelectionChip(
                                        title: cat.rawValue.capitalized,
                                        isSelected: category == cat
                                    ) {
                                        withAnimation { category = cat }
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color.clarityCard)
                            .cornerRadius(20)
                        }
                        
                        // Note
                        CustomTextField(icon: "note.text", placeholder: "What was this for?", text: $note)
                        
                        // Date & Recurring
                        HStack(alignment: .top, spacing: 16) {
                            // Date Picker Compact
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                                
                                DatePicker("", selection: $date, displayedComponents: [.date])
                                    .labelsHidden()
                                    .tint(Color.clarityBlue)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.clarityCard)
                            .cornerRadius(16)
                            
                            // Recurring Toggle
                            VStack(alignment: .leading, spacing: 8) {
                                Button(action: { withAnimation { recurring.toggle() } }) {
                                    HStack {
                                        Image(systemName: "repeat")
                                            .font(.title3)
                                            .foregroundStyle(recurring ? Color.white : Color.clarityPurple)
                                            .frame(width: 32, height: 32)
                                            .background(recurring ? Color.clarityPurple : Color.clear)
                                            .clipShape(Circle())
                                        
                                        Text("Repeat")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(recurring ? Color.clarityPurple : Color.primary)
                                            
                                        Spacer()
                                    }
                                }
                                
                                if recurring {
                                    Menu {
                                        ForEach(TransactionInterval.allCases) { interval in
                                            Button(interval.displayName) {
                                                recurrenceInterval = interval
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(recurrenceInterval.displayName)
                                                .font(.subheadline)
                                                .foregroundStyle(Color.clarityPurple)
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.caption)
                                                .foregroundStyle(Color.clarityPurple)
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.clarityPurple.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(recurring ? Color.clarityPurple.opacity(0.05) : Color.clarityCard)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(recurring ? Color.clarityPurple : Color.clear, lineWidth: 1)
                            )
                        }
                        
                        Spacer(minLength: 20)
                        
                        Button(action: saveTransaction) {
                            Text("Add Transaction")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(amount.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            })
            .onAppear {
                if prefillAmount > 0 {
                    amount = String(format: "%.2f", prefillAmount)
                }
                if prefillCategory != .other {
                    category = prefillCategory
                }
                if !prefillNote.isEmpty {
                    note = prefillNote
                }
            }
        }
    }
    
    private func saveTransaction() {
        guard let amountValue = Double(amount) else { return }
        
        // Create Transaction
        let transaction = Transaction(
            amount: amountValue,
            date: date,
            category: category,
            note: note.isEmpty ? nil : note,
            isRecurring: recurring,
            recurrenceInterval: recurrenceInterval
        )
        transaction.ownerEmail = userEmail
        
        context.insert(transaction)
        
        // 1. Dopamine Hit (Fun notification)
        FinanceNotificationHelper.triggerNotification(for: transaction)
        
        // 2. Alert Budget Check
        let descriptor = FetchDescriptor<Budget>()
        if let allBudgets = try? context.fetch(descriptor),
           let budget = allBudgets.first(where: { $0.category == category }) {
            
             // Calculate total spent including this one
            let calendar = Calendar.current
            let currentMonth = calendar.component(.month, from: Date())
            let transactionDescriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { $0.ownerEmail == userEmail }
            )
            
            if let monthTransactions = try? context.fetch(transactionDescriptor) {
                 let spent = monthTransactions.filter { 
                     $0.category == category && 
                     calendar.component(.month, from: $0.date) == currentMonth 
                 }.reduce(0) { $0 + $1.amount } + amountValue
                
                if spent > budget.limit {
                    FinanceNotificationHelper.triggerBudgetAlert(status: .over, category: category)
                } else if spent > (budget.limit * 0.8) {
                    FinanceNotificationHelper.triggerBudgetAlert(status: .near, category: category)
                }
            }
        }
        
        try? context.save()
        dismiss()
    }
}
