import SwiftUI
import SwiftData
import Charts

// MARK: - Quick Add Transaction View
struct QuickAddTransactionView: View {
    @Binding var showAdd: Bool
    @Binding var prefillAmount: Double
    @Binding var prefillCategory: TransactionCategory
    @Binding var prefillNote: String
    
    let presets = [
        ("☕", "Coffee", TransactionCategory.food),
        ("🍔", "Lunch", TransactionCategory.food),
        ("⛽", "Gas", TransactionCategory.transport),
        ("🛒", "Groceries", TransactionCategory.food),
        ("🎬", "Movie", TransactionCategory.entertainment),
        ("💊", "Pharmacy", TransactionCategory.bills),
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Add")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(presets, id: \.1) { preset in
                        QuickAddButton(
                            emoji: preset.0,
                            title: preset.1,
                            category: preset.2
                        ) {
                            prefillAmount = 0.0
                            prefillCategory = preset.2
                            prefillNote = preset.1
                            showAdd = true
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.horizontal, -12) // Break out of parent padding
        }
    }
}

struct QuickAddButton: View {
    let emoji: String
    let title: String
    let category: TransactionCategory
    let onAdd: () -> Void
    
    var body: some View {
        Button(action: onAdd) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 32))
                
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }
            .frame(width: 80, height: 80)
            .background(Color.clarityCard)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Suggested Transactions View
struct SuggestedTransactionsView: View {
    @Environment(\.modelContext) private var context
    @Query private var recentTransactions: [Transaction]
    
    @Binding var showAdd: Bool
    @Binding var prefillAmount: Double
    @Binding var prefillCategory: TransactionCategory
    @Binding var prefillNote: String
    
    let userEmail: String
    
    init(showAdd: Binding<Bool>, prefillAmount: Binding<Double>, prefillCategory: Binding<TransactionCategory>, prefillNote: Binding<String>, userEmail: String) {
        self._showAdd = showAdd
        self._prefillAmount = prefillAmount
        self._prefillCategory = prefillCategory
        self._prefillNote = prefillNote
        self.userEmail = userEmail
        
        // Query recent transactions (last 30 days)
        let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        _recentTransactions = Query(filter: #Predicate<Transaction> { 
            $0.ownerEmail == userEmail && $0.date >= monthAgo 
        })
    }
    
    /// Build context from user's transaction history
    var suggestionContext: SuggestionEngine.UserContextData {
        var context = SuggestionEngine.UserContextData()
        
        // Calculate spending by category
        let grouped = Dictionary(grouping: recentTransactions) { $0.category }
        context.spendingByCategory = grouped.mapValues { transactions in
            transactions.reduce(0) { $0 + $1.amount }
        }
        
        // Calculate average transaction amount
        if !recentTransactions.isEmpty {
            context.averageTransactionAmount = recentTransactions.reduce(0) { $0 + $1.amount } / Double(recentTransactions.count)
        }
        
        return context
    }
    
    /// Dynamic suggestions from engine
    var suggestions: [SuggestionEngine.FinanceSuggestion] {
        SuggestionEngine.shared.generateFinanceSuggestions(context: suggestionContext)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                if recentTransactions.isEmpty {
                    Text("No transactions yet")
                        .font(.title2.bold())
                    Text("Track your spending by adding common expenses")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Quick Add")
                        .font(.title2.bold())
                    Text(headerSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestions) { suggestion in
                        SuggestedTransactionCard(
                            emoji: suggestion.emoji,
                            title: suggestion.title,
                            amount: suggestion.amount,
                            category: suggestion.category,
                            reason: suggestion.reason
                        ) {
                            prefillAmount = suggestion.amount
                            prefillCategory = suggestion.category
                            prefillNote = suggestion.title
                            showAdd = true
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.horizontal, -12) // Break out of parent padding
        }
        .padding(.vertical)
    }
    
    private var headerSubtitle: String {
        let day = Calendar.current.component(.day, from: Date())
        if day <= 5 {
            return "Start of month - don't forget bills!"
        } else if day >= 25 {
            return "End of month - review your spending"
        } else {
            return "Based on your spending patterns"
        }
    }
}

struct SuggestedTransactionCard: View {
    let emoji: String
    let title: String
    let amount: Double
    let category: TransactionCategory
    let reason: String?
    let onTap: () -> Void
    
    init(emoji: String, title: String, amount: Double, category: TransactionCategory, reason: String? = nil, onTap: @escaping () -> Void) {
        self.emoji = emoji
        self.title = title
        self.amount = amount
        self.category = category
        self.reason = reason
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 32))
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    if amount > 0 {
                        Text("$\(amount, specifier: "%.0f")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if let reason = reason {
                        Text(reason)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Image(systemName: "plus.circle.fill")
                    .font(.body)
                    .foregroundStyle(Color.clarityOrange)
            }
            .frame(width: 110, height: 130)
            .background(Color.clarityCard)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Spending Breakdown Card
struct SpendingBreakdownCard: View {
    let transactions: [Transaction]
    
    var categoryTotals: [(category: TransactionCategory, amount: Double, percentage: Double)] {
        let grouped = Dictionary(grouping: transactions) { $0.category }
        let totals = grouped.mapValues { $0.reduce(0) { $0 + $1.amount } }
        let grandTotal = totals.values.reduce(0, +)
        
        return totals.map { (category: $0.key, amount: $0.value, percentage: grandTotal > 0 ? ($0.value / grandTotal) * 100 : 0) }
            .sorted { $0.amount > $1.amount }
    }
    
    var totalSpent: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spending Breakdown")
                        .font(.headline)
                    Text("This week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("$\(totalSpent, specifier: "%.2f")")
                    .font(.title2.bold())
                    .foregroundStyle(Color.clarityOrange)
            }
            
            if categoryTotals.isEmpty {
                Text("No spending tracked yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                HStack(spacing: 20) {
                    // Pie Chart
                    Chart(categoryTotals, id: \.category) { item in
                        SectorMark(
                            angle: .value("Amount", item.amount),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(categoryColor(item.category).gradient)
                    }
                    .frame(width: 120, height: 120)
                    
                    // Legend
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(categoryTotals.prefix(5), id: \.category) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(categoryColor(item.category))
                                    .frame(width: 10, height: 10)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.category.rawValue.capitalized)
                                        .font(.caption.bold())
                                    Text("$\(item.amount, specifier: "%.0f")")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("\(item.percentage, specifier: "%.0f")%")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.clarityCard)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private func categoryIcon(_ category: TransactionCategory) -> String {
        switch category {
        case .food: return "🍔"
        case .shopping: return "🛍️"
        case .bills: return "💡"
        case .transport: return "🚗"
        case .entertainment: return "🎬"
        case .other: return "💰"
        }
    }
    
    private func categoryColor(_ category: TransactionCategory) -> Color {
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
