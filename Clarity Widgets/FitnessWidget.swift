import WidgetKit
import SwiftUI

// MARK: - Fitness Widget
// New widget type — steps, weekly workout progress, and streak, since
// fitness didn't have a dedicated widget before.

struct SmallFitnessWidgetView: View {
    var entry: ClarityEntry

    var stepProgress: Double {
        Double(entry.data.todaySteps ?? 0) / Double(max(1, entry.data.stepGoal))
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "figure.run")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text("Fitness")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: min(1, stepProgress))
                    .stroke(Color.white, lineWidth: 8)
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text(entry.data.todaySteps.map { "\($0)" } ?? "—")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }

            Text("of \(entry.data.stepGoal) steps")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            if entry.data.workoutStreak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                    Text("\(entry.data.workoutStreak) day streak")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(14)
    }
}

struct MediumFitnessWidgetView: View {
    var entry: ClarityEntry

    var stepProgress: Double {
        Double(entry.data.todaySteps ?? 0) / Double(max(1, entry.data.stepGoal))
    }

    var workoutProgress: Double {
        Double(entry.data.weekWorkouts) / Double(max(1, entry.data.weeklyWorkoutGoal))
    }

    var body: some View {
        HStack(spacing: 20) {
            fitnessStat(icon: "figure.walk", title: "Steps", value: entry.data.todaySteps.map { "\($0)" } ?? "—", progress: stepProgress)
            fitnessStat(icon: "figure.run", title: "Workouts", value: "\(entry.data.weekWorkouts)/\(entry.data.weeklyWorkoutGoal)", progress: workoutProgress)

            VStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                Text("\(entry.data.workoutStreak)")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("day streak")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
    }

    private func fitnessStat(icon: String, title: String, value: String, progress: Double) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 6)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: min(1, progress))
                    .stroke(Color.white, lineWidth: 6)
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Widget Configuration

struct FitnessWidget: Widget {
    let kind: String = "FitnessWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClarityWidgetProvider()) { entry in
            FitnessWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Fitness")
        .description("Steps, workouts, and your streak at a glance")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FitnessWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: ClarityEntry

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.1, blue: 0.08),
                Color(red: 0.02, green: 0.25, blue: 0.22)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium:
            MediumFitnessWidgetView(entry: entry)
        default:
            SmallFitnessWidgetView(entry: entry)
        }
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            content
                .containerBackground(for: .widget) {
                    backgroundGradient
                }
        } else {
            ZStack {
                backgroundGradient.ignoresSafeArea()
                content
            }
        }
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    FitnessWidget()
} timeline: {
    ClarityEntry(date: .now, data: .placeholder)
}

#Preview(as: .systemMedium) {
    FitnessWidget()
} timeline: {
    ClarityEntry(date: .now, data: .placeholder)
}
