import SwiftUI
import SwiftData

struct WeeklyReviewView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let userEmail: String
    
    // Data State
    @State private var wins = ""
    @State private var challenges = ""
    @State private var learnings = ""
    @State private var rating = 3
    @State private var mainFocus = ""
    @State private var goals = ""
    @State private var habitFocus = ""
    
    // Conversation State
    @State private var step = 0
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isTyping = false
    @FocusState private var isInputFocused: Bool
    @State private var glowRotation = 0.0
    
    // AI Extraction State
    @State private var showExtractionPreview = false
    @State private var extractedItems: ExtractedItems?
    @State private var isExtracting = false
    @State private var reviewSaved = false // Prevent double-saving
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Background
            Color.clarityBackground.ignoresSafeArea()
            
            // Gradient overlay
            LinearGradient(
                colors: [Color.clarityBlue.opacity(0.05), Color.clarityPurple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.primaryGradient)
                    Text("Clarity AI")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // Invisible spacer to balance layout
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                // Chat History
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            Spacer(minLength: 20)
                            
                            ForEach(messages) { message in
                                ChatBubble(text: message.text, isAI: message.isAI)
                                    .id(message.id)
                            }
                            
                            if isTyping {
                                TypingIndicator()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 24)
                                    .id("typing")
                            }
                            
                            // Completion View
                            if step == 8 {
                                VStack(spacing: 24) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundStyle(LinearGradient.claritySuccess)
                                        .padding(.top, 20)
                                    
                                    Text("Review Complete!")
                                        .font(.title2.bold())
                                    
                                    Text("Scroll down to get AI suggestions or finish.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }
                                .padding(.bottom, 40)
                                .id("completion")
                            }
                            
                            Spacer(minLength: 20)
                        }
                        .padding(.bottom, 20)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastId = messages.last?.id {
                            withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                        }
                    }
                    .onChange(of: isTyping) { _, typing in
                        if typing {
                            withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                        }
                    }
                    .onChange(of: step) { _, newStep in
                        if newStep == 8 {
                            withAnimation { proxy.scrollTo("completion", anchor: .bottom) }
                        }
                    }
                }
                
            // Input Area (Pinned to bottom)
            if step < 8 {
                VStack(spacing: 0) {
                    // Rating Suggestions (Step 4)
                    if step == 4 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { score in
                                    Button(action: { sendMessage("\(score)") }) {
                                        Text("\(score) Stars")
                                            .font(.caption.bold())
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.clarityBlue.opacity(0.1), in: Capsule())
                                            .foregroundStyle(Color.clarityBlue)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                    }
                    
                    // Start Button (Step 0)
                    if step == 0 {
                        Button(action: { sendMessage("Let's go") }) {
                            Text("Start Review")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.clarityBlue)
                                .clipShape(Capsule())
                                .shadow(color: Color.clarityBlue.opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                        .padding(.top, 12)
                    } else if step == 4 {
                        // Star Rating for week rating
                        VStack(spacing: 16) {
                            Text("Rate your week")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 12) {
                                ForEach(1...5, id: \.self) { star in
                                    Button(action: {
                                        sendMessage("\(star)")
                                    }) {
                                        Image(systemName: star <= (Int(inputText) ?? 0) ? "star.fill" : "star")
                                            .font(.system(size: 40))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.clarityYellow, .clarityOrange],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                        .padding(.top, 12)
                    } else {
                        // Text Input with suggestions
                        HStack(spacing: 12) {
                            ZStack(alignment: .leading) {
                                if inputText.isEmpty {
                                    Text(placeholderForCurrentStep)
                                        .foregroundStyle(Color.secondary.opacity(0.5))
                                        .padding(.horizontal, 16)
                                }
                                
                                TextField("", text: $inputText)
                                    .focused($isInputFocused)
                                    .submitLabel(.send)
                                    .onSubmit {
                                        if !inputText.isEmpty {
                                            sendMessage(inputText)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.clarityCard)
                                    .cornerRadius(20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(
                                                AngularGradient(
                                                    gradient: Gradient(colors: [
                                                        Color.clarityBlue,
                                                        Color.clarityPurple,
                                                        Color.clarityBlue
                                                    ]),
                                                    center: .center,
                                                    startAngle: .degrees(glowRotation),
                                                    endAngle: .degrees(glowRotation + 360)
                                                ),
                                                lineWidth: 4
                                            )
                                            .blur(radius: 16)
                                            .opacity(isInputFocused ? 0.4 : 0)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.secondary.opacity(0.2), lineWidth: isInputFocused ? 0 : 1)
                                    )
                                    .onAppear {
                                        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                                            glowRotation = 360
                                        }
                                    }
                            }
                            
                            Button(action: { sendMessage(inputText) }) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(inputText.isEmpty ? Color.secondary.opacity(0.3) : Color.clarityBlue)
                            }
                            .disabled(inputText.isEmpty)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .padding(.top, 12)
                    }
                }
                .background(.ultraThinMaterial)
            }
            
            // Extract Action Items button (pinned to bottom)
            if step >= 8 {
                VStack(spacing: 16) {
                    Text("Review Complete!")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        // Finish Button (Secondary)
                        Button(action: { dismiss() }) {
                            Text("Finish")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                        }
                        
                        // Extract Button (Primary)
                        Button(action: extractActionItems) {
                            HStack {
                                if isExtracting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(isExtracting ? "Thinking..." : "Get Suggestions")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.clarityBlue, Color.clarityPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: Color.clarityBlue.opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .disabled(isExtracting)
                    }
                }
                .padding(24)
                .background(.ultraThinMaterial)
            }
        } // Close VStack (line 41)
    } // Close ZStack (line 29)
    .sheet(item: $extractedItems) { items in
        ActionItemsPreviewSheet(
            extractedItems: items,
            userEmail: userEmail,
            onComplete: {
                // Dismiss weekly review to return to dashboard
                dismiss()
            }
        )
    }
    .alert("Unable to Extract Items", isPresented: $showError) {
        Button("OK", role: .cancel) { }
    } message: {
        Text(errorMessage)
    }
    .onAppear {
        // Initial Message
        if messages.isEmpty {
            addMessage("Time for your weekly review! Ready to reflect on your progress?", isAI: true)
        }
    }
}
    
    func addMessage(_ text: String, isAI: Bool) {
        let message = ChatMessage(text: text, isAI: isAI)
        withAnimation {
            messages.append(message)
        }
    }
    
    func sendMessage(_ text: String) {
        guard !text.isEmpty else { return }
        
        let userText = text
        inputText = "" // Clear input
        
        // Add user message
        addMessage(userText, isAI: false)
        
        // Show typing indicator
        isTyping = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isTyping = false
            handleResponse(userText) // Process the user's response
            advanceStep() // Then advance the step
        }
    }
    
    func advanceStep() {
        step += 1
        
        switch step {
        case 1:
            addMessage("Great! Let's start with the positives. What were your biggest wins this week?", isAI: true)
        case 2:
            addMessage("That's awesome to hear! Now, what challenges did you face?", isAI: true)
        case 3:
            addMessage("Challenges are just opportunities in disguise. What did you learn from them?", isAI: true)
        case 4:
            addMessage("Taking everything into account, how would you rate this week?", isAI: true)
        case 5:
            addMessage("Got it. Now looking ahead, what is your main focus for next week?", isAI: true)
        case 6:
            addMessage("And what are your top 3 goals? (You can list them here)", isAI: true)
        case 7:
            addMessage("Finally, is there a specific habit you want to focus on improving?", isAI: true)
        case 8:
            addMessage("Perfect! I've saved your review. Here's to a great week ahead! 🚀", isAI: true)
            // Save review automatically
            saveReviewSilently()
            // Show extraction button after completing review
        default:
            break
        }
    }
    
    var placeholderForCurrentStep: String {
        switch step {
        case 1: return "e.g., Completed my project, had quality time with family..."
        case 2: return "e.g., Struggled with time management, felt overwhelmed..."
        case 3: return "e.g., Learned to prioritize better, need more breaks..."
        case 5: return "e.g., Launch new feature, improve health routine..."
        case 6: return "e.g., 1. Exercise 3x/week 2. Read daily 3. Sleep 8hrs..."
        case 7: return "e.g., Morning meditation, drinking more water..."
        default: return "Type your answer..."
        }
    }
    
    func handleResponse(_ userResponse: String) {
        switch step {
        case 1:
            wins = userResponse
        case 2:
            challenges = userResponse
        case 3:
            learnings = userResponse
        case 4:
            rating = Int(userResponse) ?? 3
        case 5:
            mainFocus = userResponse
        case 6:
            goals = userResponse
        case 7:
            habitFocus = userResponse
        default:
            break
        }
    }
    
    private func saveReview() {
        let goalsList = goals.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        
        let review = WeeklyReview(
            ownerEmail: userEmail,
            date: Date(),
            wins: wins,
            challenges: challenges,
            learnings: learnings,
            improvements: "",
            habitAdherence: 0, // Not explicitly asked, could infer or remove
            topGoals: goalsList,
            mainFocus: mainFocus,
            habitFocus: habitFocus,
            weekRating: rating
        )
        context.insert(review)
        try? context.save()
        
        // Save timestamp for last weekly review
        UserDefaults.standard.set(Date(), forKey: "lastWeeklyReview")
        
        dismiss()
    }
    
    private func saveReviewSilently() {
        guard !reviewSaved else {
            print("⚠️ Review already saved, skipping")
            return
        }
        
        let goalsList = goals.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        
        let review = WeeklyReview(
            ownerEmail: userEmail,
            date: Date(),
            wins: wins,
            challenges: challenges,
            learnings: learnings,
            improvements: "",
            habitAdherence: 0,
            topGoals: goalsList,
            mainFocus: mainFocus,
            habitFocus: habitFocus,
            weekRating: rating
        )
        context.insert(review)
        try? context.save()
        
        // Save timestamp for last weekly review
        UserDefaults.standard.set(Date(), forKey: "lastWeeklyReview")
        reviewSaved = true
        print("✅ Review saved successfully")
        // Don't dismiss - keep view open for extraction
    }
    
    private func extractActionItems() {
        guard !allReflectionText.isEmpty else {
            print("⚠️ Reflection text is empty")
            return
        }
        
        print("🔍 Starting extraction...")
        print("📝 Reflection text: \(allReflectionText)")
        
        isExtracting = true
        
        Task {
            do {
                let items = try await AIService.shared.extractActionItems(from: allReflectionText)
                print("✅ Extraction successful!")
                print("📊 Found: \(items.moments.count) moments, \(items.habits.count) habits, \(items.tasks.count) tasks")
                
                await MainActor.run {
                    extractedItems = items
                    isExtracting = false
                    
                    if items.isEmpty {
                        print("⚠️ No items extracted")
                    } else {
                        showExtractionPreview = true
                    }
                }
            } catch {
                print("❌ Extraction error: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                await MainActor.run {
                    isExtracting = false
                    showError = true
                    errorMessage = "We couldn't extract suggestions from your review. Please try again or add items manually."
                }
            }
        }
    }
    
    private var allReflectionText: String {
        """
        Wins: \(wins)
        Challenges: \(challenges)
        Learnings: \(learnings)
        Main Focus: \(mainFocus)
        Goals: \(goals)
        Habit Focus: \(habitFocus)
        """
    }
}

#Preview {
    WeeklyReviewView(userEmail: "preview@example.com")
}
