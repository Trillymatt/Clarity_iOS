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
                            
                            HStack {
                                Text("$")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(.secondary)
                                TextField("0.00", text: $amount)
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .keyboardType(.decimalPad)
                            }
                            .padding()
                            .background(Color.clarityCard)
                            .cornerRadius(16)
                        }
                        
                        // Category Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(TransactionCategory.allCases) { cat in
                                        SelectionChip(
                                            title: cat.rawValue.capitalized,
                                            isSelected: transaction.category == cat
                                        ) {
                                            withAnimation { transaction.category = cat }
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
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
                        
                        // Date
                        VStack(alignment: .leading, spacing: 12) {
                            Text("When?")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            DatePicker("Date", selection: $transaction.date, displayedComponents: [.date])
                                .datePickerStyle(.graphical)
                                .padding()
                                .background(Color.clarityCard)
                                .cornerRadius(16)
                        }
                        
                        // Recurring Toggle
                        Toggle(isOn: $transaction.isRecurring) {
                            Label("Recurring Transaction", systemImage: "repeat")
                        }
                        .padding()
                        .background(Color.clarityCard)
                        .cornerRadius(12)
                        
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
    
    private func saveChanges() {
        if let value = Double(amount) {
            transaction.amount = value
        }
        try? context.save()
        dismiss()
    }
    
    private func deleteTransaction() {
        context.delete(transaction)
        try? context.save()
        dismiss()
    }
}
