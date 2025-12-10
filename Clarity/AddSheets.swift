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
                        
                        // Date & Priority
                        VStack(spacing: 16) {
                            Toggle(isOn: $isToday) {
                                Label("Do it Today", systemImage: "star.fill")
                                    .foregroundStyle(isToday ? Color.clarityOrange : .primary)
                            }
                            .padding()
                            .background(Color.clarityCard)
                            .cornerRadius(12)
                            
                            if !isToday {
                                DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])
                                    .padding()
                                    .background(Color.clarityCard)
                                    .cornerRadius(12)
                                
                                // Notification toggle for due date
                                Toggle(isOn: $notifyOnDueDate) {
                                    Label("Remind me on due date", systemImage: "bell.fill")
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
            _days = State(initialValue: Set(habit.daysOfWeek))
            _notificationsEnabled = State(initialValue: habit.notificationsEnabled)
            _reminderTime = State(initialValue: habit.reminderTime ?? Date())
        }
    }
    
    var isPrimary: Bool {
        guard let habit = habitToEdit else { return false }
        return habit.displayOrder == 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Name Input with Magic Wand
                        HStack(spacing: 12) {
                            CustomTextField(icon: "tag.fill", placeholder: "Habit Name (e.g. Drink Water)", text: $name)
                            
                            // Hide AI button when editing
                            if habitToEdit == nil {
                                Button {
                                    generateHabit()
                                } label: {
                                    Image(systemName: "wand.and.stars")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                        .frame(width: 50, height: 50)
                                        .background(isGenerating ? Color.gray : Color.clarityPurple)
                                        .cornerRadius(12)
                                        .shadow(color: Color.clarityPurple.opacity(0.3), radius: 5, x: 0, y: 2)
                                }
                                .disabled(isGenerating || name.isEmpty)
                            }
                        }
                        
                        // Icon Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Icon")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                                ForEach(icons, id: \.self) { icon in
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundStyle(selectedIcon == icon ? .white : Color.clarityPurple)
                                        .frame(width: 44, height: 44)
                                        .background(selectedIcon == icon ? Color.clarityPurple : Color.clarityCard)
                                        .clipShape(Circle())
                                        .onTapGesture { withAnimation { selectedIcon = icon } }
                                }
                            }
                        }
                        
                        // Goal
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Daily Goal: \(goal) times")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            Stepper("Goal", value: $goal, in: 1...100)
                                .padding()
                                .background(Color.clarityCard)
                                .cornerRadius(12)
                        }
                        
                        // Frequency
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Frequency")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            HStack(spacing: 8) {
                                ForEach(0..<7) { index in
                                    SelectionChip(title: String(weekDays[index].prefix(1)), isSelected: days.contains(index)) {
                                        if days.contains(index) { days.remove(index) } else { days.insert(index) }
                                    }
                                }
                            }
                        }
                        
                        // Notifications
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $notificationsEnabled) {
                                Label("Reminder Notifications", systemImage: "bell.fill")
                            }
                            .tint(Color.clarityBlue)
                            .padding()
                            .background(Color.clarityCard)
                            .cornerRadius(12)
                            
                            if notificationsEnabled {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Reminder Time")
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 4)
                                    
                                    DatePicker("Time", selection: $reminderTime, displayedComponents: [.hourAndMinute])
                                        .datePickerStyle(.wheel)
                                        .labelsHidden()
                                        .padding()
                                        .background(Color.clarityCard)
                                        .cornerRadius(12)
                                }
                                .transition(.opacity)
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
            existing.daysOfWeek = Array(days)
            existing.notificationsEnabled = notificationsEnabled
            existing.reminderTime = notificationsEnabled ? reminderTime : nil
            try? context.save()
            
            // Update notifications
            if notificationsEnabled {
                Task { @MainActor in
                    NotificationManager.shared.scheduleHabitReminder(
                        habitId: existing.id,
                        habitName: existing.name,
                        reminderTime: reminderTime,
                        daysOfWeek: Array(days)
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
                daysOfWeek: Array(days),
                isActive: true,
                displayOrder: maxOrder + 1,
                notificationsEnabled: notificationsEnabled,
                reminderTime: notificationsEnabled ? reminderTime : nil
            )
            context.insert(habit)
            try? context.save()
            
            // Schedule notifications if enabled
            if notificationsEnabled {
                Task { @MainActor in
                    NotificationManager.shared.scheduleHabitReminder(
                        habitId: habit.id,
                        habitName: habit.name,
                        reminderTime: reminderTime,
                        daysOfWeek: Array(days)
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
            // Convert Double (0.0-1.0) back to Int (1-5)
            _moodScore = State(initialValue: Int((moment.moodScore ?? 0.5) * 4) + 1)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Mood Selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How are you feeling?")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            HStack(spacing: 16) {
                                ForEach(0..<5) { index in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            moodScore = index + 1
                                        }
                                    } label: {
                                        Text(moodEmojis[index])
                                            .font(.system(size: moodScore == index + 1 ? 48 : 36))
                                            .opacity(moodScore == index + 1 ? 1.0 : 0.4)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clarityCard)
                            .cornerRadius(16)
                        }
                        
                        // Title Input
                        CustomTextField(icon: "sparkles", placeholder: "What happened?", text: $title)
                        
                        // Moment Type
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Type")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
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
                        
                        // Details
                        CustomTextEditor(title: "Tell the story", text: $details)
                        
                        // Date
                        VStack(alignment: .leading, spacing: 12) {
                            Text("When did this happen?")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            DatePicker("Date", selection: $date, displayedComponents: [.date])
                                .datePickerStyle(.graphical)
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
                    .padding()
                }
            }
            .navigationTitle(momentToEdit == nil ? "New Moment" : "Edit Moment")
            .navigationBarTitleDisplayMode(.inline)
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
    
    private func saveMoment() {
        if let existing = momentToEdit {
            // Update existing moment
            existing.title = title
            existing.note = details.isEmpty ? nil : details
            existing.date = date
            existing.type = selectedType
            existing.moodScore = Double(moodScore - 1) / 4.0
            try? context.save()
        } else {
            // Create new moment
            let moment = LifeMoment(
                ownerEmail: userEmail,
                date: date,
                title: title,
                note: details.isEmpty ? nil : details,
                moodScore: Double(moodScore - 1) / 4.0, // Convert Int (1-5) to Double (0.0-1.0 range)
                type: selectedType
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
