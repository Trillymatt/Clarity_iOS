import SwiftUI
import SwiftData

// MARK: - Trend History View
// The Life Pulse graph only ever showed 7 days. This adds Month/Year ranges
// on top of the same generator and chart, reached from the dashboard.

struct TrendHistoryView: View {
    let userEmail: String

    @Query private var tasks: [TaskItem]
    @Query private var habits: [Habit]
    @Query private var checkins: [HabitCheckin]
    @Query private var moodEntries: [MoodEntry]
    @Query private var moments: [LifeMoment]
    @Query private var transactions: [Transaction]

    @State private var range: Range = .week

    enum Range: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        var id: String { rawValue }

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .year: return 364
            }
        }

        var strideBy: Int {
            switch self {
            case .week, .month: return 1
            case .year: return 7
            }
        }
    }

    init(userEmail: String) {
        self.userEmail = userEmail
        _tasks = Query(filter: #Predicate { $0.ownerEmail == userEmail })
        _habits = Query(filter: #Predicate { $0.ownerEmail == userEmail })
        _checkins = Query(filter: #Predicate { $0.ownerEmail == userEmail })
        _moodEntries = Query(filter: #Predicate { $0.ownerEmail == userEmail })
        _moments = Query(filter: #Predicate { $0.ownerEmail == userEmail })
        _transactions = Query(filter: #Predicate { $0.ownerEmail == userEmail })
    }

    private var pulseData: [LifePulseDataPoint] {
        LifePulseDataGenerator.generateData(
            days: range.days,
            strideBy: range.strideBy,
            tasks: tasks,
            checkins: checkins,
            habits: habits,
            moodEntries: moodEntries,
            moments: moments,
            transactions: transactions
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Picker("Range", selection: $range) {
                        ForEach(Range.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if pulseData.isEmpty {
                        SoftCard {
                            Text("No activity in this range yet.")
                                .font(.clarityCallout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)
                    } else {
                        LifePulseGraph(pulseData: pulseData)
                            .padding(.horizontal)

                        summaryCard
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .background(Color.clarityBackground.ignoresSafeArea())
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var summaryCard: some View {
        let scores = pulseData.map(\.clarityScore)
        let avg = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
        let best = scores.max() ?? 0
        let totalCompletions = pulseData.reduce(0) { $0 + $1.taskCount + $1.habitCount }

        return SoftCard {
            HStack(spacing: 24) {
                summaryStat(value: "\(Int(avg))", label: "Avg Score")
                summaryStat(value: "\(Int(best))", label: "Best Day")
                summaryStat(value: "\(totalCompletions)", label: "Completions")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func summaryStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.clarityPurple)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
