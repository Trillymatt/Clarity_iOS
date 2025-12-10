import SwiftUI
import SwiftData

struct SuggestedMomentsView: View {
    @Environment(\.modelContext) private var context
    @Query private var recentMoments: [LifeMoment]
    
    @Binding var showAdd: Bool
    @Binding var prefillTitle: String
    let userEmail: String
    
    init(showAdd: Binding<Bool>, prefillTitle: Binding<String>, userEmail: String) {
        self._showAdd = showAdd
        self._prefillTitle = prefillTitle
        self.userEmail = userEmail
        
        // Query recent moments (last 7 days)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        _recentMoments = Query(filter: #Predicate<LifeMoment> { 
            $0.ownerEmail == userEmail && $0.date >= weekAgo 
        })
    }
    
    @State private var selectedSuggestion: (type: MomentType, mood: Int, prompt: String)? = nil
    @State private var showQuickAdd = false
    
    /// Build context from user's recent moments
    var suggestionContext: SuggestionEngine.UserContextData {
        var context = SuggestionEngine.UserContextData()
        
        // Recent moment types
        context.recentMomentTypes = recentMoments.map { $0.type }
        
        // Days since last gratitude
        let gratitudeMoments = recentMoments.filter { $0.type == .gratitude }
        if let lastGratitude = gratitudeMoments.max(by: { $0.date < $1.date }) {
            let days = Calendar.current.dateComponents([.day], from: lastGratitude.date, to: Date()).day ?? 999
            context.daysSinceLastGratitude = days
        }
        
        return context
    }
    
    /// Dynamic suggestions from engine
    var suggestions: [SuggestionEngine.MomentSuggestion] {
        SuggestionEngine.shared.generateMomentSuggestions(context: suggestionContext)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Capture Your Moments")
                    .font(.title2.bold())
                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestions) { suggestion in
                        SuggestedMomentCard(
                            title: suggestion.title,
                            emoji: suggestion.emoji,
                            icon: suggestion.icon,
                            subtitle: suggestion.subtitle,
                            isPriority: suggestion.isPriority,
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
                .padding(.horizontal, 12)
            }
            .padding(.horizontal, -12) // Break out of parent padding
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
    
    private var headerSubtitle: String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        switch weekday {
        case 2: return "Start the week with intention"
        case 6: return "Celebrate your Friday wins!"
        case 7, 1: return "Weekend reflections"
        default: return "What made today special?"
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
    let isPriority: Bool
    let onTap: () -> Void
    
    init(title: String, emoji: String, icon: String, subtitle: String, isPriority: Bool = false, onTap: @escaping () -> Void) {
        self.title = title
        self.emoji = emoji
        self.icon = icon
        self.subtitle = subtitle
        self.isPriority = isPriority
        self.onTap = onTap
    }
    
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
