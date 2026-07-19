import SwiftUI
import SwiftData

// MARK: - Global Search
// One search box across everything instead of hunting through four
// different domain screens.

struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    let userEmail: String

    @Query private var tasks: [TaskItem]
    @Query private var habits: [Habit]
    @Query private var moments: [LifeMoment]
    @Query private var transactions: [Transaction]

    @State private var query = ""
    @State private var editingTask: TaskItem?
    @State private var editingHabit: Habit?
    @State private var editingMoment: LifeMoment?
    @State private var editingTransaction: Transaction?

    init(userEmail: String) {
        self.userEmail = userEmail
        _tasks = Query(filter: #Predicate { $0.ownerEmail == userEmail })
        _habits = Query(filter: #Predicate { $0.ownerEmail == userEmail })
        _moments = Query(filter: #Predicate { $0.ownerEmail == userEmail })
        _transactions = Query(filter: #Predicate { $0.ownerEmail == userEmail })
    }

    private var matchedTasks: [TaskItem] {
        guard !query.isEmpty else { return [] }
        return tasks.filter { $0.title.localizedCaseInsensitiveContains(query) || ($0.notes ?? "").localizedCaseInsensitiveContains(query) }
    }

    private var matchedHabits: [Habit] {
        guard !query.isEmpty else { return [] }
        return habits.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var matchedMoments: [LifeMoment] {
        guard !query.isEmpty else { return [] }
        return moments.filter { $0.title.localizedCaseInsensitiveContains(query) || ($0.note ?? "").localizedCaseInsensitiveContains(query) }
    }

    private var matchedTransactions: [Transaction] {
        guard !query.isEmpty else { return [] }
        return transactions.filter { ($0.note ?? "").localizedCaseInsensitiveContains(query) || $0.category.rawValue.localizedCaseInsensitiveContains(query) }
    }

    private var hasAnyResults: Bool {
        !matchedTasks.isEmpty || !matchedHabits.isEmpty || !matchedMoments.isEmpty || !matchedTransactions.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()

                if query.isEmpty {
                    ContentUnavailableView("Search Everything", systemImage: "magnifyingglass", description: Text("Tasks, habits, moments, and transactions — all in one place."))
                } else if !hasAnyResults {
                    ContentUnavailableView.search(text: query)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            resultSection(title: "Tasks", count: matchedTasks.count) {
                                ForEach(matchedTasks.prefix(10)) { task in
                                    Button(action: { editingTask = task }) {
                                        resultRow(icon: "checkmark.circle.fill", color: .clarityBlue, title: task.title, subtitle: task.category.rawValue.capitalized)
                                    }
                                }
                            }

                            resultSection(title: "Habits", count: matchedHabits.count) {
                                ForEach(matchedHabits.prefix(10)) { habit in
                                    Button(action: { editingHabit = habit }) {
                                        resultRow(icon: "repeat.circle.fill", color: .clarityOrange, title: habit.name, subtitle: habit.isActive ? "Active" : "Inactive")
                                    }
                                }
                            }

                            resultSection(title: "Moments", count: matchedMoments.count) {
                                ForEach(matchedMoments.prefix(10)) { moment in
                                    Button(action: { editingMoment = moment }) {
                                        resultRow(icon: "sparkles", color: .clarityPink, title: moment.title, subtitle: moment.date.formatted(date: .abbreviated, time: .omitted))
                                    }
                                }
                            }

                            resultSection(title: "Transactions", count: matchedTransactions.count) {
                                ForEach(matchedTransactions.prefix(10)) { txn in
                                    Button(action: { editingTransaction = txn }) {
                                        resultRow(icon: "dollarsign.circle.fill", color: .clarityPurple, title: txn.note?.isEmpty == false ? txn.note! : txn.category.rawValue.capitalized, subtitle: String(format: "$%.2f", txn.amount))
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search tasks, habits, moments, money…")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: $editingTask) { task in
                EditTaskSheet(task: task)
            }
            .sheet(item: $editingHabit) { habit in
                AddHabitSheet(userEmail: userEmail, habitToEdit: habit)
            }
            .sheet(item: $editingMoment) { moment in
                AddMomentSheet(userEmail: userEmail, momentToEdit: moment)
            }
            .sheet(item: $editingTransaction) { txn in
                EditTransactionSheet(transaction: txn)
            }
        }
    }

    @ViewBuilder
    private func resultSection<Content: View>(title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        if count > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(title) (\(count))")
                    .font(.clarityCaptionBold)
                    .foregroundStyle(.secondary)
                VStack(spacing: 8) {
                    content()
                }
            }
        }
    }

    private func resultRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.clarityCallout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
