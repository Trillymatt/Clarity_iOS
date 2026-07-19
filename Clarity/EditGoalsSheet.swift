import SwiftUI
import SwiftData

// MARK: - Edit Goals Sheet
// What Jarvis coaches you toward. Deliberately just four numbers — the ones
// that already drive the fitness score and the recommendation engine — kept
// simple on purpose rather than a generic, open-ended goal builder.

struct EditGoalsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var goals: UserGoals

    @State private var spendLimitText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        goalStepper(title: "Daily Steps", icon: "figure.walk", color: .clarityGreen, value: $goals.dailyStepGoal, range: 1000...30000, step: 500)
                        goalStepper(title: "Workouts / Week", icon: "figure.run", color: .clarityTeal, value: $goals.weeklyWorkoutGoal, range: 1...14, step: 1)
                        goalStepper(title: "Tasks Completed / Day", icon: "checkmark.circle.fill", color: .clarityBlue, value: $goals.dailyTaskGoal, range: 1...20, step: 1)

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Weekly Spending Limit", systemImage: "dollarsign.circle.fill")
                                .font(.headline)
                                .foregroundStyle(Color.clarityPurple)

                            HStack(spacing: 8) {
                                Text("$")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                TextField("200", text: $spendLimitText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Your Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                spendLimitText = String(format: "%.0f", goals.weeklySpendLimit)
            }
        }
    }

    @ViewBuilder
    private func goalStepper(title: String, icon: String, color: Color, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)

            Stepper(value: value, in: range, step: step) {
                Text("\(value.wrappedValue)")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func save() {
        if let value = Double(spendLimitText) {
            goals.weeklySpendLimit = max(0, value)
        }
        try? context.save()
        dismiss()
    }
}
