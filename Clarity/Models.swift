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
    var title: String
    var notes: String?
    var dueDate: Date?
    var isCompleted: Bool
    var isToday: Bool
    var categoryRaw: String
    var estimatedMinutes: Int?
    
    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), title: String, notes: String? = nil, dueDate: Date? = nil, isCompleted: Bool = false, isToday: Bool = false, category: TaskCategory = .other, estimatedMinutes: Int? = nil) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.isToday = isToday
        self.categoryRaw = category.rawValue
        self.estimatedMinutes = estimatedMinutes
    }
}

@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconName: String?
    var goalPerDay: Int?
    var daysOfWeek: [Int]
    var isActive: Bool
    
    init(id: UUID = UUID(), name: String, iconName: String? = nil, goalPerDay: Int? = nil, daysOfWeek: [Int] = [], isActive: Bool = true) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.goalPerDay = goalPerDay
        self.daysOfWeek = daysOfWeek
        self.isActive = isActive
    }
}

@Model
final class HabitCheckin {
    @Attribute(.unique) var id: UUID
    @Relationship var habit: Habit
    var date: Date
    var value: Int
    var isCompleted: Bool
    
    init(id: UUID = UUID(), habit: Habit, date: Date, value: Int = 0, isCompleted: Bool = false) {
        self.id = id
        self.habit = habit
        self.date = date
        self.value = value
        self.isCompleted = isCompleted
    }
}

@Model
final class JournalEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var moodScore: Int
    var stressLevel: Int?
    var text: String
    var tags: [String]
    
    init(id: UUID = UUID(), date: Date = Date(), moodScore: Int = 3, stressLevel: Int? = nil, text: String = "", tags: [String] = []) {
        self.id = id
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
    var date: Date
    var title: String
    var note: String?
    var moodScore: Int?
    var typeRaw: String
    
    var type: MomentType {
        get { MomentType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), date: Date = Date(), title: String, note: String? = nil, moodScore: Int? = nil, type: MomentType = .other) {
        self.id = id
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
    var amount: Double
    var date: Date
    var categoryRaw: String
    var note: String?
    var isRecurring: Bool
    
    var category: TransactionCategory {
        get { TransactionCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), amount: Double, date: Date = Date(), category: TransactionCategory = .other, note: String? = nil, isRecurring: Bool = false) {
        self.id = id
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
    var title: String
    var targetAmount: Double
    var currentAmount: Double
    var dueDate: Date?
    
    init(id: UUID = UUID(), title: String, targetAmount: Double, currentAmount: Double = 0, dueDate: Date? = nil) {
        self.id = id
        self.title = title
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.dueDate = dueDate
    }
}

@Model
final class LifeAreaScore {
    @Attribute(.unique) var id: UUID
    var date: Date
    var health: Int
    var mind: Int
    var relationships: Int
    var career: Int
    var finance: Int
    var spiritual: Int
    var growth: Int
    var lifestyle: Int
    
    init(id: UUID = UUID(), date: Date = Date(), health: Int = 5, mind: Int = 5, relationships: Int = 5, career: Int = 5, finance: Int = 5, spiritual: Int = 5, growth: Int = 5, lifestyle: Int = 5) {
        self.id = id
        self.date = date
        self.health = health
        self.mind = mind
        self.relationships = relationships
        self.career = career
        self.finance = finance
        self.spiritual = spiritual
        self.growth = growth
        self.lifestyle = lifestyle
    }
}
