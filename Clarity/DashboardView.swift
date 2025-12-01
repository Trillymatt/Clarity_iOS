import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    let userEmail: String
    
    @Query private var profiles: [UserProfile]
    @Query private var tasks: [TaskItem]
    @Query private var habits: [Habit]
    @Query private var habitCheckins: [HabitCheckin]
    @Query private var transactions: [Transaction]
    @Query private var moodEntries: [MoodEntry]
    @Query private var moments: [LifeMoment]
    
    init(userEmail: String) {
        self.userEmail = userEmail
        _profiles = Query(filter: #Predicate { $0.email == userEmail })
        _tasks = Query(filter: #Predicate { $0.ownerEmail == userEmail }, sort: \TaskItem.dueDate)
        _habits = Query(filter: #Predicate { $0.ownerEmail == userEmail })
        _habitCheckins = Query(filter: #Predicate { $0.ownerEmail == userEmail })
        _transactions = Query(filter: #Predicate { $0.ownerEmail == userEmail }, sort: \Transaction.date, order: .reverse)
        _moodEntries = Query(filter: #Predicate { $0.ownerEmail == userEmail })
        _moments = Query(filter: #Predicate { $0.ownerEmail == userEmail })
    }
    
    @State private var showMoodCheckIn = false
    @State private var showProfile = false
    @State private var showWeeklyReview = false
    @State private var currentScore: ClarityScore?
    
    var userName: String {
        profiles.first?.name ?? "Friend"
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
                        Button(action: { showProfile = true }) {
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
                    
                    // 🌟 CLARITY SCORE CARD (HERO)
                    if let score = currentScore {
                        ClarityScoreCard(score: score)
                            .padding(.horizontal)
                    }
                    
                    // TODAY'S FOCUS
                    TodaysFocusSection(tasks: tasks, context: context)
                    
                    // LIFE PULSE GRAPH (SIGNATURE VIZ)
                    let pulseData = LifePulseDataGenerator.generateWeekData(
                        tasks: tasks,
                        checkins: habitCheckins,
                        habits: habits,
                        moodEntries: moodEntries,
                        moments: moments,
                        transactions: transactions
                    )
                    LifePulseGraph(pulseData: pulseData)
                        .padding(.horizontal)
                    
                    // HABITS PREVIEW
                    HabitsPreviewSection(habits: habits)
                    
                    // MOMENTS PREVIEW
                    MomentsPreviewSection(moments: moments)
                    
                    Spacer(minLength: 50)
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
            .sheet(isPresented: $showProfile) { ProfileView(userEmail: userEmail) }
            .sheet(isPresented: $showWeeklyReview) {
                WeeklyReviewView(userEmail: userEmail)
            }
            .refreshable {
                calculateCurrentScore()
            }
            .onAppear {
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
        }
    }
    
    private func calculateCurrentScore() {
        currentScore = ClarityScoreCalculator.calculateFullScore(
            tasks: tasks,
            habits: habits,
            checkins: habitCheckins,
            moodEntries: moodEntries,
            moments: moments,
            transactions: transactions
        )
        
        // Update widget data
        WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
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
    
    var todaysTasks: [TaskItem] {
        tasks.filter {
            !$0.isCompleted && ($0.isToday || ($0.dueDate != nil && Calendar.current.isDateInToday($0.dueDate!)))
        }
    }
    
    var taskInsight: String {
        InsightGenerator.generateTaskInsight(
            completionRate: Double(todaysTasks.filter { $0.isCompleted }.count) / max(1, Double(todaysTasks.count)),
            tasksCompleted: todaysTasks.filter { $0.isCompleted }.count
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Today's Focus",
                insight: "\(todaysTasks.count) tasks",
                action: { },
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
                            .background(Color.clarityCard)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
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
    
    var activeHabits: [Habit] {
        habits.filter { $0.isActive }
    }
    
    var habitInsight: String {
        let streak = min(7, activeHabits.count)
        return InsightGenerator.generateHabitInsight(streak: streak, consistency: 0.8)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Habits",
                insight: habitInsight
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
                            CompactHabitCard(habit: habit)
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
    
    var habitIcon: String {
        // Map common icon names to emojis, or use default star
        if let iconName = habit.iconName {
            switch iconName {
            case "figure.run", "figure.walk": return "🏃‍♂️"
            case "book.fill", "book": return "📚"
            case "waterbottle.fill", "waterbottle": return "💧"
            case "figure.mind.and.body": return "🧘‍♀️"
            case "bed.double.fill", "bed": return "😴"
            case "fork.knife": return "🍽️"
            case "dumbbell.fill", "dumbbell": return "💪"
            case "brain.head.profile": return "🧠"
            case "heart.fill", "heart": return "❤️"
            case "sun.max.fill", "sun": return "☀️"
            default: return "⭐"
            }
        }
        return "⭐"
    }
    
    var currentStreak: Int {
        // Simplified - would need actual streak calculation
        habit.isActive ? 3 : 0
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
        .background(Color.clarityCard)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Moments Preview Section
struct MomentsPreviewSection: View {
    let moments: [LifeMoment]
    
    var recentMoments: [LifeMoment] {
        moments.sorted { $0.date > $1.date }.prefix(3).map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Recent Moments",
                insight: "\(moments.count) captured"
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
        .background(Color.clarityCard)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    DashboardView(userEmail: "preview@example.com")
        .modelContainer(for: [UserProfile.self, TaskItem.self, Habit.self, Transaction.self, MoodEntry.self, LifeMoment.self])
}
