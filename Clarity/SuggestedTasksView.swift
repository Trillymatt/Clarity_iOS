import SwiftUI
import SwiftData

struct SuggestedTasksView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query private var tasks: [TaskItem]
    
    let userEmail: String
    var title: String = "No tasks yet"
    var subtitle: String = "Here are some suggestions to get started"
    
    @State private var generatingTask: String? = nil
    
    init(userEmail: String, title: String = "No tasks yet", subtitle: String = "Here are some suggestions to get started") {
        self.userEmail = userEmail
        self.title = title
        self.subtitle = subtitle
        _profiles = Query(filter: #Predicate<UserProfile> { $0.email == userEmail })
        _tasks = Query(filter: #Predicate<TaskItem> { $0.ownerEmail == userEmail })
    }
    
    var userProfile: UserProfile? {
        profiles.first
    }
    
    /// Dynamic suggestions from engine based on user's task data
    var suggestions: [SuggestionEngine.TaskSuggestion] {
        SuggestionEngine.shared.generateTaskSuggestions(
            existingTasks: tasks,
            userProfile: userProfile
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestions) { suggestion in
                        SuggestedTaskCard(
                            title: suggestion.name,
                            emoji: suggestion.emoji,
                            icon: suggestion.icon,
                            reason: suggestion.reason,
                            isGenerating: generatingTask == suggestion.name,
                            onAdd: {
                                addTaskWithAI(title: suggestion.name, category: suggestion.category)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.horizontal, -12) // Break out of parent padding
        }
        .padding(.vertical)
    }
    
    private func addTaskWithAI(title: String, category: TaskCategory) {
        generatingTask = title
        
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
                    // Create all subtasks from AI
                    for subtask in result.subtasks {
                        let offsetDate = Calendar.current.date(byAdding: .day, value: subtask.suggestedOffset, to: Date())
                        let isSubtaskToday = subtask.suggestedOffset == 0
                        
                        let task = TaskItem(
                            ownerEmail: userEmail,
                            title: subtask.title,
                            notes: "Part of: \(result.title)",
                            dueDate: offsetDate,
                            isCompleted: false,
                            isToday: isSubtaskToday,
                            category: category
                        )
                        context.insert(task)
                    }
                    
                    try? context.save()
                    generatingTask = nil
                }
            } catch {
                print("AI Error: \(error)")
                await MainActor.run {
                    // Fallback: Create single task if AI fails
                    let task = TaskItem(
                        ownerEmail: userEmail,
                        title: title,
                        isToday: true,
                        category: category
                    )
                    context.insert(task)
                    try? context.save()
                    generatingTask = nil
                }
            }
        }
    }
}

struct SuggestedTaskCard: View {
    let title: String
    let emoji: String
    let icon: String
    var reason: String? = nil
    let isGenerating: Bool
    let onAdd: () -> Void
    
    var body: some View {
        Button(action: onAdd) {
            VStack(spacing: 12) {
                if isGenerating {
                    ProgressView()
                        .font(.system(size: 32))
                } else {
                    Text(emoji)
                        .font(.system(size: 32))
                }
                
                Text(title)
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isGenerating ? .secondary : .primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                if isGenerating {
                    Text("Generating...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.clarityBlue)
                }
                
                // Show personalized reason
                if let reason = reason, !isGenerating {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 130, height: 160)
            .background(Color.clarityCard)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
    }
}
