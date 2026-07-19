import SwiftUI

// MARK: - Clarity Gradients
// Signature gradients that define the Clarity visual identity

extension LinearGradient {
    // MARK: - Score Gradients

    /// Thriving state (80-100 score) - Vibrant green glow
    static let clarityThriving = LinearGradient(
        colors: [Color(hex: "#34F5A6"), Color(hex: "#12B981")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Growing state (60-79 score) - Electric blue glow
    static let clarityGrowing = LinearGradient(
        colors: [Color(hex: "#5FD4FF"), Color(hex: "#3B8CFF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Adjusting state (40-59 score) - Warm amber glow
    static let clarityAdjusting = LinearGradient(
        colors: [Color(hex: "#FFC069"), Color(hex: "#FF9736")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Rebuilding state (0-39 score) - Soft violet glow (no shame)
    static let clarityRebuilding = LinearGradient(
        colors: [Color(hex: "#C6A6FF"), Color(hex: "#9B6BFF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - UI Gradients

    /// Primary brand gradient - Electric blue to violet
    static let clarityPrimary = LinearGradient(
        colors: [Color.clarityBlue, Color.clarityPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Calm background wash for full-screen dark surfaces
    static let clarityCalmBackground = LinearGradient(
        colors: [
            Color(hex: "#0B0F1A"),
            Color(hex: "#13122A")
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Insight accent gradient - Warm coral, legible on dark surfaces
    static let clarityInsight = LinearGradient(
        colors: [Color(hex: "#FFA98F"), Color(hex: "#FF7A6B")],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Success gradient
    static let claritySuccess = LinearGradient(
        colors: [Color(hex: "#5CF2B0"), Color(hex: "#34D97E")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Fitness accent gradient - teal to blue, for the new fitness module
    static let clarityFitness = LinearGradient(
        colors: [Color(hex: "#35E6C0"), Color(hex: "#4DC8FF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Radial Gradients
extension RadialGradient {
    /// Soft blue glow effect for emphasis (AI / score elements)
    static let clarityGlow = RadialGradient(
        colors: [
            Color.clarityBlue.opacity(0.45),
            Color.clarityBlue.opacity(0.15),
            Color.clear
        ],
        center: .center,
        startRadius: 0,
        endRadius: 100
    )

    /// Violet variant of the glow, used behind AI/assistant surfaces
    static let clarityGlowPurple = RadialGradient(
        colors: [
            Color.clarityPurple.opacity(0.45),
            Color.clarityPurple.opacity(0.15),
            Color.clear
        ],
        center: .center,
        startRadius: 0,
        endRadius: 100
    )
}
