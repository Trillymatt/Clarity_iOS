import Foundation
import SwiftData

@Model
final class MoodEntry {
    var ownerEmail: String
    var date: Date
    var moodScore: Double // 0.0 to 1.0
    var emotion: String
    var note: String?
    
    init(ownerEmail: String = "", date: Date = Date(), moodScore: Double, emotion: String, note: String? = nil) {
        self.ownerEmail = ownerEmail
        self.date = date
        self.moodScore = moodScore
        self.emotion = emotion
        self.note = note
    }
}
