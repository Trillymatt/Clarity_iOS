import Foundation

// MARK: - Insight Type
// Drives the color/icon of InsightBadge (Components/Shared/InsightBadge.swift).
// The generic canned-insight generators that used to live here were removed —
// RecommendationEngine.swift now produces real, data-grounded insights instead.
enum InsightType: String, Codable {
    case task
    case habit
    case mood
    case finance
    case general
    case correlation // Cross-category insights
}
