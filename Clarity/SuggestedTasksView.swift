import SwiftUI
import SwiftData

struct SuggestedTasksView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    
    let userEmail: String
    var title: String = "No tasks yet"
    var subtitle: String = "Here are some suggestions to get started"
    
    @State private var generatingTask: String? = nil
    
    // Priority-based task suggestions
    let priorityTasks: [String: [(String, String, String)]] = [
        "Career": [
            ("Update Resume", "📝", "doc.text.fill"),
            ("Network with Colleague", "🤝", "person.2.fill"),
            ("Learn New Skill", "🎓", "graduationcap.fill"),
            ("Review Performance", "📊", "chart.bar.fill"),
        ],
        "Health": [
            ("Schedule Checkup", "🏥", "cross.case.fill"),
            ("Meal Prep Sunday", "🥗", "carrot.fill"),
            ("30min Workout", "💪", "figure.run"),
            ("Track Water Intake", "💧", "drop.fill"),
        ],
        "Relationships": [
            ("Call Family Member", "📞", "phone.fill"),
            ("Schedule Date Night", "❤️", "heart.fill"),
            ("Write Thank You", "✉️", "envelope.fill"),
            ("Plan Hangout", "🎉", "party.popper.fill"),
        ],
        "Finance": [
            ("Review Budget", "💰", "dollarsign.circle.fill"),
            ("Track Expenses", "📊", "chart.pie.fill"),
            ("Research Investment", "📈", "chart.line.uptrend.xyaxis"),
            ("Pay Bills", "💳", "creditcard.fill"),
        ],
        "Learning": [
            ("Read 10 Pages", "📚", "book.fill"),
            ("Take Online Course", "💻", "laptopcomputer"),
            ("Practice New Skill", "🎯", "target"),
            ("Watch Tutorial", "🎬", "play.rectangle.fill"),
        ]
    ]
    
    // Generic suggestions (fallback)
    let genericTasks = [
        ("Morning Routine", "☀️", "sunrise.fill"),
        ("Review Goals", "🎯", "target"),
        ("Plan Day", "📅", "calendar"),
        ("Exercise", "💪", "figure.run"),
    ]
    
    var userProfile: UserProfile? {
        profiles.first { $0.email == userEmail }
    }
    
    var suggestions: [(String, String, String)] {
        guard let profile = userProfile else {
            return genericTasks
        }
        
        var personalizedTasks: [(String, String, String)] = []
        
        // 1. Add tasks based on biggest priority
        if let priority = profile.biggestPriority, !priority.isEmpty {
            // Try to match priority to our categories
            for (category, tasks) in priorityTasks {
                if priority.lowercased().contains(category.lowercased()) {
                    personalizedTasks.append(contentsOf: tasks)
                    break
                }
            }
        }
        
        // 2. Add tasks from focus areas
        if !profile.focusAreas.isEmpty {
            for area in profile.focusAreas {
                if let areaTasks = priorityTasks[area] {
                    personalizedTasks.append(contentsOf: areaTasks)
                }
            }
        }
        
        // 3. Fallback to generic if nothing matched
        if personalizedTasks.isEmpty {
            personalizedTasks = genericTasks
        }
        
        // Remove duplicates and limit to 8
        var seen = Set<String>()
        return personalizedTasks.filter { task in
            let isNew = !seen.contains(task.0)
            seen.insert(task.0)
            return isNew
        }.prefix(8).map { $0 }
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
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestions, id: \.0) { suggestion in
                        SuggestedTaskCard(
                            title: suggestion.0,
                            emoji: suggestion.1,
                            icon: suggestion.2,
                            isGenerating: generatingTask == suggestion.0,
                            onAdd: {
                                addTaskWithAI(title: suggestion.0)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    private func addTaskWithAI(title: String) {
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
                            category: .personal
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
                        category: .personal
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
            }
            .frame(width: 120, height: 140)
            .background(Color.clarityCard)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
    }
}
