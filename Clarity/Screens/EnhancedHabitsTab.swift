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
    
    // MARK: - Computed Properties
    
    var activeHabits: [Habit] {
        habits.filter { $0.isActive }.sorted { $0.displayOrder < $1.displayOrder }
    }
    
    var primaryHabit: Habit? {
        activeHabits.first
    }
    
    var otherHabits: [Habit] {
        Array(activeHabits.dropFirst())
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
        
        // If at or above goal, reset to 0
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
            
            // Check for streak celebration (only when completing the habit)
            if currentCount + 1 >= goal {
                let streak = calculateStreak(for: habit, includingToday: true)
                
                // Send streak celebration if it's a milestone
                Task { @MainActor in
                    NotificationManager.shared.sendStreakCelebration(habitName: habit.name, streakDays: streak)
                }
            }
        }
        
        try? context.save()
        WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
    }
    
    /// Calculate the current streak for a habit
    private func calculateStreak(for habit: Habit, includingToday: Bool = false) -> Int {
        let calendar = Calendar.current
        let habitCheckins = checkins.filter { $0.habit?.id == habit.id }
        
        guard !habitCheckins.isEmpty else { return includingToday ? 1 : 0 }
        
        // Get all unique days with check-ins, sorted descending
        var checkinDays = Set(habitCheckins.map { calendar.startOfDay(for: $0.date) })
        
        // If including today (for celebration), add today
        if includingToday {
            checkinDays.insert(calendar.startOfDay(for: Date()))
        }
        
        let sortedDays = checkinDays.sorted(by: >)
        guard let mostRecentDay = sortedDays.first else { return includingToday ? 1 : 0 }
        
        let today = calendar.startOfDay(for: Date())
        
        // If most recent check-in isn't today or yesterday, streak is broken
        let daysSinceLastCheckin = calendar.dateComponents([.day], from: mostRecentDay, to: today).day ?? 0
        if daysSinceLastCheckin > 1 {
            return includingToday ? 1 : 0
        }
        
        // Count consecutive days backwards
        var streak = 0
        var currentDay = mostRecentDay
        
        for day in sortedDays {
            if day == currentDay {
                streak += 1
                // Move to previous day
                currentDay = calendar.date(byAdding: .day, value: -1, to: currentDay)!
            } else {
                // Gap in streak
                break
            }
        }
        
        return streak
    }
    
    private func moveHabit(from source: IndexSet, to destination: Int) {
        var reorderedHabits = otherHabits
        reorderedHabits.move(fromOffsets: source, toOffset: destination)
        
        // Update display orders (primary = 0, others start from 1)
        for (index, habit) in reorderedHabits.enumerated() {
            habit.displayOrder = index + 1
        }
        
        try? context.save()
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Header & Score
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(Date(), format: .dateTime.weekday(.wide).day().month())
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                
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
                            
                            // Other Habits
                            if !otherHabits.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Your Routine")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                    
                                    ForEach(otherHabits) { habit in
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
                                    }
                                    .onMove(perform: moveHabit)
                                }
                            }
                        
                        // Suggestions (always show)
                        SuggestedHabitsView(userEmail: userEmail)
                        
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
    
    var body: some View {
        Button(action: { showEdit = true }) {
            HStack(spacing: 16) {
                // Large Icon
                Text(habitIcon)
                    .font(.system(size: 48))
                    .frame(width: 64, height: 64)
                    .background(Color.clarityOrange.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(habit.name)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    
                    if let goal = habit.goalPerDay {
                        if goal > 1 {
                            // Show progress for multi-completion habits
                            Text("\(todayCount)/\(goal) today")
                                .font(.subheadline)
                                .foregroundStyle(todayCount >= goal ? Color.clarityOrange : .secondary)
                        } else {
                            // Single completion habit
                            Text("Daily")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Check-in Button
                Button(action: onCheckIn) {
                    Image(systemName: isCheckedIn ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 32))
                        .foregroundStyle(isCheckedIn ? Color.clarityOrange : Color.secondary.opacity(0.3))
                        .contentShape(Rectangle()) // Make touch area larger
                }
                .buttonStyle(.plain) // Prevent row click
            }
            .padding(20)
            .background(Color.clarityCard)
            .cornerRadius(20)
            .shadow(color: Color.clarityOrange.opacity(0.1), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.clarityOrange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
    
    var body: some View {
        Button(action: { showEdit = true }) {
            HStack(spacing: 16) {
                Text(habitIcon)
                    .font(.system(size: 32))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    if let goal = habit.goalPerDay {
                        if goal > 1 {
                            // Show progress for multi-completion habits
                            Text("\(todayCount)/\(goal) today")
                                .font(.caption)
                                .foregroundStyle(todayCount >= goal ? Color.clarityOrange : .secondary)
                        } else {
                            // Single completion habit
                            Text("Daily")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Check-in Button
                Button(action: onCheckIn) {
                    Image(systemName: isCheckedIn ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28))
                        .foregroundStyle(isCheckedIn ? Color.clarityOrange : Color.secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.clarityCard)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEdit) {
            AddHabitSheet(userEmail: userEmail, habitToEdit: habit)
        }
    }
}
