import SwiftUI
import SwiftData

struct SuggestedMomentsView: View {
    @Environment(\.modelContext) private var context
    @Binding var showAdd: Bool
    @Binding var prefillTitle: String
    let userEmail: String
    
    // Updated: Pass type and mood instead of title
    let suggestions: [(title: String, emoji: String, icon: String, subtitle: String, type: MomentType, mood: Int)] = [
        ("Today's Win", "🏆", "trophy.fill", "Something you accomplished", .win, 4), // Happy mood
        ("Grateful For", "🙏", "heart.fill", "What made you smile?", .gratitude, 4),
        ("New Learning", "💡", "lightbulb.fill", "Something you discovered", .other, 3),
        ("Kind Act", "💝", "gift.fill", "How you helped someone", .connection, 4),
        ("Proud Moment", "⭐", "star.fill", "Something you're proud of", .win, 4),
        ("Connection", "🤝", "person.2.fill", "A meaningful conversation", .connection, 4),
        ("Challenge", "⚡", "bolt.fill", "Something difficult you faced", .challenge, 2),
        ("Reflection", "💭", "cloud.sun.fill", "A thought or realization", .other, 3),
    ]
    
    @State private var selectedSuggestion: (type: MomentType, mood: Int, prompt: String)? = nil
    @State private var showQuickAdd = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Capture Your Moments")
                    .font(.title2.bold())
                Text("What made today special?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestions, id: \.title) { suggestion in
                        SuggestedMomentCard(
                            title: suggestion.title,
                            emoji: suggestion.emoji,
                            icon: suggestion.icon,
                            subtitle: suggestion.subtitle,
                            onTap: {
                                selectedSuggestion = (
                                    type: suggestion.type,
                                    mood: suggestion.mood,
                                    prompt: questionFor(type: suggestion.type)
                                )
                                showQuickAdd = true
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .sheet(isPresented: $showQuickAdd) {
            if let suggestion = selectedSuggestion {
                QuickAddMomentSheet(
                    userEmail: userEmail,
                    preselectedType: suggestion.type,
                    preselectedMood: suggestion.mood,
                    promptQuestion: suggestion.prompt
                )
            }
        }
    }
    
    private func questionFor(type: MomentType) -> String {
        switch type {
        case .win: return "What's your win?"
        case .gratitude: return "What are you grateful for?"
        case .connection: return "What connection did you make?"
        case .challenge: return "What challenge did you face?"
        case .other: return "What happened?"
        }
    }
}

struct SuggestedMomentCard: View {
    let title: String
    let emoji: String
    let icon: String
    let subtitle: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: 36))
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.clarityTeal)
            }
            .frame(width: 140, height: 160)
            .background(Color.clarityCard)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Add Moment Sheet
struct QuickAddMomentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let userEmail: String
    let preselectedType: MomentType
    let preselectedMood: Int
    let promptQuestion: String
    
    @State private var title = ""
    @State private var moodScore: Int
    
    let moodEmojis = ["😢", "😕", "😐", "🙂", "😄"]
    
    init(userEmail: String, preselectedType: MomentType, preselectedMood: Int, promptQuestion: String) {
        self.userEmail = userEmail
        self.preselectedType = preselectedType
        self.preselectedMood = preselectedMood
        self.promptQuestion = promptQuestion
        _moodScore = State(initialValue: preselectedMood + 1) // Convert 0-4 to 1-5
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Central question
                    Text(promptQuestion)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.top, 40)
                    
                    // Text input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your answer:")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        
                        ZStack(alignment: .topLeading) {
                            // Placeholder
                            if title.isEmpty {
                                Text("Start typing...")
                                    .font(.body)
                                    .foregroundStyle(.secondary.opacity(0.5))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                            }
                            
                            TextEditor(text: $title)
                                .font(.body)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 140)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.clarityCard)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.clarityTeal.opacity(0.6), Color.clarityPurple.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: Color.clarityTeal.opacity(0.15), radius: 12, x: 0, y: 4)
                    }
                    .padding(.horizontal, 24)
                    
                    // Mood quick-adjust
                    VStack(spacing: 12) {
                        Text("How does this make you feel?")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 16) {
                            ForEach(0..<5) { index in
                                Button {
                                    withAnimation(.spring(response: 0.2)) {
                                        moodScore = index + 1
                                    }
                                } label: {
                                    Text(moodEmojis[index])
                                        .font(.system(size: moodScore == index + 1 ? 44 : 32))
                                        .opacity(moodScore == index + 1 ? 1.0 : 0.4)
                                        .scaleEffect(moodScore == index + 1 ? 1.1 : 1.0)
                                }
                            }
                        }
                        .padding()
                        .background(Color.clarityCard)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 24)
                    
                    // Save button
                    Button(action: saveMoment) {
                        Text("Save Moment")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
                                    ? Color.gray 
                                    : Color.clarityTeal
                            )
                            .cornerRadius(12)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .background(Color.clarityBackground)
            .navigationTitle("New Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func saveMoment() {
        let moment = LifeMoment(
            ownerEmail: userEmail,
            date: Date(),
            title: title,
            note: nil,
            moodScore: Double(moodScore - 1) / 4.0,
            type: preselectedType
        )
        context.insert(moment)
        try? context.save()
        dismiss()
    }
}
