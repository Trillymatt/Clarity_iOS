import SwiftUI
import SwiftData

// MARK: - Enhanced Habits Tab
struct EnhancedHabitsTab: View {
    @Environment(\.modelContext) private var context
    let userEmail: String
    @Query private var habits: [Habit]
    @Query private var checkins: [HabitCheckin]
    
    init(userEmail: String) {
        self.userEmail = userEmail
        _habits = Query(filter: #Predicate { $0.ownerEmail == userEmail })
        _checkins = Query(filter: #Predicate { $0.ownerEmail == userEmail })
    }
    
    @State private var showAdd = false
    @State private var showHiddenSection = false
    
    // MARK: - Computed Properties
    
    /// All active, non-hidden habits
    var activeHabits: [Habit] {
        habits.filter { $0.isActive && !$0.isHiddenSafe }.sorted { $0.displayOrder < $1.displayOrder }
    }
    
    /// Habits scheduled for today (or daily habits)
    var todaysHabits: [Habit] {
        activeHabits.filter { $0.isScheduledForToday }
    }
    
    /// Habits NOT scheduled for today + manually hidden habits
    var hiddenHabits: [Habit] {
        habits.filter { habit in
            habit.isActive && (habit.isHiddenSafe || !habit.isScheduledForToday)
        }.sorted { $0.displayOrder < $1.displayOrder }
    }
    
    var primaryHabit: Habit? {
        todaysHabits.first
    }
    
    var otherHabits: [Habit] {
        Array(todaysHabits.dropFirst())
    }
    
    var otherBuildHabits: [Habit] {
        otherHabits.filter { $0.habitType == .build }
    }
    
    var otherQuitHabits: [Habit] {
        otherHabits.filter { $0.habitType == .quit }
    }
    
    var habitScore: Double {
        ClarityScoreCalculator.calculateHabitScore(habits: habits, checkins: checkins)
    }
    
    var scoreInsight: String {
        switch habitScore {
        case 80...: return "Unstoppable streak!"
        case 60..<80: return "Building consistency"
        case 40..<60: return "Keep showing up"
        default: return "Start small, dream big"
        }
    }
    
    // MARK: - Actions
    
    private func todayCount(for habit: Habit) -> Int {
        let calendar = Calendar.current
        return checkins.filter { checkin in
            checkin.habit?.id == habit.id && calendar.isDateInToday(checkin.date)
        }.reduce(0) { $0 + $1.value }
    }
    
    private func isCheckedInToday(_ habit: Habit) -> Bool {
        guard let goal = habit.goalPerDay else { return false }
        return todayCount(for: habit) >= goal
    }
    
    private func toggleCheckin(_ habit: Habit) {
        let calendar = Calendar.current
        let goal = habit.goalPerDay ?? 1
        let currentCount = todayCount(for: habit)
        
        // If at or above goal, reset to 0 (Undo)
        if currentCount >= goal {
            // Delete all today's checkins for this habit
            let todaysCheckins = checkins.filter { checkin in
                checkin.habit?.id == habit.id && calendar.isDateInToday(checkin.date)
            }
            todaysCheckins.forEach { context.delete($0) }
        } else {
            // Increment by 1
            let checkin = HabitCheckin(
                ownerEmail: userEmail,
                habit: habit,
                date: Date(),
                value: 1,
                isCompleted: currentCount + 1 >= goal
            )
            context.insert(checkin)
            
            // Celebration Logic (Only for Build habits)
            if habit.habitType == .build && currentCount + 1 >= goal {
                let streak = calculateStreak(for: habit, includingToday: true)
                
                // Send streak celebration if it's a milestone
                Task { @MainActor in
                    NotificationManager.shared.sendStreakCelebration(habitName: habit.name, streakDays: streak)
                }
                
                // DATA SYNC: Post to Friends Feed (if sharing is enabled)
                if UserDefaults.standard.bool(forKey: "shareActivityWithFriends") {
                    Task {
                        await CloudKitService.shared.postActivity(
                            type: "habit",
                            title: habit.name,
                            iconName: habit.iconName ?? "star.fill",
                            value: streak
                        )
                    }
                }
            }
        }
        
        try? context.save()
        WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
    }
    
    /// Calculate the current streak for a habit
    private func calculateStreak(for habit: Habit, includingToday: Bool = false) -> Int {
        HabitStreakCalculator.currentStreak(checkins: checkins, habitID: habit.id, includingToday: includingToday)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Spacer for nav bar
                        Color.clear.frame(height: 90)
                        // Header & Score
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Habits")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                
                                Text(scoreInsight)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.clarityOrange)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.clarityOrange.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            
                            Spacer()
                            
                            HabitScoreRing(score: habitScore)
                        }
                        .padding(.top, 10)
                        
                        // Primary Habit Card
                            if let primary = primaryHabit {
                                VStack(alignment: .leading, spacing: 16) {
                                    Label("Primary Habit", systemImage: "flame.fill")
                                        .font(.headline)
                                        .foregroundStyle(Color.clarityOrange)
                                    
                                    PrimaryHabitCard(
                                        habit: primary,
                                        isCheckedIn: isCheckedInToday(primary),
                                        todayCount: todayCount(for: primary),
                                        onCheckIn: { toggleCheckin(primary) },
                                        userEmail: userEmail
                                    )
                                    .id(primary.id)
                                }
                            }
                            
                            // Other Habits - Build Routine
                            if !otherBuildHabits.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Your Routine")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                    
                                    ForEach(otherBuildHabits) { habit in
                                        EnhancedHabitRow(
                                            habit: habit,
                                            isCheckedIn: isCheckedInToday(habit),
                                            todayCount: todayCount(for: habit),
                                            onCheckIn: { toggleCheckin(habit) },
                                            userEmail: userEmail
                                        )
                                        .id(habit.id)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                withAnimation {
                                                    // Delete associated check-ins first
                                                    let habitCheckins = checkins.filter { $0.habit?.id == habit.id }
                                                    habitCheckins.forEach { context.delete($0) }

                                                    // Then delete the habit
                                                    context.delete(habit)

                                                    // Save and refresh
                                                    try? context.save()
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                            Button {
                                                withAnimation {
                                                    habit.isHidden = true
                                                    try? context.save()
                                                }
                                            } label: {
                                                Label("Hide", systemImage: "eye.slash")
                                            }
                                            .tint(.gray)
                                        }
                                    }
                                }
                            }
                            
                            // Other Habits - Habits to Break
                            if !otherQuitHabits.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Habits to Quit")
                                        .font(.headline)
                                        .foregroundStyle(.red.opacity(0.8))
                                        .padding(.top, 8)
                                    
                                    ForEach(otherQuitHabits) { habit in
                                        EnhancedHabitRow(
                                            habit: habit,
                                            isCheckedIn: isCheckedInToday(habit),
                                            todayCount: todayCount(for: habit),
                                            onCheckIn: { toggleCheckin(habit) },
                                            userEmail: userEmail
                                        )
                                        .id(habit.id)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                withAnimation {
                                                    let habitCheckins = checkins.filter { $0.habit?.id == habit.id }
                                                    habitCheckins.forEach { context.delete($0) }
                                                    context.delete(habit)
                                                    try? context.save()
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                            Button {
                                                withAnimation {
                                                    habit.isHidden = true
                                                    try? context.save()
                                                }
                                            } label: {
                                                Label("Hide", systemImage: "eye.slash")
                                            }
                                            .tint(.gray)
                                        }
                                    }
                                }
                            }
                        
                        // Suggestions (always show)
                        SuggestedHabitsView(userEmail: userEmail)
                        
                        // Hidden/Not Scheduled Habits Section
                        if !hiddenHabits.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        showHiddenSection.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: showHiddenSection ? "eye" : "eye.slash")
                                            .font(.subheadline)
                                        Text("Hidden & Not Scheduled (\(hiddenHabits.count))")
                                            .font(.subheadline.weight(.medium))
                                        Spacer()
                                        Image(systemName: showHiddenSection ? "chevron.up" : "chevron.down")
                                            .font(.caption)
                                    }
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.clarityCard.opacity(0.5))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                                
                                if showHiddenSection {
                                    VStack(spacing: 8) {
                                        ForEach(hiddenHabits) { habit in
                                            HiddenHabitRow(
                                                habit: habit,
                                                onUnhide: {
                                                    withAnimation {
                                                        habit.isHidden = false
                                                        try? context.save()
                                                    }
                                                },
                                                onDelete: {
                                                    withAnimation {
                                                        let habitCheckins = checkins.filter { $0.habit?.id == habit.id }
                                                        habitCheckins.forEach { context.delete($0) }
                                                        context.delete(habit)
                                                        try? context.save()
                                                    }
                                                }
                                            )
                                        }
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .padding(.top, 8)
                        }
                        
                        // Inactive Habits
                        let inactiveHabits = habits.filter { !$0.isActive }
                        if !inactiveHabits.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Inactive")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                
                                ForEach(inactiveHabits) { habit in
                                    EnhancedHabitRow(
                                        habit: habit,
                                        isCheckedIn: false, // Inactive habits can't be checked in
                                        todayCount: 0, // No count for inactive
                                        onCheckIn: { }, // No-op
                                        userEmail: userEmail
                                    )
                                    .opacity(0.5)
                                }
                            }
                            .padding(.top, 10)
                        }
                        
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom)
                }
            }
            .navigationTitle("")
            .toolbar(.hidden)
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(LinearGradient.clarityPrimary)
                        .clipShape(Circle())
                        .shadow(color: Color.clarityPurple.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .padding()
            }
            .sheet(isPresented: $showAdd) {
                AddHabitSheet(userEmail: userEmail)
            }
        }
    }
}

// MARK: - Subviews

struct HabitScoreRing: View {
    let score: Double
    
    var contribution: Int {
        Int(score * ClarityScoreCalculator.habitWeight)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.clarityCard, lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(
                        LinearGradient(colors: [.clarityOrange, .clarityPink], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.8), value: score)
                
                VStack(spacing: 0) {
                    Text("\(Int(score))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Score")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }
            .frame(width: 80, height: 80)
            
            Text("+\(contribution) pts")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.clarityCard)
                .clipShape(Capsule())
        }
    }
}

struct PrimaryHabitCard: View {
    let habit: Habit
    let isCheckedIn: Bool
    let todayCount: Int
    let onCheckIn: () -> Void
    let userEmail: String
    @State private var showEdit = false
    @State private var showCalendar = false
    @State private var animateCheck = false
    @State private var showCelebration = false
    
    @Environment(\.modelContext) private var context
    @Query private var checkins: [HabitCheckin]
    
    init(habit: Habit, isCheckedIn: Bool, todayCount: Int, onCheckIn: @escaping () -> Void, userEmail: String) {
        self.habit = habit
        self.isCheckedIn = isCheckedIn
        self.todayCount = todayCount
        self.onCheckIn = onCheckIn
        self.userEmail = userEmail
        _checkins = Query(filter: #Predicate<HabitCheckin> { $0.ownerEmail == userEmail })
    }
    
    var habitIcon: String {
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
    
    /// Calculate streak for this habit
    var currentStreak: Int {
        let calendar = Calendar.current
        let habitCheckins = checkins.filter { $0.habit?.id == habit.id }
        guard !habitCheckins.isEmpty else { return isCheckedIn ? 1 : 0 }
        
        var checkinDays = Set(habitCheckins.map { calendar.startOfDay(for: $0.date) })
        if isCheckedIn {
            checkinDays.insert(calendar.startOfDay(for: Date()))
        }
        
        let sortedDays = checkinDays.sorted(by: >)
        guard let mostRecentDay = sortedDays.first else { return 0 }
        
        let today = calendar.startOfDay(for: Date())
        let daysSinceLastCheckin = calendar.dateComponents([.day], from: mostRecentDay, to: today).day ?? 0
        if daysSinceLastCheckin > 1 { return 0 }
        
        var streak = 0
        var currentDay = mostRecentDay
        
        for day in sortedDays {
            if day == currentDay {
                streak += 1
                currentDay = calendar.date(byAdding: .day, value: -1, to: currentDay)!
            } else {
                break
            }
        }
        return streak
    }
    
    /// Last 7 days completion status (array-based for backwards compatibility)
    var weeklyProgress: [Bool] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let habitCheckins = checkins.filter { $0.habit?.id == habit.id }
        let checkinDays = Set(habitCheckins.map { calendar.startOfDay(for: $0.date) })
        
        return (0..<7).reversed().map { daysAgo in
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            return checkinDays.contains(day) || (daysAgo == 0 && isCheckedIn)
        }
    }
    
    /// Check if a specific date has a check-in
    func weeklyProgress(for date: Date) -> Bool {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        let habitCheckins = checkins.filter { $0.habit?.id == habit.id }
        let checkinDays = Set(habitCheckins.map { calendar.startOfDay(for: $0.date) })
        
        // If it's today and checked in, count it
        if targetDay == today && isCheckedIn {
            return true
        }
        
        return checkinDays.contains(targetDay)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card
            HStack(spacing: 14) {
                // Icon
                Text(habitIcon)
                    .font(.system(size: 36))
                    .frame(width: 52, height: 52)
                    .background(
                        habit.habitType == .quit 
                            ? (isCheckedIn ? Color.blue.opacity(0.15) : Color.blue.opacity(0.05))
                            : (isCheckedIn ? Color.clarityOrange.opacity(0.15) : Color.clarityOrange.opacity(0.08))
                    )
                    .clipShape(Circle())
                
                // Habit info - tappable for edit
                VStack(alignment: .leading, spacing: 4) {
                    // Habit name - MOST PROMINENT
                    Text(habit.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Second row: streak + weekly dots
                    HStack(spacing: 6) {
                        // Streak badge (compact)
                        // Streak badge (compact)
                        // Streak badge (compact)
                        if currentStreak >= 1 || habit.habitType == .quit {
                            HStack(spacing: 4) {
                                Image(systemName: habit.habitType == .quit ? "checkmark.shield.fill" : "flame.fill")
                                    .font(.system(size: 10))
                                Text(habit.habitType == .quit ? "\(currentStreak)d Clean" : "\(currentStreak)")
                                    .font(.system(size: 11, weight: .bold))
                                    .lineLimit(1)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(habit.habitType == .quit ? Color.blue : Color.orange)
                            .cornerRadius(6)
                        }
                        
                        // Weekly progress - current week starting Sunday
                        HStack(spacing: 3) {
                            let calendar = Calendar.current
                            let today = Date()
                            let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
                            
                            // Find Sunday of the current week
                            let weekday = calendar.component(.weekday, from: today)
                            let daysFromSunday = weekday - 1
                            let sunday = calendar.date(byAdding: .day, value: -daysFromSunday, to: today)!
                            
                            ForEach(0..<7, id: \.self) { index in
                                let dayDate = calendar.date(byAdding: .day, value: index, to: sunday)!
                                let dayWeekday = index + 1 // 1=Sun, 7=Sat
                                let isScheduled = habit.daysOfWeek.isEmpty || habit.daysOfWeek.contains(dayWeekday)
                                let isCompleted = weeklyProgress(for: dayDate)
                                let isPast = dayDate <= today
                                
                                Text(dayLetters[index])
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(
                                        habit.habitType == .quit 
                                            ? (isCompleted ? Color.blue : (isPast ? Color.red.opacity(0.5) : Color.secondary.opacity(0.2)))
                                            : (isCompleted ? Color.clarityOrange :
                                                (isScheduled && isPast ? Color.secondary.opacity(0.6) :
                                                    (isScheduled ? Color.secondary.opacity(0.4) : Color.secondary.opacity(0.15))))
                                    )
                                    .frame(width: 12)
                            }
                        }
                        
                        if let goal = habit.goalPerDay, goal > 1 {
                            Text("\(todayCount)/\(goal)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showEdit = true
                }
                
                Spacer(minLength: 8)
                
                // Calendar expand button
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showCalendar.toggle()
                    }
                } label: {
                    Image(systemName: showCalendar ? "chevron.up.circle.fill" : "calendar")
                        .font(.system(size: 20))
                        .foregroundStyle(showCalendar ? Color.clarityPurple : Color.secondary.opacity(0.4))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                
                // Check-in Button with pulse animation
                Button {
                    // Haptic feedback
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    
                    if !isCheckedIn {
                        // Trigger pulse animation
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                            animateCheck = true
                        }
                        
                        // Success haptic after brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                        
                        // Reset pulse
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring(response: 0.2)) {
                                animateCheck = false
                            }
                        }
                    }
                    
                    // Perform the check-in
                    onCheckIn()
                } label: {
                    ZStack {
                        // Pulse ring (behind checkmark, doesn't block touches)
                        Circle()
                            .stroke(Color.clarityOrange.opacity(animateCheck ? 0.6 : 0), lineWidth: 3)
                            .frame(width: 50, height: 50)
                            .scaleEffect(animateCheck ? 1.5 : 1.0)
                            .animation(.easeOut(duration: 0.4), value: animateCheck)
                        
                            Image(systemName: isCheckedIn ? (habit.habitType == .quit ? "checkmark.shield.fill" : "checkmark.circle.fill") : "circle")
                            .font(.system(size: 34))
                            .foregroundStyle(
                                isCheckedIn 
                                    ? (habit.habitType == .quit 
                                        ? LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom)
                                        : LinearGradient(colors: [.clarityOrange, .clarityPink], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    : LinearGradient(colors: [Color.secondary.opacity(0.3), Color.secondary.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                            )
                            .scaleEffect(animateCheck ? 1.3 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.4), value: animateCheck)
                    }
                    .frame(width: 50, height: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.clarityCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isCheckedIn 
                                    ? (habit.habitType == .quit ? Color.blue.opacity(0.4) : Color.clarityOrange.opacity(0.4))
                                    : Color.clarityOrange.opacity(0.2),
                                lineWidth: isCheckedIn ? 1.5 : 1
                            )
                    )
            )
            .shadow(color: Color.clarityOrange.opacity(0.1), radius: 8, x: 0, y: 3)
            
            // Expandable calendar
            if showCalendar {
                HabitMonthCalendar(
                    habit: habit,
                    checkins: checkins.filter { $0.habit?.id == habit.id },
                    userEmail: userEmail,
                    modelContext: context
                )
                .padding(.top, 10)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.3), value: showCalendar)
        .sheet(isPresented: $showEdit) {
            AddHabitSheet(userEmail: userEmail, habitToEdit: habit)
        }
    }
}

struct EnhancedHabitRow: View {
    let habit: Habit
    let isCheckedIn: Bool
    let todayCount: Int
    let onCheckIn: () -> Void
    let userEmail: String
    @State private var showEdit = false
    @State private var showCalendar = false
    @State private var animateCheck = false
    @State private var showCelebration = false
    
    @Environment(\.modelContext) private var context
    @Query private var checkins: [HabitCheckin]
    
    init(habit: Habit, isCheckedIn: Bool, todayCount: Int, onCheckIn: @escaping () -> Void, userEmail: String) {
        self.habit = habit
        self.isCheckedIn = isCheckedIn
        self.todayCount = todayCount
        self.onCheckIn = onCheckIn
        self.userEmail = userEmail
        _checkins = Query(filter: #Predicate<HabitCheckin> { $0.ownerEmail == userEmail })
    }
    
    var habitIcon: String {
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
    
    /// Calculate streak for this habit
    var currentStreak: Int {
        let calendar = Calendar.current
        let habitCheckins = checkins.filter { $0.habit?.id == habit.id }
        guard !habitCheckins.isEmpty else { return 0 }
        
        var checkinDays = Set(habitCheckins.map { calendar.startOfDay(for: $0.date) })
        if isCheckedIn {
            checkinDays.insert(calendar.startOfDay(for: Date()))
        }
        
        let sortedDays = checkinDays.sorted(by: >)
        guard let mostRecentDay = sortedDays.first else { return 0 }
        
        let today = calendar.startOfDay(for: Date())
        let daysSinceLastCheckin = calendar.dateComponents([.day], from: mostRecentDay, to: today).day ?? 0
        if daysSinceLastCheckin > 1 { return 0 }
        
        var streak = 0
        var currentDay = mostRecentDay
        
        for day in sortedDays {
            if day == currentDay {
                streak += 1
                currentDay = calendar.date(byAdding: .day, value: -1, to: currentDay)!
            } else {
                break
            }
        }
        return streak
    }
    
    /// Last 7 days completion status
    var weeklyProgress: [Bool] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let habitCheckins = checkins.filter { $0.habit?.id == habit.id }
        let checkinDays = Set(habitCheckins.map { calendar.startOfDay(for: $0.date) })
        
        return (0..<7).reversed().map { daysAgo in
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            return checkinDays.contains(day) || (daysAgo == 0 && isCheckedIn)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Icon
                Text(habitIcon)
                    .font(.system(size: 26))
                    .frame(width: 40, height: 40)
                    .background(isCheckedIn ? Color.clarityOrange.opacity(0.15) : Color.gray.opacity(0.08))
                    .clipShape(Circle())
                
                // Habit info - tappable for edit
                VStack(alignment: .leading, spacing: 3) {
                    // Habit name - MOST PROMINENT
                    Text(habit.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Second row: streak + weekly dots
                    HStack(spacing: 6) {
                        // Streak badge (compact)
                        // Streak badge (compact)
                        if currentStreak >= 2 || habit.habitType == .quit {
                            HStack(spacing: 4) {
                                Image(systemName: habit.habitType == .quit ? "shield.fill" : "flame.fill")
                                    .font(.system(size: 9))
                                Text(habit.habitType == .quit ? "\(currentStreak)d Clean" : "\(currentStreak)")
                                    .font(.system(size: 10, weight: .bold))
                                    .lineLimit(1)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(habit.habitType == .quit ? Color.blue : Color.orange)
                            .cornerRadius(5)
                        }
                        
                        // Weekly progress - current week starting Sunday
                        HStack(spacing: 2) {
                            let calendar = Calendar.current
                            let today = Date()
                            let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
                            
                            // Find Sunday of the current week
                            let weekdayToday = calendar.component(.weekday, from: today)
                            let daysFromSunday = weekdayToday - 1
                            let sunday = calendar.date(byAdding: .day, value: -daysFromSunday, to: calendar.startOfDay(for: today))!
                            
                            let habitCheckins = checkins.filter { $0.habit?.id == habit.id }
                            let checkinDays = Set(habitCheckins.map { calendar.startOfDay(for: $0.date) })
                            
                            ForEach(0..<7, id: \.self) { index in
                                let dayDate = calendar.date(byAdding: .day, value: index, to: sunday)!
                                let dayWeekday = index + 1 // 1=Sun, 7=Sat
                                let isScheduled = habit.daysOfWeek.isEmpty || habit.daysOfWeek.contains(dayWeekday)
                                let isToday = calendar.isDateInToday(dayDate)
                                let isCompleted = checkinDays.contains(dayDate) || (isToday && isCheckedIn)
                                let isPast = dayDate <= calendar.startOfDay(for: today)
                                
                                Text(dayLetters[index])
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(
                                        habit.habitType == .quit 
                                           ? (isCompleted ? Color.red : (isPast ? Color.green.opacity(0.6) : Color.secondary.opacity(0.2)))
                                           : (isCompleted ? Color.clarityOrange :
                                               (isScheduled && isPast ? Color.secondary.opacity(0.6) :
                                                   (isScheduled ? Color.secondary.opacity(0.4) : Color.secondary.opacity(0.15))))
                                    )
                                    .frame(width: 10)
                            }
                        }
                        
                        if let goal = habit.goalPerDay, goal > 1 {
                            Text("\(todayCount)/\(goal)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showEdit = true
                }
                
                Spacer(minLength: 8)
                
                // Calendar expand button
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showCalendar.toggle()
                    }
                } label: {
                    Image(systemName: showCalendar ? "chevron.up.circle.fill" : "calendar")
                        .font(.system(size: 18))
                        .foregroundStyle(showCalendar ? Color.clarityPurple : Color.secondary.opacity(0.4))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                
                // Check-in Button with pulse animation
                Button {
                    // Haptic feedback
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    
                    if !isCheckedIn {
                        // Trigger pulse animation
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                            animateCheck = true
                        }
                        
                        // Success haptic after brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                        
                        // Reset pulse
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring(response: 0.2)) {
                                animateCheck = false
                            }
                        }
                    }
                    
                    // Perform the check-in
                    onCheckIn()
                } label: {
                    ZStack {
                        // Pulse ring (behind checkmark)
                        Circle()
                            .stroke(Color.clarityOrange.opacity(animateCheck ? 0.5 : 0), lineWidth: 2)
                            .frame(width: 40, height: 40)
                            .scaleEffect(animateCheck ? 1.5 : 1.0)
                            .animation(.easeOut(duration: 0.35), value: animateCheck)
                        
                        Image(systemName: isCheckedIn ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                isCheckedIn 
                                    ? (habit.habitType == .quit 
                                        ? LinearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom)
                                        : LinearGradient(colors: [.clarityOrange, .clarityPink], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    : LinearGradient(colors: [Color.secondary.opacity(0.3), Color.secondary.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                            )
                            .scaleEffect(animateCheck ? 1.25 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.4), value: animateCheck)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clarityCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isCheckedIn 
                                ? (habit.habitType == .quit ? Color.red.opacity(0.4) : Color.clarityOrange.opacity(0.4))
                                : Color.clear, 
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
            
            // Expandable calendar
            if showCalendar {
                HabitMonthCalendar(
                    habit: habit,
                    checkins: checkins.filter { $0.habit?.id == habit.id },
                    userEmail: userEmail,
                    modelContext: context
                )
                .padding(.top, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.3), value: showCalendar)
        .sheet(isPresented: $showEdit) {
            AddHabitSheet(userEmail: userEmail, habitToEdit: habit)
        }
    }
}

// MARK: - Habit Month Calendar
struct HabitMonthCalendar: View {
    let habit: Habit
    let checkins: [HabitCheckin]
    let userEmail: String
    let modelContext: ModelContext
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    
    /// Check if a specific date is a scheduled day for this habit
    private func isScheduledDay(_ date: Date) -> Bool {
        // Empty daysOfWeek = daily (all days scheduled)
        if habit.daysOfWeek.isEmpty { return true }
        
        let weekday = Calendar.current.component(.weekday, from: date)
        return habit.daysOfWeek.contains(weekday)
    }
    
    var monthDays: [(date: Date, isCheckedIn: Bool, isScheduled: Bool)] {
        let calendar = Calendar.current
        let today = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let range = calendar.range(of: .day, in: .month, for: today)!
        
        let checkinDays = Set(checkins.map { calendar.startOfDay(for: $0.date) })
        
        return range.compactMap { day in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) else { return nil }
            let isCheckedIn = checkinDays.contains(calendar.startOfDay(for: date))
            let isScheduled = isScheduledDay(date)
            return (date, isCheckedIn, isScheduled)
        }
    }
    
    /// Consistency only counts scheduled days that have passed
    var consistency: Double {
        let scheduledDays = monthDays.filter { $0.isScheduled && $0.date <= Date() }
        guard !scheduledDays.isEmpty else { return 0 }
        
        // For Build habits: Completed = isCheckedIn
        // For Quit habits: Completed = !isCheckedIn (Clean)
        let completed = scheduledDays.filter { 
            habit.habitType == .quit ? !$0.isCheckedIn : $0.isCheckedIn 
        }.count
        
        return Double(completed) / Double(scheduledDays.count) * 100
    }
    
    /// Schedule description for header
    var scheduleText: String {
        if habit.daysOfWeek.isEmpty {
            return "Daily"
        } else {
            let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            let days = habit.daysOfWeek.sorted().compactMap { $0 >= 1 && $0 <= 7 ? dayNames[$0] : nil }
            return days.joined(separator: ", ")
        }
    }
    
    /// Toggle habit completion for a specific date
    private func toggleDateCompletion(_ date: Date) {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        
        // Only allow past and today, not future
        guard targetDay <= today else {
            // Light error haptic for future dates
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        
        // Only allow scheduled days
        guard isScheduledDay(date) else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        
        // Check if already checked in on this date
        let existingCheckins = checkins.filter { 
            calendar.isDate($0.date, inSameDayAs: targetDay)
        }
        
        if !existingCheckins.isEmpty {
            // Remove check-in
            existingCheckins.forEach { modelContext.delete($0) }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else {
            // Add check-in
            let goal = habit.goalPerDay ?? 1
            let checkin = HabitCheckin(
                ownerEmail: userEmail,
                habit: habit,
                date: targetDay,
                value: goal, // Mark as fully complete
                isCompleted: true
            )
            modelContext.insert(checkin)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        // Save changes
        try? modelContext.save()
        
        // Update widgets
        WidgetDataUpdater.updateWidgetData(context: modelContext, userEmail: userEmail)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Date(), format: .dateTime.month(.wide))
                        .font(.subheadline.bold())
                    
                    if !habit.daysOfWeek.isEmpty {
                        Text(scheduleText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text("\(Int(consistency))% consistent")
                    .font(.caption.bold())
                    .foregroundStyle(consistency >= 70 ? Color.green : (consistency >= 40 ? Color.orange : Color.red))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.clarityCard)
                    .cornerRadius(8)
            }
            
            // Helper text
            Text("Tap past dates to toggle completion")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Day labels - highlight scheduled days
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(dayLabels.enumerated()), id: \.offset) { index, day in
                    let weekday = index + 1 // 1 = Sunday
                    let isScheduledDay = habit.daysOfWeek.isEmpty || habit.daysOfWeek.contains(weekday)
                    
                    Text(day)
                        .font(.caption2.bold())
                        .foregroundStyle(isScheduledDay ? Color.primary : Color.secondary.opacity(0.4))
                        .frame(height: 20)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: columns, spacing: 4) {
                // Offset for first day of month
                let calendar = Calendar.current
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
                let weekday = calendar.component(.weekday, from: startOfMonth)
                let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
                
                ForEach(0..<(weekday - 1), id: \.self) { _ in
                    Color.clear.frame(height: 32)
                }
                
                ForEach(monthDays, id: \.date) { day in
                    let dayOfWeek = calendar.component(.weekday, from: day.date) - 1 // 0-indexed
                    let dayLetter = dayLetters[dayOfWeek]
                    let isPast = day.date <= Date()
                    let isInteractive = isPast && day.isScheduled
                    
                    Button {
                        toggleDateCompletion(day.date)
                    } label: {
                        VStack(spacing: 1) {
                            // Day number
                            ZStack {
                                if day.isCheckedIn {
                                    // Completed/Incident
                                    Circle()
                                        .fill(habit.habitType == .quit ? Color.red : Color.clarityOrange)
                                } else if !day.isScheduled {
                                    // Not scheduled - very faint
                                    Circle()
                                        .fill(Color.gray.opacity(0.08))
                                } else if day.date <= Date() {
                                    // Scheduled but missed - red outline (Build) OR Clean (Quit - Green/Blue?)
                                    if habit.habitType == .quit {
                                        // Clean day!
                                        Circle()
                                            .stroke(Color.blue.opacity(0.5), lineWidth: 1.5)
                                    } else {
                                        // Missed day (Build)
                                        Circle()
                                            .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                                    }
                                } else {
                                    // Future scheduled - orange outline
                                    Circle()
                                        .stroke(Color.clarityOrange.opacity(0.4), lineWidth: 1)
                                }
                                
                                Text("\(calendar.component(.day, from: day.date))")
                                    .font(.system(size: 10, weight: day.isScheduled ? .medium : .regular))
                                    .foregroundStyle(
                                        day.isCheckedIn ? .white :
                                            (!day.isScheduled ? Color.secondary.opacity(0.25) :
                                                (day.date <= Date() ? Color.primary : Color.secondary))
                                    )
                            }
                            .frame(width: 22, height: 22)
                            
                            // Day letter - only show for scheduled days
                            if day.isScheduled {
                                Text(dayLetter)
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(
                                        day.isCheckedIn 
                                            ? (habit.habitType == .quit ? Color.red : Color.clarityOrange) 
                                            : Color.secondary.opacity(0.5)
                                    )
                            }
                        }
                        .frame(height: 32)
                        .contentShape(Rectangle()) // Make entire area tappable
                    }
                    .buttonStyle(.plain)
                    .disabled(!isInteractive) // Disable future/unscheduled dates
                    .opacity(isInteractive ? 1.0 : 1.0) // Keep full opacity for all
                }
            }
        }
        .padding()
        .background(Color.clarityCard.opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - Hidden Habit Row
struct HiddenHabitRow: View {
    let habit: Habit
    let onUnhide: () -> Void
    let onDelete: () -> Void
    
    var habitIcon: String {
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
    
    var reasonText: String {
        if habit.isHiddenSafe {
            return "Manually hidden"
        } else if !habit.isScheduledForToday {
            // Show which days it's scheduled for
            let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            let days = habit.daysOfWeek.sorted().compactMap { $0 >= 1 && $0 <= 7 ? dayNames[$0] : nil }
            return "Only on \(days.joined(separator: ", "))"
        }
        return ""
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Text(habitIcon)
                .font(.system(size: 20))
                .frame(width: 32, height: 32)
                .background(Color.gray.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(reasonText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Unhide button (only for manually hidden)
            if habit.isHiddenSafe {
                Button {
                    onUnhide()
                } label: {
                    Image(systemName: "eye")
                        .font(.subheadline)
                        .foregroundStyle(Color.clarityPurple)
                        .padding(8)
                        .background(Color.clarityPurple.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            // Delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundStyle(.red.opacity(0.7))
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.clarityCard.opacity(0.3))
        .cornerRadius(10)
        .opacity(0.7)
    }
}
