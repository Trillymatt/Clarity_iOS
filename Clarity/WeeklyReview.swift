import Foundation
import SwiftData

@Model
final class WeeklyReview {
    var id: UUID = UUID()
    var ownerEmail: String = ""
    var date: Date = Date()
    var wins: String = ""
    var challenges: String = ""
    var learnings: String = ""
    var improvements: String = ""
    var habitAdherence: Int = 3
    var topGoals: [String] = []
    var mainFocus: String = ""
    var habitFocus: String = ""
    var weekRating: Int = 3
    
    init(ownerEmail: String = "", date: Date = Date(), wins: String = "", challenges: String = "", learnings: String = "", improvements: String = "", habitAdherence: Int = 3, topGoals: [String] = [], mainFocus: String = "", habitFocus: String = "", weekRating: Int = 3) {
        self.id = UUID()
        self.ownerEmail = ownerEmail
        self.date = date
        self.wins = wins
        self.challenges = challenges
        self.learnings = learnings
        self.improvements = improvements
        self.habitAdherence = habitAdherence
        self.topGoals = topGoals
        self.mainFocus = mainFocus
        self.habitFocus = habitFocus
        self.weekRating = weekRating
    }
}
