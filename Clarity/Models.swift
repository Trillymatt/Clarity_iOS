import Foundation
import SwiftData

// MARK: - Enums

enum TaskCategory: String, Codable, CaseIterable, Identifiable {
    case work, school, personal, other
    var id: String { rawValue }
}

enum MomentType: String, Codable, CaseIterable, Identifiable {
    case win, gratitude, connection, challenge, other
    var id: String { rawValue }
}

enum HabitType: String, Codable, CaseIterable, Identifiable {
    case build
    case quit // Using 'quit' instead of 'break' to avoid keyword conflicts and for clarity
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .build: return "Build Routine"
        case .quit: return "Break Habit"
        }
    }
}

enum TransactionCategory: String, Codable, CaseIterable, Identifiable {
    case food, shopping, bills, transport, entertainment, other
    var id: String { rawValue }
}

// MARK: - Models

@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var ownerEmail: String
    var title: String
    var notes: String?
    var dueDate: Date?
    var isCompleted: Bool
    var isToday: Bool
    var categoryRaw: String
    var estimatedMinutes: Int?
    var completedDate: Date?
    var notifyOnDueDate: Bool
    var isInProgress: Bool
    var timerStartTime: Date?
    var timerDurationMinutes: Int?
    
    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), ownerEmail: String = "", title: String, notes: String? = nil, dueDate: Date? = nil, isCompleted: Bool = false, isToday: Bool = false, category: TaskCategory = .other, estimatedMinutes: Int? = nil, completedDate: Date? = nil, notifyOnDueDate: Bool = false, isInProgress: Bool = false, timerStartTime: Date? = nil, timerDurationMinutes: Int? = nil) {
        self.id = id
        self.ownerEmail = ownerEmail
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.isToday = isToday
        self.categoryRaw = category.rawValue
        self.estimatedMinutes = estimatedMinutes
        self.completedDate = completedDate
        self.notifyOnDueDate = notifyOnDueDate
        self.isInProgress = isInProgress
        self.timerStartTime = timerStartTime
        self.timerDurationMinutes = timerDurationMinutes
    }
    
    // MARK: - Timer Helpers
    
    /// Returns the end time of the timer if one is set
    var timerEndTime: Date? {
        guard let start = timerStartTime, let duration = timerDurationMinutes else { return nil }
        return Calendar.current.date(byAdding: .minute, value: duration, to: start)
    }
    
    /// Returns the remaining seconds on the timer, or nil if no timer is set
    var remainingSeconds: Int? {
        guard let endTime = timerEndTime else { return nil }
        let remaining = Int(endTime.timeIntervalSinceNow)
        return max(0, remaining)
    }
    
    /// Returns true if the timer has expired
    var isTimerExpired: Bool {
        guard let remaining = remainingSeconds else { return false }
        return remaining <= 0
    }
    
    // MARK: - Overdue Detection
    
    /// Returns true if the task is past its due date and not completed
    /// Only considers the date, not the time - a task due today won't be overdue until tomorrow
    var isOverdue: Bool {
        guard !isCompleted, let dueDate = dueDate else { return false }
        let calendar = Calendar.current
        let endOfDueDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: dueDate)!)
        return Date() >= endOfDueDay
    }
}

@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var ownerEmail: String
    var name: String
    var iconName: String?
    var goalPerDay: Int?
    var daysOfWeek: [Int]
    var isActive: Bool
    var displayOrder: Int
    var notificationsEnabled: Bool
    var reminderTime: Date?
    var habitTypeRaw: String? // Optional for migration compatibility
    
    var habitType: HabitType {
        get { 
            guard let raw = habitTypeRaw else { return .build }
            return HabitType(rawValue: raw) ?? .build 
        }
        set { habitTypeRaw = newValue.rawValue }
    }
    
    // MARK: - Migration-Safe Properties (use optionals for new fields)
    /// Whether the habit is manually hidden by the user. Nil = not hidden (default false)
    var isHidden: Bool?
    
    /// Check if this habit is scheduled for today based on daysOfWeek
    var isScheduledForToday: Bool {
        // Empty daysOfWeek means daily (all days)
        if daysOfWeek.isEmpty { return true }
        
        // Get current day of week (1 = Sunday, 7 = Saturday)
        let today = Calendar.current.component(.weekday, from: Date())
        return daysOfWeek.contains(today)
    }
    
    /// Safe accessor for isHidden that treats nil as false
    var isHiddenSafe: Bool {
        isHidden ?? false
    }
    
    init(id: UUID = UUID(), ownerEmail: String = "", name: String, iconName: String? = nil, goalPerDay: Int? = nil, daysOfWeek: [Int] = [], isActive: Bool = true, displayOrder: Int = 0, notificationsEnabled: Bool = false, reminderTime: Date? = nil, isHidden: Bool? = nil, habitType: HabitType = .build) {
        self.id = id
        self.ownerEmail = ownerEmail
        self.name = name
        self.iconName = iconName
        self.goalPerDay = goalPerDay
        self.daysOfWeek = daysOfWeek
        self.isActive = isActive
        self.displayOrder = displayOrder
        self.notificationsEnabled = notificationsEnabled
        self.reminderTime = reminderTime
        self.isHidden = isHidden
        self.habitTypeRaw = habitType.rawValue
    }
    
    /// Calculates the current streak based on provided check-ins
    func currentStreak(from allCheckins: [HabitCheckin]) -> Int {
        let calendar = Calendar.current
        let myCheckins = allCheckins.filter { $0.habit?.id == self.id }
        
        guard !myCheckins.isEmpty else { return 0 }
        
        // Get all unique days with check-ins, sorted descending
        let checkinDays = Set(myCheckins.map { calendar.startOfDay(for: $0.date) })
            .sorted(by: >)
        
        guard let mostRecentDay = checkinDays.first else { return 0 }
        
        let today = calendar.startOfDay(for: Date())
        
        // If most recent check-in isn't today or yesterday, streak is broken
        let daysSinceLastCheckin = calendar.dateComponents([.day], from: mostRecentDay, to: today).day ?? 0
        if daysSinceLastCheckin > 1 {
            return 0
        }
        
        // Count consecutive days backwards
        var streak = 0
        var currentDay = mostRecentDay
        
        for day in checkinDays {
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
}

@Model
final class HabitCheckin {
    @Attribute(.unique) var id: UUID
    var ownerEmail: String
    @Relationship(deleteRule: .nullify) var habit: Habit?
    var date: Date
    var value: Int
    var isCompleted: Bool
    
    init(id: UUID = UUID(), ownerEmail: String = "", habit: Habit, date: Date, value: Int = 0, isCompleted: Bool = false) {
        self.id = id
        self.ownerEmail = ownerEmail
        self.habit = habit
        self.date = date
        self.value = value
        self.isCompleted = isCompleted
    }
}

@Model
final class JournalEntry {
    @Attribute(.unique) var id: UUID
    var ownerEmail: String
    var date: Date
    var moodScore: Int
    var stressLevel: Int?
    var text: String
    var tags: [String]
    
    init(id: UUID = UUID(), ownerEmail: String = "", date: Date = Date(), moodScore: Int = 3, stressLevel: Int? = nil, text: String = "", tags: [String] = []) {
        self.id = id
        self.ownerEmail = ownerEmail
        self.date = date
        self.moodScore = moodScore
        self.stressLevel = stressLevel
        self.text = text
        self.tags = tags
    }
}

@Model
final class LifeMoment {
    @Attribute(.unique) var id: UUID
    var ownerEmail: String
    var date: Date
    var title: String
    var note: String?
    var moodScore: Double?
    var typeRaw: String
    // SwiftData can externalize a single Data value, but not an array of Data
    // values. Persist the encoded array as one external blob and preserve the
    // existing imagesData API for the views that add and display photos.
    @Attribute(.externalStorage) var imagesArchiveData: Data?

    var imagesData: [Data]? {
        get {
            guard let imagesArchiveData else { return nil }
            return try? PropertyListDecoder().decode([Data].self, from: imagesArchiveData)
        }
        set {
            guard let newValue, !newValue.isEmpty else {
                imagesArchiveData = nil
                return
            }
            imagesArchiveData = try? PropertyListEncoder().encode(newValue)
        }
    }
    
    var type: MomentType {
        get { MomentType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), ownerEmail: String = "", date: Date = Date(), title: String, note: String? = nil, moodScore: Double? = nil, type: MomentType = .other, imagesData: [Data]? = nil) {
        self.id = id
        self.ownerEmail = ownerEmail
        self.date = date
        self.title = title
        self.note = note
        self.moodScore = moodScore
        self.typeRaw = type.rawValue
        self.imagesArchiveData = imagesData.flatMap {
            try? PropertyListEncoder().encode($0)
        }
    }
}

enum TransactionInterval: String, Codable, CaseIterable, Identifiable {
    case weekly, monthly, yearly
    var id: String { rawValue }
    
    var displayName: String {
        rawValue.capitalized
    }
}

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var ownerEmail: String
    var amount: Double
    var date: Date
    var categoryRaw: String
    var note: String?
    var isRecurring: Bool
    var recurrenceIntervalRaw: String?
    
    var category: TransactionCategory {
        get { TransactionCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
    
    var recurrenceInterval: TransactionInterval {
        get {
            guard let raw = recurrenceIntervalRaw else { return .monthly }
            return TransactionInterval(rawValue: raw) ?? .monthly
        }
        set { recurrenceIntervalRaw = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), ownerEmail: String = "", amount: Double, date: Date = Date(), category: TransactionCategory = .other, note: String? = nil, isRecurring: Bool = false, recurrenceInterval: TransactionInterval = .monthly) {
        self.id = id
        self.ownerEmail = ownerEmail
        self.amount = amount
        self.date = date
        self.categoryRaw = category.rawValue
        self.note = note
        self.isRecurring = isRecurring
        self.recurrenceIntervalRaw = recurrenceInterval.rawValue
    }
}

@Model
final class FinancialGoal {
    @Attribute(.unique) var id: UUID
    var ownerEmail: String
    var title: String
    var targetAmount: Double
    var currentAmount: Double
    var dueDate: Date?
    
    init(id: UUID = UUID(), ownerEmail: String = "", title: String, targetAmount: Double, currentAmount: Double = 0, dueDate: Date? = nil) {
        self.id = id
        self.ownerEmail = ownerEmail
        self.title = title
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.dueDate = dueDate
    }
}
