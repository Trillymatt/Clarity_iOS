import SwiftUI
import SwiftData

struct MoodCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let userEmail: String
    
    @State private var selectedMood = 3 // 1-5 scale
    @State private var selectedEmotion = "Content"
    @State private var note = ""
    
    let moodOptions = [
        (emoji: "😢", label: "Rough", value: 1),
        (emoji: "😕", label: "Low", value: 2),
        (emoji: "😐", label: "Okay", value: 3),
        (emoji: "🙂", label: "Good", value: 4),
        (emoji: "😄", label: "Great", value: 5)
    ]
    
    let emotions = ["Grateful", "Anxious", "Content", "Excited", "Tired", "Peaceful", "Frustrated", "Joyful"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Text("How are you feeling?")
                            .font(.clarityHero)
                        
                        Text("Take a moment to check in with yourself")
                            .font(.claritySubtitle)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Mood Selection
                    VStack(spacing: 20) {
                        Text("Overall Mood")
                            .font(.clarityTitle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 12) {
                            ForEach(moodOptions, id: \.value) { option in
                                MoodButton(
                                    emoji: option.emoji,
                                    label: option.label,
                                    isSelected: selectedMood == option.value
                                ) {
                                    selectedMood = option.value
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.clarityCard)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    
                    // Emotion Selection
                    VStack(spacing: 20) {
                        Text("What best describes your feeling?")
                            .font(.clarityTitle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(emotions, id: \.self) { emotion in
                                    EmotionTag(
                                        emotion: emotion,
                                        isSelected: selectedEmotion == emotion
                                    ) {
                                        selectedEmotion = emotion
                                    }
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                    .padding()
                    .background(Color.clarityCard)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    
                    // Note Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add a note (optional)")
                            .font(.clarityTitle)
                            .padding(.horizontal)
                        
                        TextField("What's on your mind?", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .padding()
                            .background(Color.clarityCard)
                            .cornerRadius(16)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
            }
            .background(Color.clarityBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMood()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(LinearGradient.clarityPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func saveMood() {
        let moodEntry = MoodEntry(
            ownerEmail: userEmail,
            date: Date(),
            moodScore: Double(selectedMood - 1) / 4.0, // Convert 1-5 to 0-1
            emotion: selectedEmotion,
            note: note.isEmpty ? nil : note
        )
        context.insert(moodEntry)
        try? context.save()
        
        // Save timestamp for conditional display
        UserDefaults.standard.set(Date(), forKey: "lastMoodCheckIn")
        
        dismiss()
    }
}

// MARK: - Mood Button
struct MoodButton: View {
    let emoji: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: isSelected ? 50 : 40))
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                
                Text(label)
                    .font(.clarityCaption)
                    .foregroundStyle(isSelected ? Color.clarityBlue : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.clarityBlue.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clarityBlue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Emotion Tag
struct EmotionTag: View {
    let emotion: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(emotion)
                .font(.clarityCallout)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.clarityBlue : Color.clarityCard)
                )
                .foregroundStyle(isSelected ? .white : .primary)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}
