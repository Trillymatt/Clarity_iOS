import SwiftUI
import SwiftData

struct BudgetRow: View {
    let budget: Budget
    let spent: Double
    
    var progress: Double {
        guard budget.limit > 0 else { return 0 }
        return spent / budget.limit
    }
    
    var color: Color {
        if progress >= 1.0 { return .red }
        if progress >= 0.8 { return .clarityOrange }
        return .green
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Icon based on category
                Image(systemName: iconFor(budget.category))
                    .foregroundStyle(Color.clarityPurple)
                    .frame(width: 32, height: 32)
                    .background(Color.clarityPurple.opacity(0.1))
                    .clipShape(Circle())
                
                Text(budget.categoryRaw.capitalized)
                    .font(.headline)
                
                Spacer()
                
                Text("$\(Int(budget.limit - spent)) left")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: min(CGFloat(progress) * geometry.size.width, geometry.size.width), height: 8)
                }
            }
            .frame(height: 8)
            
            HStack {
                Text("$\(Int(spent)) spent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("$\(Int(budget.limit)) limit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.clarityCard)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    func iconFor(_ category: TransactionCategory) -> String {
        switch category {
        case .food: return "fork.knife"
        case .shopping: return "bag.fill"
        case .bills: return "doc.text.fill"
        case .transport: return "car.fill"
        case .entertainment: return "tv.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

struct EditBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var budgets: [Budget]
    
    @State private var limits: [TransactionCategory: Double] = [:]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Monthly Limits") {
                    ForEach(TransactionCategory.allCases) { category in
                        HStack {
                            Text(category.rawValue.capitalized)
                            Spacer()
                            TextField("Limit", value: Binding(
                                get: { limits[category] ?? 0 },
                                set: { limits[category] = $0 }
                            ), format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .navigationTitle("Set Budgets")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBudgets()
                    }
                }
            }
            .onAppear {
                // Load existing budgets
                for budget in budgets {
                    limits[budget.category] = budget.limit
                }
            }
        }
    }
    
    private func saveBudgets() {
        for (category, limit) in limits {
            if let existing = budgets.first(where: { $0.category == category }) {
                existing.limit = limit
            } else if limit > 0 {
                let newBudget = Budget(category: category, limit: limit)
                context.insert(newBudget)
            }
        }
        try? context.save()
        dismiss()
    }
}
