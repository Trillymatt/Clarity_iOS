import SwiftUI
import SwiftData

struct SuggestedHabitsView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query private var habits: [Habit]
    
    let userEmail: String
    
    @State private var generatingHabit: String? = nil
    
    init(userEmail: String) {
        self.userEmail = userEmail
        _profiles = Query(filter: #Predicate<UserProfile> { $0.email == userEmail })
        _habits = Query(filter: #Predicate<Habit> { $0.ownerEmail == userEmail && $0.isActive == true })
    }
    
    var userProfile: UserProfile? {
        profiles.first
    }
    
    /// Build context from user's existing data
    var suggestionContext: SuggestionEngine.UserContextData {
        var context = SuggestionEngine.UserContextData()
        
        // Existing habits
        context.existingHabits = habits.map { $0.name }
        
        // Categorize existing habits
        let engine = SuggestionEngine.shared
        context.habitCategories = Set(habits.map { engine.categorizeHabit($0.name) })
        
        // Focus areas from profile
        if let profile = userProfile {
            context.focusAreas = profile.focusAreas
        }
        
        return context
    }
    
    /// Dynamic suggestions from engine
    var suggestions: [SuggestionEngine.HabitSuggestion] {
        SuggestionEngine.shared.generateHabitSuggestions(context: suggestionContext)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                if habits.isEmpty {
                    Text("No habits yet")
                        .font(.title2.bold())
                    Text("Here are some suggestions to build better habits")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Expand Your Routine")
                        .font(.title2.bold())
                    Text("Try something new based on your goals")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestions) { suggestion in
                        SuggestedHabitCard(
                            title: suggestion.name,
                            emoji: suggestion.emoji,
                            icon: suggestion.icon,
                            reason: suggestion.reason,
                            isGenerating: generatingHabit == suggestion.name,
                            onAdd: {
                                addHabitWithAI(title: suggestion.name)
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
    
    private func addHabitWithAI(title: String) {
        generatingHabit = title
        
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
                
                let suggestion = try await AIService.shared.generateHabit(for: title, userContext: userContext)
                
                await MainActor.run {
                    let habit = Habit(
                        ownerEmail: userEmail,
                        name: suggestion.name,
                        iconName: suggestion.iconName,
                        goalPerDay: suggestion.goalPerDay,
                        daysOfWeek: suggestion.daysOfWeek,
                        isActive: true
                    )
                    context.insert(habit)
                    try? context.save()
                    generatingHabit = nil
                }
            } catch {
                print("AI Error: \(error)")
                await MainActor.run {
                    // Fallback: Create simple habit if AI fails
                    let habit = Habit(
                        ownerEmail: userEmail,
                        name: title,
                        iconName: "star.fill",
                        goalPerDay: 1,
                        daysOfWeek: Array(0...6),
                        isActive: true
                    )
                    context.insert(habit)
                    try? context.save()
                    generatingHabit = nil
                }
            }
        }
    }
}

struct SuggestedHabitCard: View {
    let title: String
    let emoji: String
    let icon: String
    let reason: String?
    let isGenerating: Bool
    let onAdd: () -> Void
    
    init(title: String, emoji: String, icon: String, reason: String? = nil, isGenerating: Bool, onAdd: @escaping () -> Void) {
        self.title = title
        self.emoji = emoji
        self.icon = icon
        self.reason = reason
        self.isGenerating = isGenerating
        self.onAdd = onAdd
    }
    
    var body: some View {
        Button(action: onAdd) {
            VStack(spacing: 8) {
                if isGenerating {
                    ProgressView()
                        .font(.system(size: 32))
                } else {
                    Text(emoji)
                        .font(.system(size: 32))
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(isGenerating ? .secondary : .primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let reason = reason, !isGenerating {
                        Text(reason)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                if isGenerating {
                    Text("Generating...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.clarityPurple)
                }
            }
            .frame(width: 120, height: 150)
            .background(Color.clarityCard)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
    }
}

