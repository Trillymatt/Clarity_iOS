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

// MARK: - Soft Card (Glass Background)
struct SoftCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 16
    var glow: Color? = nil

    init(
        cornerRadius: CGFloat = 16,
        glow: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.glow = glow
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.claritySurface.opacity(0.45))

            content
                .padding()
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: (glow ?? .black).opacity(glow == nil ? 0.3 : 0.35), radius: glow == nil ? 10 : 20, x: 0, y: glow == nil ? 4 : 8)
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
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
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
