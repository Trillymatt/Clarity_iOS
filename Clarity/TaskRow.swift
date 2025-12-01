import SwiftUI
import SwiftData

struct TaskRow: View {
    @Environment(\.modelContext) private var context
    let task: TaskItem
    
    @State private var showEditSheet = false
    
    var body: some View {
        HStack {
            // Completion Toggle
            Button(action: toggleCompletion) {
                Image(systemName: completionIconName)
                    .font(.title2)
                    .foregroundStyle(completionColor)
            }
            
            // Task Info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(textColor)
                
                if let due = task.dueDate {
                    Text(due, style: .date)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showEditSheet = true
            }
            
            Spacer()
            
            // Today Toggle
            Button(action: toggleToday) {
                Image(systemName: todayIconName)
                    .foregroundStyle(todayColor)
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showEditSheet) {
            EditTaskSheet(task: task)
                .presentationDetents([.medium, .large])
        }
    }
    
    // MARK: - Helpers
    
    private var completionIconName: String {
        task.isCompleted ? "checkmark.circle.fill" : "circle"
    }
    
    private var completionColor: Color {
        task.isCompleted ? .green : .clarityBlue
    }
    
    private var textColor: Color {
        task.isCompleted ? .secondary : .primary
    }
    
    private var todayIconName: String {
        task.isToday ? "star.fill" : "star"
    }
    
    private var todayColor: Color {
        task.isToday ? .clarityOrange : .secondary
    }
    
    private func toggleCompletion() {
        withAnimation {
            task.isCompleted.toggle()
            if task.isCompleted {
                task.completedDate = Date()
                // Cancel notification when task is completed
                Task { @MainActor in
                    NotificationManager.shared.cancelTaskDeadline(taskId: task.id)
                }
            } else {
                task.completedDate = nil
                // Reschedule notification if task was incompleted and has future due date
                if let dueDate = task.dueDate, task.notifyOnDueDate, dueDate >= Date() {
                    Task { @MainActor in
                        NotificationManager.shared.scheduleTaskDeadline(
                            taskId: task.id,
                            taskTitle: task.title,
                            dueDate: dueDate
                        )
                    }
                }
            }
        }
        try? context.save()
    }
    
    private func toggleToday() {
        withAnimation {
            task.isToday.toggle()
        }
        try? context.save()
    }
}
