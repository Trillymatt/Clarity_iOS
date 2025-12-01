import SwiftUI
import SwiftData

struct CompletedTasksView: View {
    @Environment(\.modelContext) private var context
    let userEmail: String
    @Query private var completedTasks: [TaskItem]
    
    init(userEmail: String) {
        self.userEmail = userEmail
        _completedTasks = Query(filter: #Predicate { $0.isCompleted == true && $0.ownerEmail == userEmail }, sort: \TaskItem.completedDate, order: .reverse)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                if completedTasks.isEmpty {
                    ContentUnavailableView("No completed tasks", systemImage: "checkmark.circle", description: Text("Tasks you finish will appear here."))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(groupedTasks(), id: \.key) { date, tasks in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(dateLabel(for: date))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal)
                                    
                                    ForEach(tasks) { task in
                                        TaskRow(task: task)
                                            .padding(.horizontal)
                                            .transition(.move(edge: .leading).combined(with: .opacity))
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Completed")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    EditButton() // Allows deletion if we add onDelete to ForEach, but TaskRow handles toggle
                }
            }
        }
    }
    
    private func groupedTasks() -> [(key: Date, value: [TaskItem])] {
        let groups = Dictionary(grouping: completedTasks) { task in
            Calendar.current.startOfDay(for: task.completedDate ?? task.dueDate ?? Date())
        }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { ($0.completedDate ?? Date()) > ($1.completedDate ?? Date()) }) }
    }
    
    private func dateLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }
}
