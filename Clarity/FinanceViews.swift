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
                .padding(.horizontal)
            }
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
    @Binding var showAdd: Bool
    @Binding var prefillAmount: Double
    @Binding var prefillCategory: TransactionCategory
    @Binding var prefillNote: String
    
    let suggestions = [
        ("☕", "Coffee", 5.0, TransactionCategory.food),
        ("🍔", "Lunch", 12.0, TransactionCategory.food),
        ("⛽", "Gas", 40.0, TransactionCategory.transport),
        ("🛒", "Groceries", 60.0, TransactionCategory.food),
        ("🎬", "Entertainment", 20.0, TransactionCategory.entertainment),
        ("💡", "Bills", 50.0, TransactionCategory.bills),
        ("🛍️", "Shopping", 30.0, TransactionCategory.shopping),
        ("🚕", "Transport", 15.0, TransactionCategory.transport),
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("No transactions yet")
                    .font(.title2.bold())
                Text("Track your spending by adding common expenses")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestions, id: \.1) { suggestion in
                        SuggestedTransactionCard(
                            emoji: suggestion.0,
                            title: suggestion.1,
                            amount: suggestion.2,
                            category: suggestion.3
                        ) {
                            prefillAmount = suggestion.2
                            prefillCategory = suggestion.3
                            prefillNote = suggestion.1
                            showAdd = true
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

struct SuggestedTransactionCard: View {
    let emoji: String
    let title: String
    let amount: Double
    let category: TransactionCategory
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Text(emoji)
                    .font(.system(size: 32))
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text("$\(amount, specifier: "%.0f")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
