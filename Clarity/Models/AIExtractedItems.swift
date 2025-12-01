import Foundation

// MARK: - Suggested Item Models

struct SuggestedMoment: Identifiable, Codable {
    var id: UUID
    var title: String
    var type: String // "win", "gratitude", "connection", "challenge", "other"
    var note: String?
    
    var momentType: MomentType {
        MomentType(rawValue: type) ?? .other
    }
    
    enum CodingKeys: String, CodingKey {
        case title, type, note
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.type = try container.decode(String.self, forKey: .type)
        self.note = try container.decodeIfPresent(String.self, forKey: .note)
    }
}

struct SuggestedHabit: Identifiable, Codable {
    var id: UUID
    var name: String
    var goalPerDay: Int
    
    enum CodingKeys: String, CodingKey {
        case name, goalPerDay
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.goalPerDay = try container.decode(Int.self, forKey: .goalPerDay)
    }
}

struct SuggestedTask: Identifiable, Codable {
    var id: UUID
    var title: String
    var category: String // "work", "school", "personal", "other"
    
    var taskCategory: TaskCategory {
        TaskCategory(rawValue: category) ?? .other
    }
    
    enum CodingKeys: String, CodingKey {
        case title, category
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.category = try container.decode(String.self, forKey: .category)
    }
}

struct ExtractedItems: Codable, Identifiable {
    var id = UUID()
    var moments: [SuggestedMoment]
    var habits: [SuggestedHabit]
    var tasks: [SuggestedTask]
    
    enum CodingKeys: String, CodingKey {
        case moments, habits, tasks
    }
    
    var isEmpty: Bool {
        moments.isEmpty && habits.isEmpty && tasks.isEmpty
    }
    
    var totalCount: Int {
        moments.count + habits.count + tasks.count
    }
}
