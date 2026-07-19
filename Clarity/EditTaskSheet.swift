import SwiftUI
import SwiftData

struct EditTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var task: TaskItem
    @State private var showDeleteConfirmation = false
    
    // Local state for date handling
    @State private var isToday: Bool
    @State private var dueDate: Date
    @State private var notifyOnDueDate: Bool
    
    init(task: TaskItem) {
        self.task = task
        _isToday = State(initialValue: task.isToday)
        _dueDate = State(initialValue: task.dueDate ?? Date())
        _notifyOnDueDate = State(initialValue: task.notifyOnDueDate)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Title Input
                        CustomTextField(icon: "checkmark.circle.fill", placeholder: "What needs to be done?", text: $task.title)
                        
                        // Category Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(TaskCategory.allCases) { cat in
                                        SelectionChip(title: cat.rawValue.capitalized, isSelected: task.category == cat) {
                                            withAnimation { task.category = cat }
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
                                    let weekday = Calendar.current.component(.weekday, from: Date())
                                    let daysUntilNextMonday = (9 - weekday) % 7 + 7
                                    dueDate = Calendar.current.date(byAdding: .day, value: daysUntilNextMonday, to: Date()) ?? Date()
                                }
                            }
                            
                            // Custom date picker (compact)
                            DisclosureGroup("Pick a specific date") {
                                DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .onChange(of: dueDate) { _, newValue in
                                        isToday = Calendar.current.isDateInToday(newValue)
                                    }
                            }
                            .padding()
                            .background(Color.clarityCard)
                            .cornerRadius(12)
                            
                            // Clear date option
                            Button {
                                isToday = false
                                task.dueDate = nil
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Clear Due Date")
                                }
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.clarityCard)
                                .cornerRadius(12)
                            }
                            
                            // Notification toggle
                            if !isToday && task.dueDate != nil {
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
                        
                        // Notes
                        CustomTextEditor(title: "Notes (Optional)", text: Binding(
                            get: { task.notes ?? "" },
                            set: { task.notes = $0.isEmpty ? nil : $0 }
                        ))
                        
                        Spacer(minLength: 20)
                        
                        // Save Button
                        Button(action: saveChanges) {
                            Text("Save Changes")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        // Delete Button
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
                    .padding()
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            })
            .alert("Delete Task?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    context.delete(task)
                    try? context.save()
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    private func saveChanges() {
        // Update task with local state
        task.isToday = isToday
        task.dueDate = isToday ? nil : dueDate
        task.notifyOnDueDate = notifyOnDueDate
        
        try? context.save()
        
        // Handle notifications
        if !isToday && notifyOnDueDate && dueDate >= Date() {
            Task { @MainActor in
                NotificationManager.shared.scheduleTaskDeadline(
                    taskId: task.id,
                    taskTitle: task.title,
                    dueDate: dueDate
                )
            }
        } else {
            Task { @MainActor in
                NotificationManager.shared.cancelTaskDeadline(taskId: task.id)
            }
        }
        
        dismiss()
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

struct QuickDateButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption.bold())
            }
            .frame(width: 80, height: 80)
            .foregroundStyle(color)
            .background(Color.clarityCard)
            .cornerRadius(12)
            .shadow(color: color.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
}
