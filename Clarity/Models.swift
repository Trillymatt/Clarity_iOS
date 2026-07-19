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
    
    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), ownerEmail: String = "", title: String, notes: String? = nil, dueDate: Date? = nil, isCompleted: Bool = false, isToday: Bool = false, category: TaskCategory = .other, estimatedMinutes: Int? = nil, completedDate: Date? = nil, notifyOnDueDate: Bool = false, isInProgress: Bool = false) {
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
    
    init(id: UUID = UUID(), ownerEmail: String = "", name: String, iconName: String? = nil, goalPerDay: Int? = nil, daysOfWeek: [Int] = [], isActive: Bool = true, displayOrder: Int = 0, notificationsEnabled: Bool = false, reminderTime: Date? = nil) {
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
    
    var type: MomentType {
        get { MomentType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), ownerEmail: String = "", date: Date = Date(), title: String, note: String? = nil, moodScore: Double? = nil, type: MomentType = .other) {
        self.id = id
        self.ownerEmail = ownerEmail
        self.date = date
        self.title = title
        self.note = note
        self.moodScore = moodScore
        self.typeRaw = type.rawValue
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
    
    var category: TransactionCategory {
        get { TransactionCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), ownerEmail: String = "", amount: Double, date: Date = Date(), category: TransactionCategory = .other, note: String? = nil, isRecurring: Bool = false) {
        self.id = id
        self.ownerEmail = ownerEmail
        self.amount = amount
        self.date = date
        self.categoryRaw = category.rawValue
        self.note = note
        self.isRecurring = isRecurring
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

