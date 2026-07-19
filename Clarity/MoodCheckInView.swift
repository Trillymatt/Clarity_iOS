import SwiftUI
import SwiftData

struct MoodCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let userEmail: String
    var onSave: (() -> Void)? = nil // Optional callback for embedded use
    var embedMode: Bool = false
    
    @State private var selectedMood = 3 // 1-5 scale
    @State private var selectedEmotion = "Content"
    @State private var note = ""
    
    let moodOptions = [
        (emoji: "😢", label: "Rough", value: 1, color: Color.blue),
        (emoji: "😕", label: "Low", value: 2, color: Color.cyan),
        (emoji: "😐", label: "Okay", value: 3, color: Color.gray),
        (emoji: "🙂", label: "Good", value: 4, color: Color.orange),
        (emoji: "😄", label: "Great", value: 5, color: Color.green)
    ]
    
    let emotions = ["Grateful", "Anxious", "Content", "Excited", "Tired", "Peaceful", "Frustrated", "Joyful", "Focused", "Stressed"]
    
    var body: some View {
        if embedMode {
            content
        } else {
            NavigationStack {
                ZStack {
                    Color.clarityBackground.ignoresSafeArea()
                    content
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(.secondary)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveMood()
                        }
                        .fontWeight(.bold)
                        .foregroundStyle(LinearGradient.clarityPrimary)
                    }
                }
            }
            .presentationDetents([.large])
        }
    }
    
    var content: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("How are you feeling?")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    
                    Text("Take a moment to check in with yourself")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Mood Selection
                VStack(spacing: 24) {
                    Text("Overall Mood")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    HStack(spacing: 8) {
                        ForEach(moodOptions, id: \.value) { option in
                            MoodButton(
                                emoji: option.emoji,
                                label: option.label,
                                value: option.value,
                                color: option.color,
                                isSelected: selectedMood == option.value
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedMood = option.value
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Emotion Selection
                VStack(spacing: 20) {
                    Text("What best describes it?")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    // Flow layout for tags using slightly more complex ScrollView setup
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(emotions, id: \.self) { emotion in
                                EmotionTag(
                                    emotion: emotion,
                                    isSelected: selectedEmotion == emotion
                                ) {
                                    withAnimation {
                                        selectedEmotion = emotion
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Note Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add a note (optional)")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ZStack(alignment: .topLeading) {
                        if note.isEmpty {
                            Text("What's on your mind?")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                        }
                        
                        TextEditor(text: $note)
                            .padding(12)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .background(Color.clarityCard)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal)
                }
                
                if embedMode {
                    Button(action: {
                         saveMood()
                    }) {
                        Text("Continue")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient.clarityPrimary)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                
                Spacer(minLength: 40)
            }
            .padding(.bottom, 20)
        }
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
        
        if let onSave = onSave {
            onSave()
        } else {
            dismiss()
        }
    }
}

// MARK: - Mood Button
struct MoodButton: View {
    let emoji: String
    let label: String
    let value: Int
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: isSelected ? 44 : 36))
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .shadow(color: isSelected ? color.opacity(0.4) : .clear, radius: 10, x: 0, y: 5)
                
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? color : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(Color.clarityCard)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
            .shadow(color: isSelected ? color.opacity(0.15) : Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
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
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(isSelected ? LinearGradient.clarityPrimary : LinearGradient(colors: [Color.clarityCard], startPoint: .top, endPoint: .bottom))
                )
                .foregroundStyle(isSelected ? .white : .primary)
                .shadow(color: isSelected ? Color.clarityPurple.opacity(0.3) : Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
