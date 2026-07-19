import SwiftUI
import SwiftData

struct BudgetRow: View {
    let budget: Budget
    let spent: Double
    
    var progress: Double {
        guard budget.limit > 0 else { return 0 }
        return spent / budget.limit
    }
    
    var remaining: Double {
        budget.limit - spent
    }
    
    var color: Color {
        if progress >= 1.0 { return .red }
        if progress >= 0.8 { return .clarityOrange }
        return .green
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconFor(budget.category))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(colorFor(budget.category).gradient)
                .clipShape(Circle())
            
            // Middle: Name + Progress Bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(budget.categoryRaw.capitalized)
                        .font(.subheadline.weight(.medium))
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(color)
                            .frame(width: min(CGFloat(progress) * geometry.size.width, geometry.size.width), height: 6)
                    }
                }
                .frame(height: 6)
            }
            
            // Right: Money Stats
            VStack(alignment: .trailing, spacing: 2) {
                Text(remaining >= 0 ? "$\(Int(remaining))" : "-$\(Int(abs(remaining)))")
                    .font(.subheadline.bold())
                    .foregroundStyle(remaining >= 0 ? Color.primary : Color.red)
                
                Text("/ $\(Int(budget.limit))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 60, alignment: .trailing)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(color.opacity(0.25), lineWidth: 1))
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
    
    func colorFor(_ category: TransactionCategory) -> Color {
        switch category {
        case .food: return .clarityOrange
        case .shopping: return .clarityPink
        case .bills: return .clarityPurple
        case .transport: return .clarityBlue
        case .entertainment: return .clarityTeal
        case .other: return .gray
        }
    }
}

struct EditBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let userEmail: String
    @Query private var budgets: [Budget]

    @State private var limits: [TransactionCategory: Double] = [:]
    @State private var showWizard = false

    init(userEmail: String) {
        self.userEmail = userEmail
        _budgets = Query(filter: #Predicate<Budget> { $0.ownerEmail == userEmail })
    }

    var body: some View {
        NavigationStack {
            Form {
                if budgets.isEmpty {
                    Section {
                        Button(action: { showWizard = true }) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(Color.clarityBlue)
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading) {
                                    Text("Create a Budget Plan")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("Use our wizard to set up a balanced plan")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
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
            .sheet(isPresented: $showWizard) {
                CreateBudgetView()
            }
        }
    }
    
    private func saveBudgets() {
        for (category, limit) in limits {
            if let existing = budgets.first(where: { $0.category == category }) {
                existing.limit = limit
            } else if limit > 0 {
                let newBudget = Budget(ownerEmail: userEmail, category: category, limit: limit)
                context.insert(newBudget)
            }
        }
        try? context.save()
        dismiss()
    }
}
