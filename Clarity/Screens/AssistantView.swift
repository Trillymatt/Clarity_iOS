import SwiftUI
import SwiftData

// MARK: - Assistant View
// The always-on Jarvis chat. Persists history in SwiftData so the
// conversation survives app relaunch, and every user message can trigger
// real tool-calls against the user's Clarity data via AssistantService.

struct AssistantView: View {
    @Environment(\.modelContext) private var context
    let userEmail: String

    @Query private var profiles: [UserProfile]
    @Query private var messages: [AssistantMessage]

    @State private var inputText = ""
    @State private var isThinking = false
    @State private var errorMessage: String?
    @State private var showError = false

    init(userEmail: String) {
        self.userEmail = userEmail
        _profiles = Query(filter: #Predicate<UserProfile> { $0.email == userEmail })
        _messages = Query(filter: #Predicate<AssistantMessage> { $0.ownerEmail == userEmail }, sort: \AssistantMessage.timestamp)
    }

    private var userContext: UserContext {
        UserContext(
            biggestPriority: profiles.first?.biggestPriority,
            idealDay: profiles.first?.idealDay,
            desiredHabit: profiles.first?.desiredHabit
        )
    }

    private var userFirstName: String {
        (profiles.first?.name ?? "there").components(separatedBy: " ").first ?? "there"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()

                RadialGradient.clarityGlowPurple
                    .opacity(0.35)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 20) {
                                if messages.isEmpty {
                                    emptyState
                                }

                                ForEach(messages) { message in
                                    ChatBubble(
                                        text: message.content,
                                        isAI: message.role == "assistant",
                                        actionSummary: message.actionSummary
                                    )
                                    .id(message.id)
                                }

                                if isThinking {
                                    TypingIndicator()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 24)
                                        .id("thinking")
                                }

                                Spacer(minLength: 12)
                            }
                            .padding(.top, 12)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let lastId = messages.last?.id {
                                withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                            }
                        }
                        .onChange(of: isThinking) { _, thinking in
                            if thinking {
                                withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                            }
                        }
                    }

                    ChatInputBar(placeholder: "Ask Jarvis anything…", text: $inputText, isBusy: isThinking, showVoiceButton: true) { text in
                        send(text)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("")
            .toolbar(.hidden)
            .alert("Jarvis had trouble responding", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(RadialGradient.clarityGlow).frame(width: 36, height: 36)
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.clarityBlue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Jarvis")
                    .font(.headline)
                Text("Your life & fitness assistant")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Hey \(userFirstName), I'm Jarvis.")
                .font(.title3.bold())
            Text("Ask how your week's going, or tell me things like \u{201c}log a 30 minute run\u{201d} or \u{201c}add a task to call the dentist.\u{201d}")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }

    private func send(_ text: String) {
        let userMessage = AssistantMessage(ownerEmail: userEmail, role: "user", content: text)
        context.insert(userMessage)
        try? context.save()

        let historySnapshot = messages
        isThinking = true

        Task {
            do {
                let result = try await AssistantService.shared.sendMessage(
                    text,
                    history: historySnapshot,
                    userName: userFirstName,
                    userContext: userContext,
                    userEmail: userEmail,
                    context: context
                )

                await MainActor.run {
                    let combinedSummary = result.actionSummaries.isEmpty ? nil : result.actionSummaries.joined(separator: " · ")
                    let reply = AssistantMessage(
                        ownerEmail: userEmail,
                        role: "assistant",
                        content: result.reply,
                        actionSummary: combinedSummary
                    )
                    context.insert(reply)
                    try? context.save()
                    isThinking = false
                }
            } catch {
                await MainActor.run {
                    isThinking = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}
