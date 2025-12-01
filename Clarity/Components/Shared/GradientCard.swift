import SwiftUI

// MARK: - Gradient Card
// Reusable card component with gradient background and subtle effects

struct GradientCard<Content: View>: View {
    let gradient: LinearGradient
    let content: Content
    var cornerRadius: CGFloat = 20
    var shadowRadius: CGFloat = 10
    
    init(
        gradient: LinearGradient,
        cornerRadius: CGFloat = 20,
        shadowRadius: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) {
        self.gradient = gradient
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(gradient)
            
            content
                .padding()
        }
        .shadow(color: .black.opacity(0.1), radius: shadowRadius, x: 0, y: 4)
    }
}

// MARK: - Soft Card (Material Background)
struct SoftCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 16
    
    init(
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
            
            content
                .padding()
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Insight Card (Accent Style)
struct InsightCard: View {
    let insight: String
    var icon: String = "lightbulb.fill"
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(LinearGradient.clarityInsight)
            
            Text(insight)
                .font(.clarityInsight)
                .foregroundStyle(.primary)
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#FEF2F2"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(LinearGradient.clarityInsight, lineWidth: 1.5)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        GradientCard(gradient: .clarityPrimary) {
            VStack {
                Text("Gradient Card")
                    .font(.clarityTitle)
                    .foregroundStyle(.white)
                Text("With custom content")
                    .font(.clarityBody)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(height: 150)
        
        SoftCard {
            VStack(alignment: .leading) {
                Text("Soft Material Card")
                    .font(.clarityTitle)
                Text("Ultra thin material background")
                    .font(.clarityCaption)
                    .foregroundStyle(.secondary)
            }
        }
        
        InsightCard(insight: "Great productivity this week!")
    }
    .padding()
}
