import SwiftUI

// MARK: - Goal Progress Ring
// One generic ring for every "today vs. goal" metric on the dashboard,
// replacing the pattern of copy-pasting a near-identical ring per tab.

struct GoalProgressRing: View {
    let progress: Double // 0...1, already clamped by the caller if needed
    let value: String
    let label: String
    let color: Color
    var size: CGFloat = 64

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(1, max(0, progress)))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                Text(value)
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(4)
            }
            .frame(width: size, height: size)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
