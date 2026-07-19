import SwiftUI
import SwiftData

struct TaskRow: View {
    @Environment(\.modelContext) private var context
    let task: TaskItem
    
    @State private var showEditSheet = false
    @State private var showShareSheet = false
    
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
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.headline)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(textColor)
                    
                    // Past Due badge
                    if task.isOverdue {
                        Text("Past Due")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                }
                
                if let due = task.dueDate {
                    Text(due, style: .date)
                        .font(.caption)
                        .foregroundStyle(task.isOverdue ? Color.red : Color.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showEditSheet = true
            }
            
            Spacer()
            
            // Share button
            Menu {
                Button {
                    showShareSheet = true
                } label: {
                    Label("Share with Friend", systemImage: "person.badge.plus")
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundStyle(Color.clarityBlue)
                    .padding(8)
                    .background(Color.clarityBlue.opacity(0.1))
                    .clipShape(Circle())
            }
            
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
        .sheet(isPresented: $showShareSheet) {
            FriendPickerSheet(
                itemType: "task",
                itemId: task.id.uuidString,
                itemTitle: task.title
            )
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
                task.isInProgress = false
                // Cancel notification when task is completed
                Task { @MainActor in
                    NotificationManager.shared.cancelTaskDeadline(taskId: task.id)
                }
                // Stop Live Activity when task is completed
                Task { @MainActor in
                    if LiveActivityManager.shared.activeTaskId == task.id.uuidString {
                        LiveActivityManager.shared.stopTaskActivity()
                    }
                }
                
                // DATA SYNC: Post to Friends Feed (if sharing is enabled)
                if UserDefaults.standard.bool(forKey: "shareActivityWithFriends") {
                    Task {
                        await CloudKitService.shared.postActivity(
                            type: "task",
                            title: task.title,
                            iconName: "checkmark.circle.fill"
                        )
                    }
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
