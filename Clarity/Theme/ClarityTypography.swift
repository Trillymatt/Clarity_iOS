import SwiftUI

// MARK: - Clarity Typography
// Unified text styles following the calm, intentional design language

extension Font {
    // MARK: - Display Styles
    
    /// Hero text - Large welcoming headers (34pt)
    static let clarityHero = Font.system(size: 34, weight: .bold, design: .rounded)
    
    /// Title - Section headers (22pt)
    static let clarityTitle = Font.system(size: 22, weight: .semibold, design: .default)
    
    /// Subtitle - Secondary headers (17pt)
    static let claritySubtitle = Font.system(size: 17, weight: .medium, design: .default)
    
    // MARK: - Body Styles
    
    /// Body text (17pt)
    static let clarityBody = Font.system(size: 17, weight: .regular, design: .default)
    
    /// Callout - Emphasized body (16pt)
    static let clarityCallout = Font.system(size: 16, weight: .medium, design: .default)
    
    // MARK: - Detail Styles
    
    /// Caption - Metadata and labels (13pt)
    static let clarityCaption = Font.system(size: 13, weight: .regular, design: .default)
    
    /// Caption Bold - Emphasized metadata (13pt)
    static let clarityCaptionBold = Font.system(size: 13, weight: .semibold, design: .default)
    
    // MARK: - Insight Style
    
    /// Insight text - Micro-insights with personality (15pt)
    static let clarityInsight = Font.system(size: 15, weight: .medium, design: .rounded)
    
    // MARK: - Score Display

    /// Large score number (60pt) - monospaced digits for a HUD-readout feel
    static let clarityScoreLarge = Font.system(size: 60, weight: .bold, design: .rounded).monospacedDigit()

    /// Medium score number (40pt) - monospaced digits for a HUD-readout feel
    static let clarityScoreMedium = Font.system(size: 40, weight: .bold, design: .rounded).monospacedDigit()
}

// MARK: - Text View Modifiers

extension View {
    /// Apply hero style
    func heroStyle() -> some View {
        self
            .font(.clarityHero)
            .foregroundStyle(.primary)
    }

    /// Apply insight style with accent color
    func insightStyle() -> some View {
        self
            .font(.clarityInsight)
            .foregroundStyle(Color(hex: "#FFA98F"))
    }
}

// MARK: - Line Spacing & Letter Spacing

extension Text {
    /// Add breathing room with line spacing
    func withLineSpacing(_ spacing: CGFloat = 6) -> some View {
        self.lineSpacing(spacing)
    }
    
    /// Add letter spacing for elegance
    func withTracking(_ tracking: CGFloat = 0.5) -> some View {
        self.tracking(tracking)
    }
}
