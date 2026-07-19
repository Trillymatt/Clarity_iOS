import SwiftUI

// MARK: - Jarvis Brief Card
// A holistic, one-sentence AI read of the user's day, sitting right at the
// top of the dashboard. Falls back to a plain rule-based summary if the AI
// call fails or is still loading, so the card never looks broken.

struct JarvisBriefCard: View {
    let userName: String
    let userContext: UserContext
    let tasks: [TaskItem]
    let habits: [Habit]
    let checkins: [HabitCheckin]
    let moodEntries: [MoodEntry]
    let workouts: [Workout]
    let transactions: [Transaction]
    var onOpenAssistant: () -> Void = {}

    @State private var brief: String?
    @State private var isLoading = false

    var body: some View {
        Button(action: onOpenAssistant) {
            SoftCard(glow: Color.clarityPurple) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle().fill(RadialGradient.clarityGlowPurple).frame(width: 40, height: 40)
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.clarityPurple)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Jarvis Brief")
                            .font(.clarityCaptionBold)
                            .foregroundStyle(.secondary)

                        if isLoading && brief == nil {
                            Text("Reading your day…")
                                .font(.clarityCallout)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(brief ?? fallbackBrief)
                                .font(.clarityCallout)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
        .task(id: dataFingerprint) {
            await loadBrief()
        }
    }

    private var dataFingerprint: Int {
        tasks.count ^ habits.count ^ checkins.count ^ moodEntries.count ^ workouts.count ^ transactions.count
    }

    private var fallbackBrief: String {
        let openToday = tasks.filter { !$0.isCompleted && $0.isToday }.count
        let activeHabits = habits.filter { $0.isActive }.count
        return "You have \(openToday) task\(openToday == 1 ? "" : "s") open today and \(activeHabits) active habit\(activeHabits == 1 ? "" : "s") to keep up. Tap to ask me anything."
    }

    private func loadBrief() async {
        isLoading = true

        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) ?? Date()
        let openToday = tasks.filter { !$0.isCompleted && $0.isToday }.count
        let completedToday = tasks.filter { $0.isCompleted && $0.completedDate != nil && calendar.isDateInToday($0.completedDate!) }.count
        let activeHabits = habits.filter { $0.isActive }.count
        let weekWorkouts = workouts.filter { $0.date >= weekStart }.count
        let weekSpend = transactions.filter { $0.date >= weekStart }.reduce(0) { $0 + $1.amount }
        let latestMood = moodEntries.sorted { $0.date > $1.date }.first

        let summary = """
        Tasks: \(completedToday) completed today, \(openToday) still open today
        Habits: \(activeHabits) active
        Fitness: \(weekWorkouts) workouts in the last 7 days
        Money: $\(String(format: "%.2f", weekSpend)) spent in the last 7 days
        Mood: \(latestMood.map { "'\($0.emotion)' logged \($0.date.formatted(.relative(presentation: .named)))" } ?? "not logged recently")
        """

        do {
            let result = try await AssistantService.shared.generateDailyBrief(userName: userName, userContext: userContext, summary: summary)
            await MainActor.run {
                brief = result.isEmpty ? nil : result
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}
