import SwiftUI

// MARK: - Clarity Score Card
// The signature hero component displaying the user's Clarity Score

struct ClarityScoreCard: View {
    let score: ClarityScore
    @State private var animateScore = false
    @State private var showBreakdown = false
    
    var body: some View {
        Button(action: { showBreakdown = true }) {
            GradientCard(gradient: gradientForState(score.state)) {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Clarity Score")
                                .font(.clarityCallout)
                                .foregroundStyle(.white.opacity(0.9))
                            
                            Text(score.stateDescription)
                                .font(.claritySubtitle)
                                .foregroundStyle(.white)
                        }
                        
                        Spacer()
                        
                        // Trend indicator
                        TrendIndicator(trend: score.trend)
                    }
                    
                    // Score display
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(Int(animateScore ? score.totalScore : 0))")
                            .font(.clarityScoreLarge)
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                        
                        Text(score.stateEmoji)
                            .font(.system(size: 40))
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Micro insight
                    if let mainInsight = generateMainInsight() {
                        Text(mainInsight)
                            .font(.clarityInsight)
                            .foregroundStyle(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    
                    // Tap hint
                    HStack(spacing: 4) {
                        Text("Tap for breakdown")
                            .font(.clarityCaption)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.vertical, 8)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showBreakdown) {
            ScoreBreakdownView(score: score)
        }
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                animateScore = true
            }
        }
    }
    
    private func gradientForState(_ state: ScoreState) -> LinearGradient {
        switch state {
        case .thriving: return .clarityThriving
        case .growing: return .clarityGrowing
        case .adjusting: return .clarityAdjusting
        case .rebuilding: return .clarityRebuilding
        }
    }
    
    private func generateMainInsight() -> String? {
        // Generate a supportive insight based on score
        switch score.state {
        case .thriving:
            return "You're in flow! Everything's aligned this week."
        case .growing:
            return "Steady progress across all areas. Keep building!"
        case .adjusting:
            return "Finding your rhythm. Small shifts make big changes."
        case .rebuilding:
            return "Every step forward matters. Be kind to yourself."
        }
    }
}

// MARK: - Trend Indicator
struct TrendIndicator: View {
    let trend: ScoreTrend
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.title3)
            
            Text(trendText)
                .font(.clarityCaptionBold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.white.opacity(0.2))
        )
    }
    
    private var iconName: String {
        switch trend {
        case .up: return "arrow.up.right"
        case .neutral: return "minus"
        case .down: return "arrow.down.right"
        }
    }
    
    private var trendText: String {
        switch trend {
        case .up: return "+5%"
        case .neutral: return "Steady"
        case .down: return "-3%"
        }
    }
}

// MARK: - Score Breakdown View
struct ScoreBreakdownView: View {
    @Environment(\.dismiss) private var dismiss
    let score: ClarityScore
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Overall score
                    VStack(spacing: 12) {
                        Text("\(Int(score.totalScore))")
                            .font(.clarityScoreLarge)
                            .foregroundStyle(LinearGradient.clarityPrimary)
                        
                        Text("Clarity Score")
                            .font(.clarityTitle)
                        
                        Text(score.stateDescription)
                            .font(.claritySubtitle)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    
                    // Component breakdown
                    VStack(spacing: 16) {
                        Text("Score Breakdown")
                            .font(.clarityTitle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ScoreComponentRow(title: "Tasks", score: score.taskScore, weight: 30, color: .clarityBlue)
                        ScoreComponentRow(title: "Habits", score: score.habitScore, weight: 25, color: .clarityOrange)
                        ScoreComponentRow(title: "Mood", score: score.moodScore, weight: 20, color: .clarityPink)
                        ScoreComponentRow(title: "Moments", score: score.momentScore, weight: 15, color: .clarityTeal)
                        ScoreComponentRow(title: "Finance", score: score.financeScore, weight: 10, color: .clarityPurple)
                    }
                    .padding()
                    .background(Color.clarityCard)
                    .cornerRadius(16)
                    
                    // Explanation
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How it works")
                            .font(.clarityTitle)
                        
                        Text("Your Clarity Score reflects how aligned your life is with your intentions. It's calculated from your weekly activity across five key areas.")
                            .font(.clarityBody)
                            .foregroundStyle(.secondary)
                        
                        Text("Higher scores mean greater awareness and consistency - not perfection.")
                            .font(.clarityCallout)
                            .foregroundStyle(.primary)
                    }
                    .padding()
                }
                .padding()
            }
            .background(Color.clarityBackground.ignoresSafeArea())
            .navigationTitle("Score Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Score Component Row
struct ScoreComponentRow: View {
    let title: String
    let score: Double
    let weight: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.clarityCallout)
                
                Spacer()
                
                Text("\(Int(score))")
                    .font(.clarityTitle)
                    .foregroundStyle(color)
                
                Text("(\(weight)%)")
                    .font(.clarityCaption)
                    .foregroundStyle(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.gradient)
                        .frame(width: geo.size.width * (score / 100), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    let mockScore = ClarityScore(
        taskScore: 85,
        habitScore: 72,
        moodScore: 68,
        momentScore: 55,
        financeScore: 80
    )
    
    ClarityScoreCard(score: mockScore)
        .padding()
}
