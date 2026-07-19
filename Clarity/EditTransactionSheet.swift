import SwiftUI
import SwiftData

struct EditTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var transaction: Transaction
    
    @State private var amount: String = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Amount Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("$")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                TextField("0.00", text: $amount)
                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                            .background(Color.clarityCard)
                            .cornerRadius(20)
                        }
                        
                        // Category Selection (Grid)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                                ForEach(TransactionCategory.allCases) { cat in
                                    SelectionChip(
                                        title: cat.rawValue.capitalized,
                                        isSelected: transaction.category == cat
                                    ) {
                                        withAnimation { transaction.category = cat }
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color.clarityCard)
                            .cornerRadius(20)
                        }
                        
                        // Note
                        CustomTextField(
                            icon: "note.text",
                            placeholder: "What was this for?",
                            text: Binding(
                                get: { transaction.note ?? "" },
                                set: { transaction.note = $0.isEmpty ? nil : $0 }
                            )
                        )
                        
                        // Date & Recurring
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                                
                                DatePicker("Date", selection: $transaction.date, displayedComponents: [.date])
                                    .labelsHidden()
                                    .tint(Color.clarityBlue)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.clarityCard)
                            .cornerRadius(16)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Button(action: { withAnimation { transaction.isRecurring.toggle() } }) {
                                    HStack {
                                        Image(systemName: "repeat")
                                            .font(.title3)
                                            .foregroundStyle(transaction.isRecurring ? Color.white : Color.clarityPurple)
                                            .frame(width: 32, height: 32)
                                            .background(transaction.isRecurring ? Color.clarityPurple : Color.clear)
                                            .clipShape(Circle())
                                        
                                        Text("Repeat")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(transaction.isRecurring ? Color.clarityPurple : Color.primary)
                                        
                                        Spacer()
                                    }
                                }
                                
                                if transaction.isRecurring {
                                    Menu {
                                        ForEach(TransactionInterval.allCases) { interval in
                                            Button(interval.displayName) {
                                                transaction.recurrenceInterval = interval
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(transaction.recurrenceInterval.displayName)
                                                .font(.subheadline)
                                                .foregroundStyle(Color.clarityPurple)
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.caption)
                                                .foregroundStyle(Color.clarityPurple)
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.clarityPurple.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(transaction.isRecurring ? Color.clarityPurple.opacity(0.05) : Color.clarityCard)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(transaction.isRecurring ? Color.clarityPurple : Color.clear, lineWidth: 1)
                            )
                        }
                        
                        Spacer(minLength: 20)
                        
                        Button(action: saveChanges) {
                            Text("Save Changes")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(Double(amount) == nil || amount.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .alert("Delete Transaction?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteTransaction()
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .onAppear {
                amount = String(format: "%.2f", transaction.amount)
            }
        }
    }
    
    @Query private var budgets: [Budget]
    // We can't easily query "all transactions for this month" dynamically inside the view without a complex predicate provided by init.
    // Instead we will rely on a simpler fetch or just let the main view handle it? 
    // No, let's fetch all (it's efficient enough for now) and filter.
    @Query private var allTransactions: [Transaction] 
    
    private func saveChanges() {
        if let value = Double(amount) {
            transaction.amount = value
        }
        
        // 1. Dopamine Hit
        FinanceNotificationHelper.triggerNotification(for: transaction)
        
        // 2. Check Budget
        checkBudget(for: transaction)
        
        try? context.save()
        dismiss()
    }
    
    private func checkBudget(for transaction: Transaction) {
        guard let budget = budgets.first(where: { $0.category == transaction.category }) else { return }
        
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        
        let monthTransactions = allTransactions.filter { 
            $0.category == transaction.category && 
            calendar.component(.month, from: $0.date) == currentMonth 
        }
        
        let totalSpent = monthTransactions.reduce(0) { $0 + $1.amount } + (Double(amount) ?? 0)
        
        if totalSpent > budget.limit {
            FinanceNotificationHelper.triggerBudgetAlert(status: .over, category: transaction.category)
        } else if totalSpent > (budget.limit * 0.8) {
            FinanceNotificationHelper.triggerBudgetAlert(status: .near, category: transaction.category)
        }
    }
    
    private func deleteTransaction() {
        context.delete(transaction)
        try? context.save()
        dismiss()
    }
}
