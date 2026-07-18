import SwiftUI

// MARK: - Assistant Dock Bar
// The persistent "always-on Jarvis" affordance. Docked above the tab bar on
// every screen except the Assistant tab itself; tapping it jumps straight
// into the full chat.

struct AssistantDockBar: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(RadialGradient.clarityGlow)
                        .frame(width: 30, height: 30)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.clarityBlue)
                }

                Text("Ask Jarvis anything…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
            .jarvisGlow(active: true, cornerRadius: 28)
            .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}
