import SwiftUI
import SwiftData
import Charts

// MARK: - Fitness Detail View
// The full fitness surface, reached from the Dashboard's Fitness module via
// "See All." Shows today's HealthKit-derived snapshot (or manual fallback)
// plus the workout log.

struct FitnessDetailView: View {
    @Environment(\.modelContext) private var context
    let userEmail: String

    @Query private var workouts: [Workout]
    @Query private var bodyMetrics: [BodyMetric]

    @ObservedObject private var healthKit = HealthKitManager.shared
    @State private var showAddWorkout = false
    @State private var editingWorkout: Workout?
    @State private var showAddMetric = false
    @State private var isSyncing = false

    init(userEmail: String) {
        self.userEmail = userEmail
        _workouts = Query(filter: #Predicate<Workout> { $0.ownerEmail == userEmail }, sort: \Workout.date, order: .reverse)
        _bodyMetrics = Query(filter: #Predicate<BodyMetric> { $0.ownerEmail == userEmail }, sort: \BodyMetric.date, order: .reverse)
    }

    private var todayMetric: BodyMetric? {
        bodyMetrics.first { Calendar.current.isDateInToday($0.date) }
    }

    private var weeklyWorkoutCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return workouts.filter { $0.date >= weekAgo }.count
    }

    /// Consecutive days (counting back from today or yesterday) with at
    /// least one logged workout.
    private var currentWorkoutStreak: Int {
        let calendar = Calendar.current
        let workoutDays = Set(workouts.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
        guard let mostRecent = workoutDays.first else { return 0 }

        let today = calendar.startOfDay(for: Date())
        let daysSinceLast = calendar.dateComponents([.day], from: mostRecent, to: today).day ?? 0
        guard daysSinceLast <= 1 else { return 0 }

        var streak = 0
        var cursor = mostRecent
        for day in workoutDays {
            if day == cursor {
                streak += 1
                cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            } else {
                break
            }
        }
        return streak
    }

    private var longestDurationWorkout: Workout? {
        workouts.max { $0.durationMinutes < $1.durationMinutes }
    }

    private var mostCaloriesWorkout: Workout? {
        workouts.filter { $0.caloriesBurned != nil }.max { ($0.caloriesBurned ?? 0) < ($1.caloriesBurned ?? 0) }
    }

    private var farthestDistanceWorkout: Workout? {
        workouts.filter { $0.distanceMeters != nil }.max { ($0.distanceMeters ?? 0) < ($1.distanceMeters ?? 0) }
    }

    private var weightHistory: [BodyMetric] {
        bodyMetrics.filter { $0.weightKg != nil }.sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if !healthKit.isAuthorized {
                    healthKitBanner
                }

                todaySummaryCard

                if currentWorkoutStreak > 0 || longestDurationWorkout != nil {
                    streakAndRecordsCard
                        .padding(.horizontal)
                }

                if weightHistory.count >= 2 {
                    weightTrendCard
                        .padding(.horizontal)
                }

                HStack {
                    Text("This Week")
                        .font(.clarityTitle)
                    Spacer()
                    Text("\(weeklyWorkoutCount) workouts")
                        .font(.clarityCaption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                if workouts.isEmpty {
                    SoftCard {
                        VStack(spacing: 8) {
                            Text("No workouts yet")
                                .font(.clarityCallout)
                                .foregroundStyle(.secondary)
                            Text("Log one below, or connect Health to import automatically.")
                                .font(.clarityCaption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        ForEach(workouts.prefix(30)) { workout in
                            WorkoutRow(workout: workout)
                                .onTapGesture { editingWorkout = workout }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 80)
            }
            .padding(.top)
        }
        .background(Color.clarityBackground.ignoresSafeArea())
        .navigationTitle("Fitness")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { showAddWorkout = true }) {
                        Label("Log Workout", systemImage: "figure.run")
                    }
                    Button(action: { showAddMetric = true }) {
                        Label("Log Weight / Steps / Sleep", systemImage: "waveform.path.ecg")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.clarityBlue)
                }
            }
        }
        .sheet(isPresented: $showAddWorkout) {
            AddWorkoutSheet(userEmail: userEmail)
        }
        .sheet(item: $editingWorkout) { workout in
            AddWorkoutSheet(userEmail: userEmail, workoutToEdit: workout)
        }
        .sheet(isPresented: $showAddMetric) {
            AddBodyMetricSheet(userEmail: userEmail, metricToEdit: todayMetric)
        }
        .task {
            await syncHealthKitIfNeeded()
        }
    }

    private var healthKitBanner: some View {
        Button(action: connectHealthKit) {
            SoftCard(glow: Color.clarityTeal) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connect Apple Health")
                            .font(.clarityTitle)
                        Text("Auto-import steps, workouts, heart rate & sleep")
                            .font(.clarityCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isSyncing {
                        ProgressView()
                    } else {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.clarityTeal)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var todaySummaryCard: some View {
        SoftCard(glow: Color.clarityBlue) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Today")
                    .font(.clarityTitle)

                HStack(spacing: 20) {
                    metricTile(value: todayMetric?.steps.map { "\($0)" } ?? "—", label: "Steps", icon: "figure.walk")
                    metricTile(value: todayMetric?.activeEnergyKcal.map { "\(Int($0))" } ?? "—", label: "Active kcal", icon: "flame.fill")
                    metricTile(value: todayMetric?.restingHeartRate.map { "\($0)" } ?? "—", label: "RHR", icon: "heart.fill")
                    metricTile(value: todayMetric?.sleepHours.map { String(format: "%.1fh", $0) } ?? "—", label: "Sleep", icon: "bed.double.fill")
                }
            }
        }
        .padding(.horizontal)
    }

    private var streakAndRecordsCard: some View {
        SoftCard(glow: Color.clarityOrange) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color.clarityOrange)
                    Text("Streak & Records")
                        .font(.clarityTitle)
                }

                if currentWorkoutStreak > 0 {
                    HStack(spacing: 6) {
                        Text("\(currentWorkoutStreak)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.clarityOrange)
                        Text("day workout streak")
                            .font(.clarityCallout)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 8) {
                    if let longest = longestDurationWorkout {
                        recordRow(icon: "clock.fill", label: "Longest", value: "\(longest.durationMinutes) min \(longest.type.label)")
                    }
                    if let most = mostCaloriesWorkout, let calories = most.caloriesBurned {
                        recordRow(icon: "flame.fill", label: "Most Calories", value: "\(Int(calories)) kcal (\(most.type.label))")
                    }
                    if let farthest = farthestDistanceWorkout, let miles = farthest.distanceMiles {
                        recordRow(icon: "location.fill", label: "Farthest", value: String(format: "%.1f mi (%@)", miles, farthest.type.label))
                    }
                }
            }
        }
    }

    private func recordRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.clarityCaption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.clarityCallout.bold())
        }
    }

    private var weightTrendCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Weight Trend")
                    .font(.clarityTitle)

                Chart(weightHistory) { metric in
                    LineMark(
                        x: .value("Date", metric.date),
                        y: .value("Weight", metric.weightLbs ?? 0)
                    )
                    .foregroundStyle(Color.clarityBlue)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", metric.date),
                        y: .value("Weight", metric.weightLbs ?? 0)
                    )
                    .foregroundStyle(Color.clarityBlue)
                }
                .frame(height: 140)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
    }

    private func metricTile(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(Color.clarityTeal)
            Text(value)
                .font(.clarityCallout.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func connectHealthKit() {
        Task {
            isSyncing = true
            let granted = await healthKit.requestAuthorization()
            if granted {
                await healthKit.syncToday(context: context, userEmail: userEmail)
            }
            isSyncing = false
        }
    }

    private func syncHealthKitIfNeeded() async {
        guard healthKit.isAuthorized else { return }
        isSyncing = true
        await healthKit.syncToday(context: context, userEmail: userEmail)
        isSyncing = false
    }
}

// MARK: - Workout Row

struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.clarityTeal.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(workout.type.emoji)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(workout.type.label)
                        .font(.clarityCallout.bold())
                    if workout.source == "healthKit" {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.clarityBlue)
                    }
                }
                Text("\(workout.durationMinutes) min · \(workout.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.clarityCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let calories = workout.caloriesBurned {
                Text("\(Int(calories)) kcal")
                    .font(.caption.bold())
                    .foregroundStyle(Color.clarityOrange)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }
}
