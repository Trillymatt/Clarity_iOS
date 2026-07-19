import SwiftUI
import SwiftData

struct ActionItemsPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let extractedItems: ExtractedItems
    let userEmail: String
    var onComplete: (() -> Void)? = nil
    
    @State private var selectedMoments: Set<UUID> = []
    @State private var selectedHabits: Set<UUID> = []
    @State private var selectedTasks: Set<UUID> = []
    @State private var showSuccessAlert = false
    
    var selectedCount: Int {
        selectedMoments.count + selectedHabits.count + selectedTasks.count
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 48))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.clarityBlue, .clarityPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .padding(.bottom, 8)
                            
                            Text("Review & Add")
                                .font(.title.bold())
                                .foregroundStyle(.primary)
                            
                            Text("Select the items you want to keep from your weekly reflection.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 24)
                        
                        if extractedItems.isEmpty {
                            EmptyStateView()
                        } else {
                            // Moments Section
                            if !extractedItems.moments.isEmpty {
                                SuggestionSection(
                                    title: "Moments",
                                    icon: "star.fill",
                                    color: .clarityOrange,
                                    items: extractedItems.moments,
                                    selectedItems: $selectedMoments
                                )
                            }
                            
                            // Habits Section
                            if !extractedItems.habits.isEmpty {
                                SuggestionSection(
                                    title: "Habits",
                                    icon: "flame.fill",
                                    color: .clarityTeal,
                                    items: extractedItems.habits,
                                    selectedItems: $selectedHabits
                                )
                            }
                            
                            // Tasks Section
                            if !extractedItems.tasks.isEmpty {
                                SuggestionSection(
                                    title: "Tasks",
                                    icon: "checkmark.circle.fill",
                                    color: .clarityBlue,
                                    items: extractedItems.tasks,
                                    selectedItems: $selectedTasks
                                )
                            }
                        }
                        
                        // Bottom Padding for floating button
                        Color.clear.frame(height: 100)
                    }
                    .padding()
                }
                
                // Floating Action Bar
                VStack {
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.plain)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        
                        Button(action: addSelectedItems) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add \(selectedCount) Items")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.clarityBlue, Color.clarityPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: Color.clarityBlue.opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .disabled(selectedCount == 0)
                        .opacity(selectedCount == 0 ? 0.6 : 1)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .navigationBarHidden(true)
            .alert("Items Added!", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                    // Call completion callback to dismiss parent weekly review
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onComplete?()
                    }
                }
            } message: {
                Text("\(selectedCount) item\(selectedCount == 1 ? "" : "s") added successfully. Check your dashboard!")
            }
        }
        .onAppear {
            // Pre-select all items by default
            selectedMoments = Set(extractedItems.moments.map { $0.id })
            selectedHabits = Set(extractedItems.habits.map { $0.id })
            selectedTasks = Set(extractedItems.tasks.map { $0.id })
        }
    }
    
    private func addSelectedItems() {
        // Create selected moments
        for moment in extractedItems.moments where selectedMoments.contains(moment.id) {
            let lifeMoment = LifeMoment(
                ownerEmail: userEmail,
                date: Date(),
                title: moment.title,
                note: moment.note,
                type: moment.momentType,
                imagesData: nil
            )
            context.insert(lifeMoment)
        }
        
        // Create selected habits
        for habit in extractedItems.habits where selectedHabits.contains(habit.id) {
            let newHabit = Habit(
                ownerEmail: userEmail,
                name: habit.name,
                goalPerDay: habit.goalPerDay,
                displayOrder: 999
            )
            context.insert(newHabit)
        }
        
        // Create selected tasks
        for task in extractedItems.tasks where selectedTasks.contains(task.id) {
            let newTask = TaskItem(
                ownerEmail: userEmail,
                title: task.title,
                isToday: true,
                category: task.taskCategory
            )
            context.insert(newTask)
        }
        
        try? context.save()
        print("✅ Added \(selectedCount) items from weekly review")
        showSuccessAlert = true
    }
}

// MARK: - Subviews

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))
            
            Text("No items found")
                .font(.headline)
            
            Text("Try writing more detailed reflections next time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

struct SuggestionSection<T: Identifiable>: View where T.ID == UUID {
    let title: String
    let icon: String
    let color: Color
    let items: [T]
    @Binding var selectedItems: Set<UUID>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(color)
                
                Spacer()
                
                Button(action: toggleAll) {
                    Text(allSelected ? "Deselect All" : "Select All")
                        .font(.caption.bold())
                        .foregroundStyle(color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(color.opacity(0.1), in: Capsule())
                }
            }
            
            VStack(spacing: 12) {
                if let moments = items as? [SuggestedMoment] {
                    ForEach(moments) { moment in
                        MomentRow(moment: moment, isSelected: selectedItems.contains(moment.id)) {
                            toggleSelection(moment.id)
                        }
                    }
                } else if let habits = items as? [SuggestedHabit] {
                    ForEach(habits) { habit in
                        HabitRow(habit: habit, isSelected: selectedItems.contains(habit.id)) {
                            toggleSelection(habit.id)
                        }
                    }
                } else if let tasks = items as? [SuggestedTask] {
                    ForEach(tasks) { task in
                        TaskRowView(task: task, isSelected: selectedItems.contains(task.id)) {
                            toggleSelection(task.id)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.clarityCard)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
    }
    
    private var allSelected: Bool {
        items.allSatisfy { selectedItems.contains($0.id) }
    }
    
    private func toggleAll() {
        if allSelected {
            items.forEach { selectedItems.remove($0.id) }
        } else {
            items.forEach { selectedItems.insert($0.id) }
        }
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
    }
}

// MARK: - Item Rows

struct MomentRow: View {
    let moment: SuggestedMoment
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.clarityOrange : .secondary.opacity(0.5))
                    .contentShape(Rectangle())
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(moment.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let note = moment.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    Text(moment.type.capitalized)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.clarityOrange.opacity(0.1))
                        .foregroundStyle(Color.clarityOrange)
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
            .padding()
            .background(Color.clarityBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clarityOrange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct HabitRow: View {
    let habit: SuggestedHabit
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.clarityTeal : .secondary.opacity(0.5))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    Text("\(habit.goalPerDay)/day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.clarityBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clarityTeal : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TaskRowView: View {
    let task: SuggestedTask
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.clarityBlue : .secondary.opacity(0.5))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(task.category.capitalized)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.clarityBlue.opacity(0.1))
                        .foregroundStyle(Color.clarityBlue)
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
            .padding()
            .background(Color.clarityBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clarityBlue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
