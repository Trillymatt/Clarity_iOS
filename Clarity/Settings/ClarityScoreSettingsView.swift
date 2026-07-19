import SwiftUI

struct ClarityScoreSettingsView: View {
    @StateObject private var settings = ClarityScoreSettings.shared
    
    // Timer to throttle updates during drag if needed,
    // but SwiftUI Slider onEditingChanged might be enough.
    // However, for "live" dragging effect, we bind directly.
    
    var body: some View {
        Form {
            Section {
                Text("Adjust the sliders to choose how much each area contributes to your Clarity Score. The total will always equal 100%.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            }
            
            Section(header: Text("Distribution")) {
                componentSlider(name: "Tasks", component: .task, value: $settings.taskWeight)
                componentSlider(name: "Habits", component: .habit, value: $settings.habitWeight)
                componentSlider(name: "Mood", component: .mood, value: $settings.moodWeight)
                componentSlider(name: "Moments", component: .moment, value: $settings.momentWeight)
                componentSlider(name: "Finance", component: .finance, value: $settings.financeWeight)
            }
            
            Section {
                 // Visualization
                VStack(alignment: .leading, spacing: 10) {
                    Text("Breakdown")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    ChartPreview(weights: settings.currentWeights)
                        .frame(height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Score Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func componentSlider(name: String, component: ScoreComponent, value: Binding<Double>) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(name)
                    .font(.subheadline.bold())
                Spacer()
                Text(percent.string(from: NSNumber(value: value.wrappedValue)) ?? "")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            
            Slider(value: Binding(
                get: { value.wrappedValue },
                set: { newValue in
                    settings.setWeight(for: component, to: newValue)
                }
            ), in: 0...1) {
                Text(name)
            }
            .tint(colorFor(component))
        }
        .padding(.vertical, 4)
    }
    
    private func colorFor(_ component: ScoreComponent) -> Color {
        switch component {
        case .task: return .blue
        case .habit: return .green
        case .mood: return .purple
        case .moment: return .orange
        case .finance: return .yellow
        }
    }
}

private struct ChartPreview: View {
    let weights: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Task
                if weights[0] > 0 {
                    Color.blue.frame(width: geometry.size.width * weights[0])
                }
                // Habit
                if weights[1] > 0 {
                    Color.green.frame(width: geometry.size.width * weights[1])
                }
                // Mood
                if weights[2] > 0 {
                    Color.purple.frame(width: geometry.size.width * weights[2])
                }
                // Moment
                if weights[3] > 0 {
                    Color.orange.frame(width: geometry.size.width * weights[3])
                }
                // Finance
                if weights[4] > 0 {
                    Color.yellow.frame(width: geometry.size.width * weights[4])
                }
            }
        }
    }
}

private let percent: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .percent
    f.maximumFractionDigits = 0
    return f
}()

#Preview {
    NavigationStack {
        ClarityScoreSettingsView()
    }
}
