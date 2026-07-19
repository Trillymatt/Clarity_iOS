import Foundation
import SwiftData

// MARK: - Assistant Message
// Persisted Jarvis conversation history, so the chat survives app relaunch.

@Model
final class AssistantMessage {
    @Attribute(.unique) var id: UUID
    var ownerEmail: String
    /// "user" or "assistant"
    var role: String
    var content: String
    var actionSummary: String?
    var timestamp: Date

    init(
        id: UUID = UUID(),
        ownerEmail: String = "",
        role: String,
        content: String,
        actionSummary: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.ownerEmail = ownerEmail
        self.role = role
        self.content = content
        self.actionSummary = actionSummary
        self.timestamp = timestamp
    }
}
