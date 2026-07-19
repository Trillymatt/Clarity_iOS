import Foundation
import SwiftData

/// Helper to compute and update widget data from the main app
class WidgetDataUpdater {
    static func updateWidgetData(context: ModelContext, userEmail: String) {
        Task {
            do {
                // Fetch all necessary data
                let taskDescriptor = FetchDescriptor<TaskItem>(
                    predicate: #Predicate { $0.ownerEmail == userEmail }
                )
                let tasks = try context.fetch(taskDescriptor)
                
                let habitDescriptor = FetchDescriptor<Habit>(
                    predicate: #Predicate { $0.ownerEmail == userEmail },
                    sortBy: [SortDescriptor(\.displayOrder)]
                )
                let habits = try context.fetch(habitDescriptor)
                
                let checkinDescriptor = FetchDescriptor<HabitCheckin>(
                    predicate: #Predicate { $0.ownerEmail == userEmail }
                )
                let checkins = try context.fetch(checkinDescriptor)

                let workoutDescriptor = FetchDescriptor<Workout>(
                    predicate: #Predicate { $0.ownerEmail == userEmail }
                )
                let workouts = (try? context.fetch(workoutDescriptor)) ?? []

                let bodyMetricDescriptor = FetchDescriptor<BodyMetric>(
                    predicate: #Predicate { $0.ownerEmail == userEmail }
                )
                let bodyMetrics = (try? context.fetch(bodyMetricDescriptor)) ?? []

                let goals = UserGoals.fetchOrCreate(context: context, ownerEmail: userEmail)

                // Calculate today's tasks
                let calendar = Calendar.current
                let todayTasks = tasks.filter { task in
                    if task.isToday { return true }
                    guard let due = task.dueDate else { return false }
                    return calendar.isDateInToday(due)
                }
                let todayCompleted = todayTasks.filter { $0.isCompleted }.count
                let todayTotal = todayTasks.count
                
                // Get primary habit (first active habit)
                let primaryHabit = habits.first { $0.isActive }
                var habitProgress = 0
                var habitGoal = 1
                
                if let habit = primaryHabit {
                    habitGoal = habit.goalPerDay ?? 1
                    habitProgress = checkins.filter { checkin in
                        checkin.habit?.id == habit.id && calendar.isDateInToday(checkin.date)
                    }.reduce(0) { $0 + $1.value }
                }
                
                // Calculate Clarity Score
                let score = ClarityScoreCalculator.calculateFullScore(
                    tasks: tasks,
                    habits: habits,
                    checkins: checkins,
                    moodEntries: [],
                    moments: [],
                    transactions: [],
                    workouts: workouts,
                    bodyMetrics: bodyMetrics,
                    goals: goals
                )

                // Fitness snapshot for the Fitness/Goals widgets
                let todaySteps = bodyMetrics.first { calendar.isDateInToday($0.date) }?.steps
                let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                let weekWorkouts = workouts.filter { $0.date >= weekAgo }.count

                let workoutDays = Set(workouts.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
                var workoutStreak = 0
                if let mostRecent = workoutDays.first {
                    let daysSince = calendar.dateComponents([.day], from: mostRecent, to: calendar.startOfDay(for: Date())).day ?? 0
                    if daysSince <= 1 {
                        var cursor = mostRecent
                        for day in workoutDays {
                            if day == cursor {
                                workoutStreak += 1
                                cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
                            } else {
                                break
                            }
                        }
                    }
                }
                
                // Prepare upcoming tasks (top 5, sorted by completion and due time)
                let sortedTasks = todayTasks
                    .sorted { (task1: TaskItem, task2: TaskItem) -> Bool in
                        // Incomplete tasks first
                        if task1.isCompleted != task2.isCompleted {
                            return !task1.isCompleted
                        }
                        // Then by due time
                        if let due1 = task1.dueDate, let due2 = task2.dueDate {
                            return due1 < due2
                        }
                        // Tasks with due dates take priority
                        if task1.dueDate != nil && task2.dueDate == nil {
                            return true
                        }
                        return false
                    }
                    .prefix(5)
                    .map { task in
                        WidgetTask(
                            id: task.id,
                            title: task.title,
                            isCompleted: task.isCompleted,
                            priority: 0, // Default priority since TaskItem doesn't have this field
                            dueTime: task.dueDate
                        )
                    }
                
                // Prepare active habits (top 5)
                let activeHabitsData = habits
                    .filter { $0.isActive }
                    .prefix(5)
                    .map { habit -> WidgetHabit in
                        let habitGoal = habit.goalPerDay ?? 1
                        let habitProgress = checkins.filter { checkin in
                            checkin.habit?.id == habit.id && calendar.isDateInToday(checkin.date)
                        }.reduce(0) { $0 + $1.value }
                        
                        return WidgetHabit(
                            id: habit.id,
                            name: habit.name,
                            icon: habit.iconName ?? "star.fill",
                            progress: min(habitProgress, habitGoal),
                            goal: habitGoal,
                            colorHex: nil // Habit model doesn't have a color property
                        )
                    }
                
                // Create widget data
                var widgetData = WidgetData(
                    clarityScore: Int(score.totalScore),
                    todayTasksCompleted: todayCompleted,
                    todayTasksTotal: max(todayTotal, 1), // Prevent division by zero
                    primaryHabitName: primaryHabit?.name,
                    primaryHabitProgress: min(habitProgress, habitGoal),
                    primaryHabitGoal: habitGoal,
                    primaryHabitIcon: primaryHabit?.iconName,
                    lastUpdated: Date(),
                    upcomingTasks: Array(sortedTasks),
                    activeHabits: Array(activeHabitsData)
                )
                widgetData.todaySteps = todaySteps
                widgetData.stepGoal = goals.dailyStepGoal
                widgetData.weekWorkouts = weekWorkouts
                widgetData.weeklyWorkoutGoal = goals.weeklyWorkoutGoal
                widgetData.tasksCompletedToday = todayCompleted
                widgetData.dailyTaskGoal = goals.dailyTaskGoal
                widgetData.workoutStreak = workoutStreak

                // Save to shared storage
                WidgetDataManager.shared.saveWidgetData(widgetData)
                
            } catch {
                print("Failed to update widget data: \(error)")
            }
        }
    }
}
