import SwiftUI
import SwiftData

// MARK: - Enhanced Moments Tab
struct EnhancedMomentsTab: View {
    @Environment(\.modelContext) private var context
    let userEmail: String
    @Query private var moments: [LifeMoment]
    @Query private var moodEntries: [MoodEntry]
    
    init(userEmail: String) {
        self.userEmail = userEmail
        _moments = Query(filter: #Predicate { $0.ownerEmail == userEmail }, sort: \LifeMoment.date, order: .reverse)
        _moodEntries = Query(filter: #Predicate { $0.ownerEmail == userEmail })
    }
    
    @State private var showAdd = false
    @State private var prefillTitle = ""
    
    // MARK: - Computed Properties
    
    var latestMoment: LifeMoment? {
        moments.first
    }
    
    var otherMoments: [LifeMoment] {
        Array(moments.dropFirst())
    }
    
    var momentScore: Double {
        ClarityScoreCalculator.calculateMomentScore(moments: moments)
    }
    
    var scoreInsight: String {
        switch momentScore {
        case 80...: return "Deeply reflective"
        case 60..<80: return "Consistent journaling"
        case 40..<60: return "Capturing memories"
        default: return "Start your story"
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Header & Score
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(Date(), format: .dateTime.weekday(.wide).day().month())
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                
                                Text("Moments")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                
                                Text(scoreInsight)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.clarityTeal)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.clarityTeal.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            
                            Spacer()
                            
                            MomentScoreRing(score: momentScore)
                        }
                        .padding(.top, 10)
                        
                        // Mood Trend (if available)
                        if !moodEntries.isEmpty {
                            MoodTrendMiniChart(moodEntries: moodEntries)
                        }
                        
                        // Latest Moment Card
                            if let latest = latestMoment {
                                VStack(alignment: .leading, spacing: 16) {
                                    Label("Latest Reflection", systemImage: "sparkles")
                                        .font(.headline)
                                        .foregroundStyle(Color.clarityTeal)
                                        .padding(.horizontal)
                                    
                                    LatestMomentCard(moment: latest)
                                }
                            }
                            
                            // Timeline
                            if !otherMoments.isEmpty {
                                VStack(alignment: .leading, spacing: 20) {
                                    Text("Timeline")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                    
                                    ForEach(groupedByDay(moments: otherMoments), id: \.key) { day, items in
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text(day, style: .date)
                                                .font(.caption.bold())
                                                .foregroundStyle(.secondary)
                                            
                                            ForEach(items) { moment in
                                                EnhancedMomentRow(moment: moment)
                                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                        Button(role: .destructive) {
                                                            context.delete(moment)
                                                            try? context.save()
                                                        } label: {
                                                            Label("Delete", systemImage: "trash")
                                                        }
                                                    }
                                            }
                                        }
                                    }
                                }
                            }
                        
                        // Suggestions (always show)
                        SuggestedMomentsView(showAdd: $showAdd, prefillTitle: $prefillTitle, userEmail: userEmail)
                        
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom)
                }
            }
            .navigationTitle("")
            .toolbar(.hidden)
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(LinearGradient.clarityPrimary)
                        .clipShape(Circle())
                        .shadow(color: Color.clarityPurple.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .padding()
            }
            .sheet(isPresented: $showAdd) {
                AddMomentSheet(userEmail: userEmail, prefillTitle: prefillTitle)
            }
            .onChange(of: showAdd) { _, newValue in
                if !newValue { prefillTitle = "" }
            }
        }
    }
    
    private func groupedByDay(moments: [LifeMoment]) -> [(key: Date, value: [LifeMoment])] {
        let groups = Dictionary(grouping: moments) { Calendar.current.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { $0.date > $1.date }) }
    }
}

// MARK: - Subviews

struct MomentScoreRing: View {
    let score: Double
    
    var contribution: Int {
        Int(score * ClarityScoreCalculator.momentWeight)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.clarityCard, lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(
                        LinearGradient(colors: [.clarityTeal, .clarityBlue], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.8), value: score)
                
                VStack(spacing: 0) {
                    Text("\(Int(score))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Score")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }
            .frame(width: 80, height: 80)
            
            Text("+\(contribution) pts")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.clarityCard)
                .clipShape(Capsule())
        }
    }
}

struct LatestMomentCard: View {
    let moment: LifeMoment
    @State private var showEdit = false
    
    var moodEmoji: String {
        guard let score = moment.moodScore else { return "💭" }
        switch score {
        case 0..<0.2: return "😢"
        case 0.2..<0.4: return "😕"
        case 0.4..<0.6: return "😐"
        case 0.6..<0.8: return "🙂"
        default: return "😄"
        }
    }
    
    var body: some View {
        Button(action: { showEdit = true }) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    Text(moodEmoji)
                        .font(.system(size: 48))
                        .frame(width: 64, height: 64)
                        .background(Color.clarityTeal.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(moment.title)
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        
                        Text(moment.date, style: .time)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let note = moment.note, !note.isEmpty {
                    Text(note)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.top, 4)
                }
            }
            .padding(20)
            .background(Color.clarityCard)
            .cornerRadius(20)
            .shadow(color: Color.clarityTeal.opacity(0.1), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.clarityTeal.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEdit) {
            AddMomentSheet(userEmail: moment.ownerEmail, momentToEdit: moment)
        }
    }
}

struct EnhancedMomentRow: View {
    let moment: LifeMoment
    @State private var showEdit = false
    
    var moodEmoji: String {
        guard let score = moment.moodScore else { return "💭" }
        switch score {
        case 0..<0.2: return "😢"
        case 0.2..<0.4: return "😕"
        case 0.4..<0.6: return "😐"
        case 0.6..<0.8: return "🙂"
        default: return "😄"
        }
    }
    
    var body: some View {
        Button(action: { showEdit = true }) {
            HStack(spacing: 16) {
                Text(moodEmoji)
                    .font(.system(size: 32))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(moment.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    if let note = moment.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Text(moment.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.clarityCard)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEdit) {
            AddMomentSheet(userEmail: moment.ownerEmail, momentToEdit: moment)
        }
    }
}

// Keep MoodTrendMiniChart as is
struct MoodTrendMiniChart: View {
    let moodEntries: [MoodEntry]
    
    var weeklyMoods: [MoodEntry] {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date()))!
        return moodEntries.filter { $0.date >= weekStart }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mood Trend")
                    .font(.headline)
                Spacer()
                Text("This Week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 8) {
                ForEach(weeklyMoods) { entry in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient.clarityPrimary)
                            .frame(width: 30, height: CGFloat(entry.moodScore * 80))
                        
                        Text(entry.emotion)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: 30)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.clarityCard)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
