import Foundation
import SwiftData

@Model
final class Budget {
    @Attribute(.unique) var id: UUID
    var ownerEmail: String
    var categoryRaw: String
    var limit: Double
    var period: String

    var category: TransactionCategory {
        get { TransactionCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), ownerEmail: String = "", category: TransactionCategory, limit: Double, period: String = "Monthly") {
        self.id = id
        self.ownerEmail = ownerEmail
        self.categoryRaw = category.rawValue
        self.limit = limit
        self.period = period
    }
}
