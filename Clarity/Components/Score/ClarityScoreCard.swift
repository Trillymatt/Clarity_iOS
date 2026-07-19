import SwiftUI

// MARK: - Clarity Score Card
// The signature hero component displaying the user's Clarity Score

struct ClarityScoreCard: View {
    let score: ClarityScore
    @State private var animateScore = false
    @State private var showBreakdown = false
    
    var body: some View {
        Button(action: { showBreakdown = true }) {
            GradientCard(gradient: score.gradient) {
                VStack(spacing: 8) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clarity Score")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.9))
                            
                            Text(score.stateDescription)
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                        }
                        
                        Spacer()
                        
                        // Trend indicator
                        TrendIndicator(trend: score.trend)
                    }
                    
                    // Score display
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(Int(animateScore ? score.totalScore : 0))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                        
                        Text(score.stateEmoji)
                            .font(.system(size: 32))
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Micro insight
                    if let mainInsight = generateMainInsight() {
                        Text(mainInsight)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    
                    // Tap hint
                    HStack(spacing: 4) {
                        Text("Tap for breakdown")
                            .font(.caption2)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.vertical, 4)
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
                .font(.caption.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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
        case .up: return "Improving"
        case .neutral: return "Steady"
        case .down: return "Needs focus"
        }
    }
}

// MARK: - Score Breakdown View
struct ScoreBreakdownView: View {
    @Environment(\.dismiss) private var dismiss
    let score: ClarityScore
    @State private var animateChart = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Hero Section
                    VStack(spacing: 8) {
                        Text(score.stateEmoji)
                            .font(.system(size: 64))
                            .shadow(color: .clarityPurple.opacity(0.5), radius: 20, x: 0, y: 10)
                        
                        Text(score.stateDescription)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        Text("\(Int(score.totalScore)) / 100")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(20)
                    }
                    .padding(.top, 20)
                    
                    // Radar Chart Visualization
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(Color.clarityPurple.opacity(0.2))
                            .blur(radius: 40)
                            .frame(width: 250, height: 250)
                        
                        RadarChart(
                            data: [
                                score.taskScore,
                                score.habitScore,
                                score.moodScore,
                                score.momentScore,
                                score.financeScore,
                                score.fitnessScore
                            ],
                            labels: ["Tasks", "Habits", "Mood", "Moments", "Finance", "Fitness"],
                            colors: [.clarityBlue, .clarityOrange, .clarityPink, .clarityTeal, .clarityPurple, .clarityGreen]
                        )
                        .frame(width: 300, height: 300)
                    }
                    .padding(.vertical, 20)
                    
                    // Score Details Grid
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Breakdown")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ScoreDetailCard(
                                title: "Tasks",
                                score: score.taskScore,
                                icon: "checkmark.circle.fill",
                                color: .clarityBlue
                            )
                            
                            ScoreDetailCard(
                                title: "Habits",
                                score: score.habitScore,
                                icon: "repeat.circle.fill",
                                color: .clarityOrange
                            )
                            
                            ScoreDetailCard(
                                title: "Mood",
                                score: score.moodScore,
                                icon: "face.smiling.fill",
                                color: .clarityPink
                            )
                            
                            ScoreDetailCard(
                                title: "Moments",
                                score: score.momentScore,
                                icon: "camera.macro.circle.fill",
                                color: .clarityTeal
                            )
                            
                            ScoreDetailCard(
                                title: "Finance",
                                score: score.financeScore,
                                icon: "dollarsign.circle.fill",
                                color: .clarityPurple
                            )

                            ScoreDetailCard(
                                title: "Fitness",
                                score: score.fitnessScore,
                                icon: "figure.run.circle.fill",
                                color: .clarityGreen
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Insight Box
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.clarityPurple)
                            Text("Clarity Insight")
                                .font(.headline)
                        }
                        
                        Text(generateInsight())
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .cardStyle()
                    .padding(.horizontal)
                    
                    // What Moves This Up Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What moves this up?")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ImprovementRow(title: "Complete a task", points: "+4 points", icon: "checkmark.circle.fill", color: .clarityBlue)
                            ImprovementRow(title: "Complete a habit", points: "+2 points", icon: "repeat.circle.fill", color: .clarityOrange)
                            ImprovementRow(title: "Log your mood", points: "+5 points", icon: "face.smiling.fill", color: .clarityPink)
                            ImprovementRow(title: "Capture a moment", points: "+3 points", icon: "camera.macro.circle.fill", color: .clarityTeal)
                            ImprovementRow(title: "Log a transaction", points: "+3 points", icon: "dollarsign.circle.fill", color: .clarityPurple)
                            ImprovementRow(title: "Log a workout", points: "+8 points", icon: "figure.run.circle.fill", color: .clarityGreen)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 40)
                }
            }
            .background(Color.clarityBackground.ignoresSafeArea())
            .navigationTitle("Clarity Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
        }
    }
    
    private func generateInsight() -> String {
        // Simple logic to find lowest area and give encouragement
        let scores = [
            ("Tasks", score.taskScore),
            ("Habits", score.habitScore),
            ("Mood", score.moodScore),
            ("Moments", score.momentScore),
            ("Finance", score.financeScore),
            ("Fitness", score.fitnessScore)
        ]
        
        if let lowest = scores.min(by: { $0.1 < $1.1 }) {
            return "Your \(lowest.0.lowercased()) score is a bit lower this week (\(Int(lowest.1))). Try focusing on small wins in this area to boost your overall clarity."
        }
        
        return "You're doing great! Keep maintaining balance across all areas of your life."
    }
}

struct ImprovementRow: View {
    let title: String
    let points: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(points)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.clarityCard)
        .cornerRadius(12)
    }
}

// MARK: - Score Detail Card
struct ScoreDetailCard: View {
    let title: String
    let score: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Spacer()
                
                Text("\(Int(score))")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(color.opacity(0.2))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * (score / 100), height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding()
        .background(Color.clarityCard)
        .cornerRadius(16)
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
        .background(Color.black)
}
