import SwiftUI
import SwiftData
import Charts

// MARK: - Enhanced Finance Tab
struct EnhancedFinanceTab: View {
    @Environment(\.modelContext) private var context
    let userEmail: String
    @Query private var transactions: [Transaction]
    @Query private var budgets: [Budget]

    init(userEmail: String) {
        self.userEmail = userEmail
        _transactions = Query(filter: #Predicate { $0.ownerEmail == userEmail }, sort: \Transaction.date, order: .reverse)
        _budgets = Query(filter: #Predicate<Budget> { $0.ownerEmail == userEmail })
    }

    @State private var showAdd = false
    @State private var showEditBudgets = false
    @State private var prefillAmount: Double = 0
    @State private var prefillCategory: TransactionCategory = .other
    @State private var prefillNote: String = ""

    private var monthSpending: [TransactionCategory: Double] {
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
        let monthTransactions = transactions.filter { $0.date >= monthStart }
        return Dictionary(grouping: monthTransactions, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }

    private var recurringCharges: [DetectedRecurringCharge] {
        RecurringTransactionDetector.detect(transactions: transactions)
    }
    
    // MARK: - Computed Properties
    
    var financeScore: Double {
        ClarityScoreCalculator.calculateFinanceScore(transactions: transactions)
    }
    
    var scoreInsight: String {
        switch financeScore {
        case 80...: return "Financial master!"
        case 60..<80: return "Great awareness"
        case 40..<60: return "Building habits"
        default: return "Start tracking"
        }
    }
    
    var weeklySpending: Double {
        let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        return transactions.filter { $0.date >= weekStart }.reduce(0) { $0 + $1.amount }
    }
    
    var spendingByCategory: [(category: TransactionCategory, amount: Double)] {
        let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        let weekTransactions = transactions.filter { $0.date >= weekStart }
        let grouped = Dictionary(grouping: weekTransactions) { $0.category }
        return grouped.map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Spacer for nav bar
                        Color.clear.frame(height: 90)
                        // Header & Score
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Finance")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                
                                Text(scoreInsight)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.clarityPurple)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.clarityPurple.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            
                            Spacer()
                            
                            FinanceScoreRing(score: financeScore)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        
                        // Weekly Awareness (Primary Focus)
                        WeeklyAwarenessCard(
                            totalSpent: weeklySpending,
                            transactionCount: transactions.filter {
                                $0.date >= Calendar.current.date(byAdding: .day, value: -6, to: Date())!
                            }.count
                        )
                        .padding(.horizontal, 12)
                        
                        // Category Breakdown
                        if !spendingByCategory.isEmpty {
                            CategoryBreakdownCard(categoryData: spendingByCategory)
                                .padding(.horizontal, 12)
                        }

                        // Budgets
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Budgets")
                                    .font(.headline)
                                Spacer()
                                Button(action: { showEditBudgets = true }) {
                                    Text(budgets.isEmpty ? "Set Budgets" : "Edit")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(Color.clarityBlue)
                                }
                            }

                            if budgets.isEmpty {
                                SoftCard {
                                    Text("Set monthly limits per category and Jarvis will flag it when you're close.")
                                        .font(.clarityCallout)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(budgets.sorted { $0.categoryRaw < $1.categoryRaw }) { budget in
                                        BudgetRow(budget: budget, spent: monthSpending[budget.category] ?? 0)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)

                        // Subscriptions & Bills (auto-detected)
                        if !recurringCharges.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Subscriptions & Bills")
                                    .font(.headline)
                                Text("Detected from repeating charges — confirm to stop seeing this prompt.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                VStack(spacing: 12) {
                                    ForEach(recurringCharges) { charge in
                                        RecurringChargeRow(charge: charge) {
                                            markRecurring(charge)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                        }

                        if transactions.isEmpty {
                            SuggestedTransactionsView(
                                showAdd: $showAdd,
                                prefillAmount: $prefillAmount,
                                prefillCategory: $prefillCategory,
                                prefillNote: $prefillNote,
                                userEmail: userEmail
                            )
                            .padding(.horizontal, 12)
                        } else {
                            QuickAddTransactionView(
                                showAdd: $showAdd,
                                prefillAmount: $prefillAmount,
                                prefillCategory: $prefillCategory,
                                prefillNote: $prefillNote
                            )
                            .padding(.horizontal, 12)
                        }
                        
                        // Recent Transactions
                        if !transactions.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Recent Activity")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                                
                                ForEach(transactions.prefix(10)) { transaction in
                                    EnhancedTransactionRow(transaction: transaction)
                                        .padding(.horizontal, 12)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                context.delete(transaction)
                                                try? context.save()
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                        
                        Spacer(minLength: 80)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                AddTransactionSheet(
                    userEmail: userEmail,
                    prefillAmount: prefillAmount,
                    prefillCategory: prefillCategory,
                    prefillNote: prefillNote
                )
            }
            .sheet(isPresented: $showEditBudgets) {
                EditBudgetSheet(userEmail: userEmail)
            }
        }
    }

    private func markRecurring(_ charge: DetectedRecurringCharge) {
        let matches = transactions.filter { charge.transactionIDs.contains($0.id) }
        matches.forEach { $0.isRecurring = true }
        try? context.save()
    }
}

// MARK: - Recurring Charge Row

struct RecurringChargeRow: View {
    let charge: DetectedRecurringCharge
    var onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(charge.note.isEmpty ? charge.category.rawValue.capitalized : charge.note)
                    .font(.body.weight(.medium))
                Text("~$\(String(format: "%.2f", charge.averageAmount))/mo · next ~\(charge.nextExpectedDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onConfirm) {
                Text("Confirm")
                    .font(.caption.bold())
                    .foregroundStyle(Color.clarityTeal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.clarityTeal.opacity(0.15), in: Capsule())
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Subviews

struct FinanceScoreRing: View {
    let score: Double
    
    var contribution: Int {
        Int(score * ClarityScoreCalculator.financeWeight)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.clarityCard, lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(
                        LinearGradient(colors: [.clarityPurple, .clarityBlue], startPoint: .top, endPoint: .bottom),
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

struct WeeklyAwarenessCard: View {
    let totalSpent: Double
    let transactionCount: Int
    
    var awarenessPercentage: Double {
        min(1.0, Double(transactionCount) / 49.0)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.clarityPurple.opacity(0.1), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: awarenessPercentage)
                    .stroke(Color.clarityPurple, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: "eye.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.clarityPurple)
            }
            .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Weekly Awareness")
                    .font(.subheadline.bold())
                Text("\(transactionCount) transactions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("$\(totalSpent, specifier: "%.2f")")
                .font(.headline)
                .foregroundStyle(Color.clarityPurple)
        }
        .padding(12)
        .background(Color.clarityCard)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
}

struct CategoryBreakdownCard: View {
    let categoryData: [(category: TransactionCategory, amount: Double)]
    
    var totalSpending: Double {
        categoryData.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending by Category")
                .font(.headline)
            
            ForEach(categoryData.prefix(5), id: \.category) { item in
                HStack {
                    Circle()
                        .fill(colorForCategory(item.category))
                        .frame(width: 12, height: 12)
                    
                    Text(item.category.rawValue.capitalized)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("$\(item.amount, specifier: "%.0f")")
                        .font(.subheadline.bold())
                    
                    Text("(\(Int((item.amount / totalSpending) * 100))%)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorForCategory(item.category).gradient)
                        .frame(width: geo.size.width * (item.amount / totalSpending), height: 6)
                }
                .frame(height: 6)
            }
        }
        .padding()
        .background(Color.clarityCard)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private func colorForCategory(_ category: TransactionCategory) -> Color {
        switch category {
        case .food: return .clarityOrange
        case .shopping: return .clarityPink
        case .bills: return .clarityPurple
        case .transport: return .clarityBlue
        case .entertainment: return .clarityTeal
        case .other: return .secondary
        }
    }
}

struct EnhancedTransactionRow: View {
    let transaction: Transaction
    @State private var showEdit = false
    
    var categoryIcon: String {
        switch transaction.category {
        case .food: return "🍔"
        case .shopping: return "🛍️"
        case .bills: return "💡"
        case .transport: return "🚗"
        case .entertainment: return "🎬"
        case .other: return "💰"
        }
    }
    
    var body: some View {
        Button(action: { showEdit = true }) {
            HStack(spacing: 12) {
                Text(categoryIcon)
                    .font(.system(size: 32))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.note ?? transaction.category.rawValue.capitalized)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    Text(transaction.date, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("$\(transaction.amount, specifier: "%.2f")")
                    .font(.headline)
                    .foregroundStyle(Color.clarityOrange)
            }
            .padding()
            .background(Color.clarityCard)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEdit) {
            EditTransactionSheet(transaction: transaction)
        }
    }
}
