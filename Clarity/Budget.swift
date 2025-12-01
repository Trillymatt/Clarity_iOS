import Foundation
import SwiftData

@Model
final class Budget {
    var id: UUID
    var categoryRaw: String
    var limit: Double
    var period: String
    
    var category: TransactionCategory {
        get { TransactionCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), category: TransactionCategory, limit: Double, period: String = "Monthly") {
        self.id = id
        self.categoryRaw = category.rawValue
        self.limit = limit
        self.period = period
    }
}
