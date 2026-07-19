import SwiftUI
import SwiftData

struct CreateBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var existingBudgets: [Budget]
    
    // MARK: - State
    @State private var step = 1
    @State private var monthlyIncome: Double?
    @State private var incomeString = ""
    
    // Fixed Expenses State
    @State private var rentAmount = ""
    @State private var carAmount = ""
    @State private var utilitiesAmount = ""
    @State private var otherBillsAmount = ""
    
    @State private var budgetAllocations: [TransactionCategory: Double] = [:]
    
    // MARK: - Constants
    // 50/30/20 Rule: Needs (50%), Wants (30%), Savings (20%)
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Progress Indicator
                    HStack(spacing: 8) {
                        ForEach(1...4, id: \.self) { i in
                            Capsule()
                                .fill(i <= step ? Color.clarityBlue : Color.gray.opacity(0.2))
                                .frame(height: 4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    TabView(selection: $step) {
                        incomeInputStep
                            .tag(1)
                        
                        fixedExpensesStep
                            .tag(2)
                        
                        allocationStep
                            .tag(3)
                        
                        customizationStep
                            .tag(4)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                
                // Bottom Navigation
                VStack {
                    Spacer()
                    
                    HStack(spacing: 20) {
                        if step > 1 {
                            Button(action: { withAnimation { step -= 1 } }) {
                                Image(systemName: "chevron.left")
                                    .font(.title3.bold())
                                    .foregroundStyle(.secondary)
                                    .padding()
                                    .background(Color.clarityCard)
                                    .clipShape(Circle())
                            }
                        }
                        
                        Button(action: nextStep) {
                            Text(step == 4 ? "Save Budget" : "Next")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LinearGradient.clarityPrimary)
                                .cornerRadius(16)
                                .shadow(color: .clarityPurple.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .disabled(step == 1 && monthlyIncome == nil)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Steps
    
    var stepTitle: String {
        switch step {
        case 1: return "Monthly Income"
        case 2: return "Fixed Expenses"
        case 3: return "Recommended Plan"
        case 4: return "Customize"
        default: return "Create Budget"
        }
    }
    
    // Step 1: Income Input
    var incomeInputStep: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient.clarityPrimary)
                .shadow(color: .clarityPurple.opacity(0.3), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 16) {
                Text("Monthly Net Income")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                
                Text("Enter your take-home pay. We'll use this to build a balanced budget.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            HStack(spacing: 4) {
                Text("$")
                    .font(.title.bold())
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                
                TextField("0", text: $incomeString)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .onChange(of: incomeString) { _, newValue in
                        let filtered = newValue.filter { "0123456789.".contains($0) }
                        if filtered != newValue {
                            incomeString = filtered
                        }
                        monthlyIncome = Double(filtered)
                    }
            }
            .padding(.vertical, 20)
            
            Spacer()
            
            if monthlyIncome != nil {
                Text("Great start! Tap Next to see continue.")
                    .font(.caption.bold())
                    .foregroundStyle(Color.clarityBlue)
            }
            
            Spacer()
        }
    }
    
    // Step 2: Fixed Expenses
    var fixedExpensesStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Fixed Expenses")
                        .font(.title2.bold())
                    Text("Enter your recurring monthly bills. This helps us calculate your true 'Needs'.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                VStack(spacing: 20) {
                    expenseInputRow(title: "Rent / Mortgage", icon: "house.fill", color: .clarityBlue, text: $rentAmount)
                    expenseInputRow(title: "Car Payment & Insurance", icon: "car.fill", color: .clarityOrange, text: $carAmount)
                    expenseInputRow(title: "Utilities & Internet", icon: "bolt.fill", color: .clarityPurple, text: $utilitiesAmount)
                    expenseInputRow(title: "Other Fixed Bills", icon: "doc.text.fill", color: .gray, text: $otherBillsAmount, placeholder: "Loans, subscriptions, etc.")
                }
                }
                .padding()
                .padding(.bottom, 80) // Space for bottom nav
            }
        }
    
    func expenseInputRow(title: String, icon: String, color: Color, text: Binding<String>, placeholder: String = "0") -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(title)
                    .font(.headline)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
            
            HStack {
                Text("$")
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: text)
                    .keyboardType(.decimalPad)
            }
            .padding()
            .background(Color.clarityCard)
            .cornerRadius(12)
        }
    }
    
    // Step 3: Allocation Visualization
    var allocationStep: some View {
        VStack(spacing: 24) {
            Text("Recommended Plan")
                .font(.title2.bold())
                .padding(.top)
            
            Text("Based on your income & fixed costs")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            
            if let income = monthlyIncome {
                // Detailed Breakdown
                VStack(spacing: 20) {
                    allocationRow(title: "Needs", amount: (budgetAllocations[.bills] ?? 0) + (budgetAllocations[.transport] ?? 0) + (budgetAllocations[.food] ?? 0), color: .clarityBlue,
                                  subtitle: "Bills, Rent, Transport, Food")
                    
                    Divider()
                    
                    allocationRow(title: "Wants", amount: (budgetAllocations[.shopping] ?? 0) + (budgetAllocations[.entertainment] ?? 0) + (budgetAllocations[.other] ?? 0), color: .clarityPurple,
                                  subtitle: "Shopping, Entertainment, Fun")
                    
                    Divider()
                    
                    let totalBudgeted = budgetAllocations.values.reduce(0, +)
                    let savings = max(0, income - totalBudgeted)
                    
                    allocationRow(title: "Savings", amount: savings, color: .clarityGreen,
                                  subtitle: "Investments, Debt Repayment")
                }
                .padding(24)
                .background(Color.clarityCard)
                .cornerRadius(20)
                .padding(.horizontal)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            }
            
            Spacer()
        }
    }
    
    func allocationRow(title: String, amount: Double, color: Color, subtitle: String) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 4, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(amount.formatted(.currency(code: "USD")))
                .font(.headline.monospaced())
        }
    }
    
    // Step 4: Customization
    var customizationStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Customize Categories")
                    .font(.title2.bold())
                    .padding(.top)
                
                VStack(spacing: 16) {
                    ForEach(TransactionCategory.allCases) { category in
                        HStack {
                            Text(category.rawValue.capitalized)
                                .font(.body.weight(.medium))
                            Spacer()
                            TextField("Limit", value: Binding(
                                get: { budgetAllocations[category] ?? 0 },
                                set: { budgetAllocations[category] = $0 }
                            ), format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.clarityBackground)
                            .cornerRadius(8)
                            .frame(width: 120)
                        }
                        .padding()
                        .background(Color.clarityCard)
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal)
                
                // Summary Card
                VStack(spacing: 16) {
                    let totalBudgeted = budgetAllocations.values.reduce(0, +)
                    let income = monthlyIncome ?? 0
                    let remaining = income - totalBudgeted
                    
                    HStack {
                        Text("Total Budgeted")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(totalBudgeted.formatted(.currency(code: "USD")))
                            .font(.headline)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Remaining for Savings")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(remaining.formatted(.currency(code: "USD")))
                            .font(.title3.bold())
                            .foregroundStyle(remaining >= 0 ? .green : .red)
                    }
                }
                .padding(20)
                .background(Color.clarityCard)
                .cornerRadius(20)
                .padding(.horizontal)
                .padding(.bottom, 100) // Space for bottom nav
            }
        }
    }
    
    // MARK: - Actions
    
    func nextStep() {
        if step < 4 {
            if step == 2 {
                calculateInitialAllocations()
            }
            withAnimation {
                step += 1
            }
        } else {
            saveBudgets()
        }
    }
    
    func calculateInitialAllocations() {
        guard let income = monthlyIncome else { return }
        
        let rent = Double(rentAmount) ?? 0
        let car = Double(carAmount) ?? 0
        let utilities = Double(utilitiesAmount) ?? 0
        let otherBills = Double(otherBillsAmount) ?? 0
        
        // Strategy: Use actuals where provided, estimate others
        
        // Bills: Rent + Utilities + Other Fixed
        budgetAllocations[.bills] = rent + utilities + otherBills
        
        // Transport: Car Payment + Gas Estimation (e.g. $150)
        budgetAllocations[.transport] = car + (car > 0 ? 150 : 100)
        
        // Calculate remaining "disposable" for variable costs
        // Total Income - Fixed Costs - Savings Target (20%)
        let fixedCosts = rent + car + utilities + otherBills
        let savingsTarget = income * 0.20
        let variableBudget = max(0, income - fixedCosts - savingsTarget)
        
        // Distribute Variable Budget
        // Food: 50% of variable
        budgetAllocations[.food] = variableBudget * 0.50
        
        // Wants: 50% split 3 ways
        let wantsSlice = (variableBudget * 0.50) / 3.0
        budgetAllocations[.shopping] = wantsSlice
        budgetAllocations[.entertainment] = wantsSlice
        budgetAllocations[.other] = wantsSlice
    }
    
    func saveBudgets() {
        for (category, limit) in budgetAllocations {
            if let existing = existingBudgets.first(where: { $0.category == category }) {
                existing.limit = limit
                existing.period = "Monthly"
            } else {
                let newBudget = Budget(category: category, limit: limit, period: "Monthly")
                context.insert(newBudget)
            }
        }
        
        try? context.save()
        dismiss()
    }
}

#Preview {
    CreateBudgetView()
}
