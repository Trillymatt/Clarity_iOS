import SwiftUI

// MARK: - Clarity Gradients
// Signature gradients that define the Clarity visual identity

extension LinearGradient {
    // MARK: - Score Gradients
    
    /// Thriving state (80-100 score) - Vibrant green gradient
    static let clarityThriving = LinearGradient(
        colors: [Color(hex: "#4ADE80"), Color(hex: "#22C55E")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Growing state (60-79 score) - Calm blue gradient
    static let clarityGrowing = LinearGradient(
        colors: [Color(hex: "#60A5FA"), Color(hex: "#3B82F6")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Adjusting state (40-59 score) - Warm orange gradient
    static let clarityAdjusting = LinearGradient(
        colors: [Color(hex: "#FB923C"), Color(hex: "#F97316")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Rebuilding state (0-39 score) - Soft purple gradient (no shame)
    static let clarityRebuilding = LinearGradient(
        colors: [Color(hex: "#C084FC"), Color(hex: "#A855F7")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - UI Gradients
    
    /// Primary brand gradient - Soft blue to purple
    static let clarityPrimary = LinearGradient(
        colors: [Color.clarityBlue, Color.clarityPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Calm background gradient
    static let clarityCalmBackground = LinearGradient(
        colors: [
            Color(hex: "#EFF6FF").opacity(0.3),
            Color(hex: "#F5F3FF").opacity(0.3)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Insight accent gradient - Warm coral
    static let clarityInsight = LinearGradient(
        colors: [Color(hex: "#FCA5A5"), Color(hex: "#F87171")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    /// Success gradient
    static let claritySuccess = LinearGradient(
        colors: [Color(hex: "#86EFAC"), Color(hex: "#4ADE80")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Radial Gradients
extension RadialGradient {
    /// Soft glow effect for emphasis
    static let clarityGlow = RadialGradient(
        colors: [
            Color.clarityBlue.opacity(0.3),
            Color.clarityBlue.opacity(0.1),
            Color.clear
        ],
        center: .center,
        startRadius: 0,
        endRadius: 100
    )
}
