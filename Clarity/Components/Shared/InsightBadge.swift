import SwiftUI

// MARK: - Insight Badge
// Small, inline micro-insight display component

struct InsightBadge: View {
    let text: String
    let type: InsightType
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
            }
            
            Text(text)
                .font(.clarityInsight)
                .lineLimit(1)
        }
        .foregroundStyle(colorForType)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(colorForType.opacity(0.16))
        )
        .overlay(
            Capsule().strokeBorder(colorForType.opacity(0.35), lineWidth: 1)
        )
    }
    
    private var colorForType: Color {
        switch type {
        case .task:
            return Color.clarityBlue
        case .habit:
            return Color.clarityOrange
        case .mood:
            return Color.clarityPink
        case .finance:
            return Color.clarityTeal
        case .general, .correlation:
            return Color.clarityPurple
        }
    }
}

// MARK: - Section Header with Insight
struct SectionHeader: View {
    let title: String
    let insight: String?
    var action: (() -> Void)? = nil
    var actionLabel: String = "See All"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.clarityTitle)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if let action = action {
                    Button(action: action) {
                        Text(actionLabel)
                            .font(.clarityCallout)
                            .foregroundStyle(Color.clarityBlue)
                    }
                }
            }
            
            if let insight = insight {
                InsightBadge(text: insight, type: .general, icon: "sparkles")
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        InsightBadge(text: "3-day streak building!", type: .habit, icon: "flame.fill")
        
        InsightBadge(text: "Great productivity this week", type: .task, icon: "checkmark.circle.fill")
        
        SectionHeader(
            title: "Today's Focus",
            insight: "5 tasks remaining",
            action: { print("See all") }
        )
        
        SectionHeader(
            title: "Habits",
            insight: nil
        )
    }
    .padding()
}
