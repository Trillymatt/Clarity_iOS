import SwiftUI

// MARK: - Chat Message
// Shared conversational primitives used by onboarding, the weekly review flow,
// and the Jarvis assistant chat.

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isAI: Bool
    var actionSummary: String? = nil
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let text: String
    let isAI: Bool
    var actionSummary: String? = nil

    var body: some View {
        VStack(alignment: isAI ? .leading : .trailing, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                if !isAI { Spacer() }

                Text(text)
                    .font(.body)
                    .lineSpacing(4)
                    .padding(16)
                    .background(bubbleBackground)
                    .foregroundStyle(isAI ? Color.primary : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(isAI ? 0.08 : 0), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 3)

                if isAI { Spacer() }
            }

            if let actionSummary {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text(actionSummary)
                        .font(.caption.bold())
                }
                .foregroundStyle(Color.clarityTeal)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.clarityTeal.opacity(0.14)))
                .overlay(Capsule().strokeBorder(Color.clarityTeal.opacity(0.35), lineWidth: 1))
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: isAI ? .leading : .trailing)
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isAI {
            ZStack {
                Color.claritySurface.opacity(0.8)
                Color.clear.background(.ultraThinMaterial)
            }
        } else {
            Color.primaryGradient
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var offset: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.clarityBlue.opacity(0.8))
                    .frame(width: 8, height: 8)
                    .offset(y: offset)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(i) * 0.2),
                        value: offset
                    )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear { offset = -5 }
    }
}

// MARK: - Chat Input Bar
// A glowing text field + send button, reused by every chat-style surface
// (onboarding, weekly review, and the assistant) instead of each screen
// re-implementing the glow effect inline.

struct ChatInputBar: View {
    let placeholder: String
    @Binding var text: String
    var isBusy: Bool = false
    var onSend: (String) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField(placeholder, text: $text, axis: .vertical)
                .focused($isFocused)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .lineLimit(1...5)
                .submitLabel(.send)
                .onSubmit(sendIfPossible)
                .jarvisGlow(active: isFocused, cornerRadius: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(isFocused ? 0 : 0.1), lineWidth: 1)
                )

            Button(action: sendIfPossible) {
                if isBusy {
                    ProgressView()
                        .tint(Color.clarityBlue)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(text.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.3) : Color.clarityBlue)
                }
            }
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isBusy)
        }
    }

    private func sendIfPossible() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy else { return }
        onSend(trimmed)
    }
}
