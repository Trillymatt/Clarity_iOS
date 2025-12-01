import SwiftUI
import SwiftData

struct SuggestedHabitsView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    
    let userEmail: String
    
    @State private var generatingHabit: String? = nil
    
    // Focus area mapped suggestions
    let allSuggestions: [String: [(String, String, String)]] = [
        "Health": [
            ("Drink Water", "💧", "drop.fill"),
            ("Morning Exercise", "🏃", "figure.run"),
            ("Healthy Sleep", "😴", "bed.double.fill"),
            ("Stretch", "🤸", "figure.flexibility"),
        ],
        "Mindfulness": [
            ("Meditation", "🧘", "sparkles"),
            ("Gratitude Journal", "📝", "heart.text.square.fill"),
            ("Deep Breathing", "🌬️", "wind"),
            ("Mindful Walking", "🚶", "figure.walk"),
        ],
        "Learning": [
            ("Read Daily", "📚", "book.fill"),
            ("Learn Something New", "🎓", "graduationcap.fill"),
            ("Practice Skill", "🎯", "target"),
            ("Take Course", "💻", "laptopcomputer"),
        ],
        "Productivity": [
            ("Plan Tomorrow", "📋", "list.bullet"),
            ("Time Block", "⏰", "clock.fill"),
            ("Focus Session", "🎯", "scope"),
            ("Review Goals", "✅", "checkmark.circle.fill"),
        ]
    ]
    
    var userProfile: UserProfile? {
        profiles.first { $0.email == userEmail }
    }
    
    var suggestions: [(String, String, String)] {
        guard let profile = userProfile else {
            // Fallback to generic suggestions
            return [
                ("Drink Water", "💧", "drop.fill"),
                ("Morning Exercise", "🏃", "figure.run"),
                ("Read Daily", "📚", "book.fill"),
                ("Meditation", "🧘", "sparkles"),
                ("Gratitude Journal", "📝", "heart.text.square.fill"),
                ("Healthy Sleep", "😴", "bed.double.fill"),
            ]
        }
        
        var personalizedSuggestions: [(String, String, String)] = []
        
        // 1. Add desired habit first if provided
        if let desiredHabit = profile.desiredHabit, !desiredHabit.isEmpty {
            personalizedSuggestions.append((desiredHabit, "⭐", "star.fill"))
        }
        
        // 2. Filter by focus areas
        if !profile.focusAreas.isEmpty {
            for area in profile.focusAreas {
                if let areaSuggestions = allSuggestions[area] {
                    personalizedSuggestions.append(contentsOf: areaSuggestions)
                }
            }
        } else {
            // If no focus areas, show popular mix
            personalizedSuggestions.append(contentsOf: allSuggestions["Health"] ?? [])
            personalizedSuggestions.append(contentsOf: allSuggestions["Mindfulness"] ?? [])
        }
        
        // Remove duplicates and limit to 8
        var seen = Set<String>()
        return personalizedSuggestions.filter { suggestion in
            let isNew = !seen.contains(suggestion.0)
            seen.insert(suggestion.0)
            return isNew
        }.prefix(8).map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("No habits yet")
                    .font(.title2.bold())
                Text("Here are some suggestions to build better habits")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestions, id: \.0) { suggestion in
                        SuggestedHabitCard(
                            title: suggestion.0,
                            emoji: suggestion.1,
                            icon: suggestion.2,
                            isGenerating: generatingHabit == suggestion.0,
                            onAdd: {
                                addHabitWithAI(title: suggestion.0)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
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
                        .foregroundStyle(Color.clarityPurple)
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
