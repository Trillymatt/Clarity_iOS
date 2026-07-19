import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    let userEmail: String
    var selectedTab: Binding<RootTabView.Tab>?

    @Query private var profiles: [UserProfile]
    @Query private var tasks: [TaskItem]
    @Query private var habits: [Habit]
    @Query private var habitCheckins: [HabitCheckin]
    @Query private var transactions: [Transaction]
    @Query private var moodEntries: [MoodEntry]
    @Query private var moments: [LifeMoment]
    @Query private var workouts: [Workout]
    @Query private var bodyMetrics: [BodyMetric]
    @Query private var userGoalsList: [UserGoals]
    @Query private var budgets: [Budget]

    init(userEmail: String, selectedTab: Binding<RootTabView.Tab>? = nil) {
        self.userEmail = userEmail
        self.selectedTab = selectedTab
        _profiles = Query(filter: #Predicate { $0.email == userEmail })
        _tasks = Query(filter: #Predicate { $0.ownerEmail == userEmail }, sort: \TaskItem.dueDate)
        _habits = Query(filter: #Predicate { $0.ownerEmail == userEmail })
        _habitCheckins = Query(filter: #Predicate { $0.ownerEmail == userEmail })
        _transactions = Query(filter: #Predicate { $0.ownerEmail == userEmail }, sort: \Transaction.date, order: .reverse)
        _moodEntries = Query(filter: #Predicate { $0.ownerEmail == userEmail })
        _moments = Query(filter: #Predicate { $0.ownerEmail == userEmail })
        _workouts = Query(filter: #Predicate<Workout> { $0.ownerEmail == userEmail }, sort: \Workout.date, order: .reverse)
        _bodyMetrics = Query(filter: #Predicate<BodyMetric> { $0.ownerEmail == userEmail }, sort: \BodyMetric.date, order: .reverse)
        _userGoalsList = Query(filter: #Predicate<UserGoals> { $0.ownerEmail == userEmail })
        _budgets = Query(filter: #Predicate<Budget> { $0.ownerEmail == userEmail })
    }

    @State private var showMoodCheckIn = false
    @State private var showWeeklyReview = false
    @State private var showEditGoals = false
    @State private var showTrends = false
    @State private var showSearch = false
    @State private var currentScore: ClarityScore?

    // Drill-in destinations — the whole point of the redesign is that these
    // are the ONLY way to leave the dashboard for domain detail; everything
    // you need day-to-day lives on this one screen.
    @State private var showFocusDetail = false
    @State private var showHabitsDetail = false
    @State private var showMomentsDetail = false
    @State private var showFinanceDetail = false
    @State private var showFitnessDetail = false

    var userName: String {
        profiles.first?.name ?? "Friend"
    }

    var userContext: UserContext {
        UserContext(
            biggestPriority: profiles.first?.biggestPriority,
            idealDay: profiles.first?.idealDay,
            desiredHabit: profiles.first?.desiredHabit
        )
    }

    /// Live goals record for this user. Falls back to an unsaved default
    /// instance for the one render before `.onAppear`'s fetch-or-create has
    /// landed, so the view never has to deal with an optional.
    var currentGoals: UserGoals {
        userGoalsList.first ?? UserGoals(ownerEmail: userEmail)
    }

    var recommendations: [Recommendation] {
        RecommendationEngine.generate(
            goals: currentGoals,
            tasks: tasks,
            habits: habits,
            checkins: habitCheckins,
            workouts: workouts,
            bodyMetrics: bodyMetrics,
            transactions: transactions,
            moodEntries: moodEntries,
            budgets: budgets
        )
    }

    var shouldShowMoodCheckIn: Bool {
        guard let lastCheckIn = UserDefaults.standard.object(forKey: "lastMoodCheckIn") as? Date else {
            return true
        }
        return !Calendar.current.isDateInToday(lastCheckIn)
    }

    var shouldShowWeeklyReview: Bool {
        guard let lastReview = UserDefaults.standard.object(forKey: "lastWeeklyReview") as? Date else {
            return true
        }
        let daysSinceReview = Calendar.current.dateComponents([.day], from: lastReview, to: Date()).day ?? 0
        return daysSinceReview >= 7
    }

    var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning,"
        case 12..<17: return "Good Afternoon,"
        default: return "Good Evening,"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(timeBasedGreeting)
                                .font(.claritySubtitle)
                                .foregroundStyle(.secondary)
                            Text(userName)
                                .font(.clarityHero)
                        }
                        Spacer()
                        Button(action: { showSearch = true }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        Button(action: { selectedTab?.wrappedValue = .profile }) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(LinearGradient.clarityPrimary)
                        }
                    }
                    .padding(.horizontal)

                    // Mood Check-in (conditional)
                    if shouldShowMoodCheckIn {
                        Button(action: { showMoodCheckIn = true }) {
                            SoftCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("How are you feeling?")
                                            .font(.clarityTitle)
                                            .foregroundStyle(.primary)
                                        Text("Check in with yourself")
                                            .font(.clarityCaption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "face.smiling")
                                        .font(.system(size: 32))
                                        .foregroundStyle(LinearGradient.clarityPrimary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }

                    // Weekly Review (conditional)
                    if shouldShowWeeklyReview {
                        WeeklyReviewPrompt(showReview: $showWeeklyReview)
                            .padding(.horizontal)
                    }

                    // JARVIS BRIEF — a holistic, cross-domain read of the day
                    JarvisBriefCard(
                        userName: userName,
                        userContext: userContext,
                        tasks: tasks,
                        habits: habits,
                        checkins: habitCheckins,
                        moodEntries: moodEntries,
                        workouts: workouts,
                        transactions: transactions,
                        onOpenAssistant: { selectedTab?.wrappedValue = .assistant }
                    )
                    .padding(.horizontal)

                    // TODAY'S GOALS — the WHOOP-style "where do I stand" ring row
                    TodayGoalsCard(
                        goals: currentGoals,
                        todaySteps: bodyMetrics.first { Calendar.current.isDateInToday($0.date) }?.steps,
                        weekWorkouts: workouts.filter { $0.date >= (Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date())) ?? Date()) }.count,
                        tasksCompletedToday: tasks.filter { $0.isCompleted && $0.completedDate != nil && Calendar.current.isDateInToday($0.completedDate!) }.count,
                        weekSpend: transactions.filter { $0.date >= (Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date())) ?? Date()) }.reduce(0) { $0 + $1.amount },
                        onEdit: { showEditGoals = true }
                    )
                    .padding(.horizontal)

                    // RECOMMENDATIONS — specific, actionable, not just "everything's fine"
                    if !recommendations.isEmpty {
                        RecommendationsCard(recommendations: recommendations)
                            .padding(.horizontal)
                    }

                    // TODAY'S FOCUS
                    TodaysFocusSection(tasks: tasks, context: context, onSeeAll: { showFocusDetail = true })

                    // FITNESS MODULE
                    FitnessPreviewSection(workouts: workouts, bodyMetrics: bodyMetrics, onSeeAll: { showFitnessDetail = true })

                    // LIFE PULSE GRAPH (SIGNATURE VIZ)
                    let pulseData = LifePulseDataGenerator.generateWeekData(
                        tasks: tasks,
                        checkins: habitCheckins,
                        habits: habits,
                        moodEntries: moodEntries,
                        moments: moments,
                        transactions: transactions
                    )
                    Button(action: { showTrends = true }) {
                        LifePulseGraph(pulseData: pulseData)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    // HABITS PREVIEW
                    HabitsPreviewSection(habits: habits, onSeeAll: { showHabitsDetail = true })

                    // MONEY MODULE
                    FinancePreviewSection(transactions: transactions, onSeeAll: { showFinanceDetail = true })

                    // MOMENTS PREVIEW
                    MomentsPreviewSection(moments: moments, onSeeAll: { showMomentsDetail = true })

                    // CLARITY SCORE — still here, just no longer the headline
                    if let score = currentScore {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Clarity Score")
                                .font(.clarityCaptionBold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            ClarityScoreCard(score: score)
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 90)
                }
                .padding(.top)
            }
            .background(Color.clarityBackground.ignoresSafeArea())
            .navigationTitle("")
            .toolbar(.hidden)
            .sheet(isPresented: $showMoodCheckIn) {
                MoodCheckInView(userEmail: userEmail)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showWeeklyReview) {
                WeeklyReviewView(userEmail: userEmail)
            }
            .sheet(isPresented: $showEditGoals) {
                EditGoalsSheet(goals: UserGoals.fetchOrCreate(context: context, ownerEmail: userEmail))
            }
            .sheet(isPresented: $showTrends) {
                TrendHistoryView(userEmail: userEmail)
            }
            .sheet(isPresented: $showSearch) {
                GlobalSearchView(userEmail: userEmail)
            }
            .sheet(isPresented: $showFocusDetail) {
                EnhancedTodayTab(userEmail: userEmail)
            }
            .sheet(isPresented: $showHabitsDetail) {
                EnhancedHabitsTab(userEmail: userEmail)
            }
            .sheet(isPresented: $showMomentsDetail) {
                EnhancedMomentsTab(userEmail: userEmail)
            }
            .sheet(isPresented: $showFinanceDetail) {
                EnhancedFinanceTab(userEmail: userEmail)
            }
            .sheet(isPresented: $showFitnessDetail) {
                NavigationStack {
                    FitnessDetailView(userEmail: userEmail)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button(action: { showFitnessDetail = false }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                }
            }
            .refreshable {
                calculateCurrentScore()
            }
            .onAppear {
                if userGoalsList.isEmpty {
                    _ = UserGoals.fetchOrCreate(context: context, ownerEmail: userEmail)
                }
                calculateCurrentScore()
            }
            .onChange(of: tasks.count) { _, _ in
                calculateCurrentScore()
            }
            .onChange(of: tasks.filter { $0.isCompleted }.count) { _, _ in
                calculateCurrentScore()
            }
            .onChange(of: habitCheckins.count) { _, _ in
                calculateCurrentScore()
            }
            .onChange(of: moments.count) { _, _ in
                calculateCurrentScore()
            }
            .onChange(of: moodEntries.count) { _, _ in
                calculateCurrentScore()
            }
            .onChange(of: transactions.count) { _, _ in
                calculateCurrentScore()
            }
            .onChange(of: workouts.count) { _, _ in
                calculateCurrentScore()
            }
            .onChange(of: bodyMetrics.count) { _, _ in
                calculateCurrentScore()
            }
            .onChange(of: currentGoals.dailyStepGoal) { _, _ in
                calculateCurrentScore()
            }
            .onChange(of: currentGoals.weeklyWorkoutGoal) { _, _ in
                calculateCurrentScore()
            }
        }
    }

    private func calculateCurrentScore() {
        let previousTotal = currentScore?.totalScore
        currentScore = ClarityScoreCalculator.calculateFullScore(
            tasks: tasks,
            habits: habits,
            checkins: habitCheckins,
            moodEntries: moodEntries,
            moments: moments,
            transactions: transactions,
            workouts: workouts,
            bodyMetrics: bodyMetrics,
            goals: currentGoals,
            previousScore: previousTotal
        )

        // Update widget data
        WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
    }
}

// MARK: - Today Goals Card
// The WHOOP-style ring row — where you stand against your own targets,
// checkable in five seconds.
struct TodayGoalsCard: View {
    let goals: UserGoals
    let todaySteps: Int?
    let weekWorkouts: Int
    let tasksCompletedToday: Int
    let weekSpend: Double
    var onEdit: () -> Void = {}

    var body: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Today's Goals")
                        .font(.clarityTitle)
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 0) {
                    GoalProgressRing(
                        progress: Double(todaySteps ?? 0) / Double(max(1, goals.dailyStepGoal)),
                        value: todaySteps.map { "\($0 / 1000)k" } ?? "—",
                        label: "Steps",
                        color: .clarityGreen
                    )
                    .frame(maxWidth: .infinity)

                    GoalProgressRing(
                        progress: Double(weekWorkouts) / Double(max(1, goals.weeklyWorkoutGoal)),
                        value: "\(weekWorkouts)/\(goals.weeklyWorkoutGoal)",
                        label: "Workouts",
                        color: .clarityTeal
                    )
                    .frame(maxWidth: .infinity)

                    GoalProgressRing(
                        progress: Double(tasksCompletedToday) / Double(max(1, goals.dailyTaskGoal)),
                        value: "\(tasksCompletedToday)/\(goals.dailyTaskGoal)",
                        label: "Tasks",
                        color: .clarityBlue
                    )
                    .frame(maxWidth: .infinity)

                    GoalProgressRing(
                        progress: weekSpend / max(1, goals.weeklySpendLimit),
                        value: String(format: "$%.0f", weekSpend),
                        label: "Spend",
                        color: weekSpend > goals.weeklySpendLimit ? .clarityPink : .clarityPurple
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Recommendations Card
struct RecommendationsCard: View {
    let recommendations: [Recommendation]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.clarityTitle)
                .padding(.horizontal, 4)

            VStack(spacing: 10) {
                ForEach(recommendations.prefix(3)) { rec in
                    HStack(spacing: 12) {
                        Image(systemName: rec.domain.icon)
                            .foregroundStyle(rec.domain.color)
                            .frame(width: 28)

                        Text(rec.message)
                            .font(.clarityCallout)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(rec.domain.color.opacity(0.25), lineWidth: 1)
                    )
                }
            }
        }
    }
}

// MARK: - Weekly Review Prompt
struct WeeklyReviewPrompt: View {
    @Binding var showReview: Bool

    var body: some View {
        Button(action: { showReview = true }) {
            GradientCard(gradient: .clarityPrimary) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weekly Review")
                            .font(.clarityTitle)
                            .foregroundStyle(.white)
                        Text("Reflect and plan ahead")
                            .font(.claritySubtitle)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Today's Focus Section
struct TodaysFocusSection: View {
    let tasks: [TaskItem]
    let context: ModelContext
    var onSeeAll: () -> Void = {}

    var todaysTasks: [TaskItem] {
        tasks.filter {
            !$0.isCompleted && ($0.isToday || ($0.dueDate != nil && Calendar.current.isDateInToday($0.dueDate!)))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Today's Focus",
                insight: "\(todaysTasks.count) tasks",
                action: onSeeAll,
                actionLabel: "See All"
            )
            .padding(.horizontal)

            if todaysTasks.isEmpty {
                SoftCard {
                    VStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(LinearGradient.claritySuccess)
                        Text("All caught up!")
                            .font(.clarityTitle)
                        Text("No urgent tasks for today")
                            .font(.clarityBody)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    ForEach(todaysTasks.prefix(3)) { task in
                        TaskRow(task: task)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Fitness Preview Section
struct FitnessPreviewSection: View {
    let workouts: [Workout]
    let bodyMetrics: [BodyMetric]
    var onSeeAll: () -> Void = {}

    private var todayMetric: BodyMetric? {
        bodyMetrics.first { Calendar.current.isDateInToday($0.date) }
    }

    private var recentWorkouts: [Workout] {
        Array(workouts.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Fitness",
                insight: recentWorkouts.isEmpty ? "No workouts logged yet" : "\(recentWorkouts.count) recent",
                action: onSeeAll,
                actionLabel: "See All"
            )
            .padding(.horizontal)

            SoftCard(glow: Color.clarityTeal) {
                HStack(spacing: 16) {
                    fitnessTile(value: todayMetric?.steps.map { "\($0)" } ?? "—", label: "Steps", icon: "figure.walk")
                    fitnessTile(value: todayMetric?.activeEnergyKcal.map { "\(Int($0))" } ?? "—", label: "Active kcal", icon: "flame.fill")
                    fitnessTile(value: recentWorkouts.first.map { "\($0.durationMinutes)m" } ?? "—", label: "Last workout", icon: "figure.run")
                }
            }
            .padding(.horizontal)
        }
    }

    private func fitnessTile(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(Color.clarityTeal)
            Text(value).font(.clarityCallout.bold()).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Finance Preview Section
struct FinancePreviewSection: View {
    let transactions: [Transaction]
    var onSeeAll: () -> Void = {}

    private var weeklyTotal: Double {
        let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return transactions.filter { $0.date >= weekStart }.reduce(0) { $0 + $1.amount }
    }

    private var recentTransactions: [Transaction] {
        Array(transactions.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Money",
                insight: String(format: "$%.0f this week", weeklyTotal),
                action: onSeeAll,
                actionLabel: "See All"
            )
            .padding(.horizontal)

            if recentTransactions.isEmpty {
                SoftCard {
                    Text("No transactions yet")
                        .font(.clarityCallout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    ForEach(recentTransactions) { txn in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(txn.note?.isEmpty == false ? txn.note! : txn.category.rawValue.capitalized)
                                    .font(.clarityCallout)
                                Text(txn.date, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(String(format: "$%.2f", txn.amount))
                                .font(.clarityCallout.bold())
                                .foregroundStyle(Color.clarityPurple)
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Habits Preview Section
struct HabitsPreviewSection: View {
    let habits: [Habit]
    var onSeeAll: () -> Void = {}
    @Query private var habitCheckins: [HabitCheckin]

    var activeHabits: [Habit] {
        habits.filter { $0.isActive }
    }

    /// A plain, honest stat instead of a canned "streak" line — real data
    /// beats a generic motivational string that isn't actually measuring
    /// anything for this specific habit set.
    var habitInsight: String {
        guard !activeHabits.isEmpty else { return "No active habits" }
        let checkedInToday = activeHabits.filter { habit in
            let goal = habit.goalPerDay ?? 1
            let todayTotal = habitCheckins
                .filter { $0.habit?.id == habit.id && Calendar.current.isDateInToday($0.date) }
                .reduce(0) { $0 + $1.value }
            return todayTotal >= goal
        }.count
        return "\(checkedInToday)/\(activeHabits.count) checked in today"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Habits",
                insight: habitInsight,
                action: onSeeAll,
                actionLabel: "See All"
            )
            .padding(.horizontal)

            if activeHabits.isEmpty {
                SoftCard {
                    VStack(spacing: 8) {
                        Text("No active habits")
                            .font(.clarityCallout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(activeHabits.prefix(4)) { habit in
                            CompactHabitCard(habit: habit, checkins: habitCheckins)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Compact Habit Card
struct CompactHabitCard: View {
    let habit: Habit
    let checkins: [HabitCheckin]

    var habitIcon: String {
        // Map common icon names to emojis, or use default star
        if let iconName = habit.iconName {
            switch iconName {
            case "figure.run", "figure.walk": return "🏃‍♂️"
            case "book.fill", "book": return "📚"
            case "waterbottle.fill", "waterbottle", "drop.fill": return "💧"
            case "figure.mind.and.body": return "🧘‍♀️"
            case "bed.double.fill", "bed": return "😴"
            case "fork.knife": return "🍽️"
            case "dumbbell.fill", "dumbbell": return "💪"
            case "brain.head.profile": return "🧠"
            case "heart.fill", "heart": return "❤️"
            case "sun.max.fill", "sun": return "☀️"
            case "flame.fill": return "🔥"
            case "leaf.fill": return "🌿"
            default: return "⭐"
            }
        }
        return "⭐"
    }

    var currentStreak: Int {
        HabitStreakCalculator.currentStreak(checkins: checkins, habitID: habit.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(habitIcon)
                .font(.system(size: 32))

            Text(habit.name)
                .font(.clarityCallout)
                .lineLimit(2)

            Text("\(currentStreak) day streak")
                .font(.clarityCaption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 120)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Moments Preview Section
struct MomentsPreviewSection: View {
    let moments: [LifeMoment]
    var onSeeAll: () -> Void = {}

    var recentMoments: [LifeMoment] {
        moments.sorted { $0.date > $1.date }.prefix(3).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Recent Moments",
                insight: "\(moments.count) captured",
                action: onSeeAll,
                actionLabel: "See All"
            )
            .padding(.horizontal)

            if recentMoments.isEmpty {
                SoftCard {
                    VStack(spacing: 8) {
                        Text("No moments yet")
                            .font(.clarityCallout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    ForEach(recentMoments) { moment in
                        CompactMomentCard(moment: moment)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Compact Moment Card
struct CompactMomentCard: View {
    let moment: LifeMoment

    var moodEmoji: String {
        guard let score = moment.moodScore else { return "💭" }
        switch score {
        case 0..<0.2: return "😢"
        case 0.2..<0.4: return "😕"
        case 0.4..<0.6: return "😐"
        case 0.6..<0.8: return "🙂"
        default: return "😄"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(moodEmoji)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 4) {
                Text(moment.title)
                    .font(.clarityCallout)
                    .lineLimit(1)

                if let note = moment.note, !note.isEmpty {
                    Text(note)
                        .font(.clarityCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(moment.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }
}

#Preview {
    DashboardView(userEmail: "preview@example.com")
        .modelContainer(for: [UserProfile.self, TaskItem.self, Habit.self, Transaction.self, MoodEntry.self, LifeMoment.self])
}
