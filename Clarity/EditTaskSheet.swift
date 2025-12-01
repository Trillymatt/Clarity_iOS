import SwiftUI
import SwiftData

struct EditTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var task: TaskItem
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Title Input
                        CustomTextField(icon: "pencil", placeholder: "Task Title", text: $task.title)
                        
                        // Quick Date Actions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("When?")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    QuickDateButton(label: "Today", icon: "sun.max.fill", color: .clarityOrange) {
                                        task.dueDate = Date()
                                        task.isToday = true
                                    }
                                    
                                    QuickDateButton(label: "Tomorrow", icon: "sunrise.fill", color: .clarityBlue) {
                                        task.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
                                        task.isToday = false
                                    }
                                    
                                    QuickDateButton(label: "Next Week", icon: "calendar.badge.clock", color: .clarityPurple) {
                                        task.dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
                                        task.isToday = false
                                    }
                                    
                                    QuickDateButton(label: "Clear Date", icon: "xmark.circle", color: .secondary) {
                                        task.dueDate = nil
                                        task.isToday = false
                                    }
                                }
                            }
                        }
                        
                        // Detailed Date Picker
                        VStack(alignment: .leading, spacing: 8) {
                            DatePicker("Due Date", selection: Binding(
                                get: { task.dueDate ?? Date() },
                                set: { task.dueDate = $0 }
                            ), displayedComponents: [.date])
                            .datePickerStyle(.graphical)
                            .padding()
                            .background(Color.clarityCard)
                            .cornerRadius(12)
                        }
                        
                        // Notes
                        CustomTextEditor(title: "Notes", text: Binding(
                            get: { task.notes ?? "" },
                            set: { task.notes = $0.isEmpty ? nil : $0 }
                        ))
                        
                        // Delete Button
                        Button(action: { showDeleteConfirmation = true }) {
                            Text("Delete Task")
                                .font(.body.bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(16)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? context.save()
                        dismiss()
                    }
                }
            })
            .alert("Delete Task?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    context.delete(task)
                    try? context.save()
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
}

struct QuickDateButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption.bold())
            }
            .frame(width: 80, height: 80)
            .foregroundStyle(color)
            .background(Color.clarityCard)
            .cornerRadius(12)
            .shadow(color: color.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
}
