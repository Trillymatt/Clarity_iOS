import SwiftUI
import SwiftData

struct WeeklyClarityArchiveView: View {
    let userEmail: String
    @Query(sort: \WeeklyReview.date, order: .reverse) private var weeklyReviews: [WeeklyReview]
    
    init(userEmail: String) {
        self.userEmail = userEmail
        _weeklyReviews = Query(filter: #Predicate { $0.ownerEmail == userEmail }, sort: \WeeklyReview.date, order: .reverse)
    }
    
    var body: some View {
        List {
            if weeklyReviews.isEmpty {
                ContentUnavailableView(
                    "No Reviews Yet",
                    systemImage: "sparkles.rectangle.stack",
                    description: Text("Complete your first weekly review to see it here.")
                )
            } else {
                ForEach(weeklyReviews) { review in
                    NavigationLink {
                        WeeklyReviewDetailView(review: review)
                    } label: {
                        WeeklyReviewRow(review: review)
                    }
                }
            }
        }
        .navigationTitle("Weekly Clarity")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Review Row
struct WeeklyReviewRow: View {
    let review: WeeklyReview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(review.date, format: .dateTime.month().day().year())
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                    Text("\(review.weekRating)/5")
                }
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(LinearGradient.clarityPrimary)
                .cornerRadius(8)
            }
            
            if !review.wins.isEmpty {
                Text(review.wins)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 12) {
                Label("\(review.habitAdherence)/5", systemImage: "repeat.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Review Detail View
struct WeeklyReviewDetailView: View {
    let review: WeeklyReview
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(review.date, format: .dateTime.weekday(.wide).month().day().year())
                        .font(.title2.bold())
                    
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                        Text("Week Rating: \(review.weekRating)/5")
                    }
                    .font(.headline)
                    .foregroundStyle(Color.clarityPurple)
                }
                
                Divider()
                
                // Ratings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ratings")
                        .font(.headline)
                    
                    HStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text("⭐")
                                .font(.title)
                            Text("Week")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(review.weekRating)/5")
                                .font(.headline)
                        }
                        
                        VStack(spacing: 4) {
                            Text("🔄")
                                .font(.title)
                            Text("Habits")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(review.habitAdherence)/5")
                                .font(.headline)
                        }
                    }
                }
                
                // Wins
                if !review.wins.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wins & Accomplishments")
                            .font(.headline)
                        Text(review.wins)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Challenges
                if !review.challenges.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Challenges")
                            .font(.headline)
                        Text(review.challenges)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Learnings
                if !review.learnings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lessons Learned")
                            .font(.headline)
                        Text(review.learnings)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Focus
                if !review.mainFocus.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Main Focus")
                            .font(.headline)
                        Text(review.mainFocus)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Goals
                if !review.topGoals.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Goals")
                            .font(.headline)
                        ForEach(review.topGoals, id: \.self) { goal in
                            HStack(spacing: 8) {
                                Image(systemName: "target")
                                    .foregroundStyle(Color.clarityBlue)
                                Text(goal)
                            }
                            .font(.body)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(Color.clarityBackground)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        WeeklyClarityArchiveView(userEmail: "test@example.com")
            .modelContainer(for: WeeklyReview.self)
    }
}
