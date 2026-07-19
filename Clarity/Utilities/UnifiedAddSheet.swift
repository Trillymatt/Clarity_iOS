
import SwiftUI

struct UnifiedAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    let userEmail: String
    
    @State private var showTaskSheet = false
    @State private var showHabitSheet = false
    @State private var showMomentSheet = false
    @State private var showTransactionSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Text("Add New")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("What would you like to create?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        AddOptionCard(
                            title: "Task",
                            icon: "checkmark.circle.fill",
                            color: .clarityBlue,
                            description: "To-do items & reminders"
                        ) {
                            showTaskSheet = true
                        }
                        
                        AddOptionCard(
                            title: "Habit",
                            icon: "flame.fill",
                            color: .clarityOrange,
                            description: "Build daily routines"
                        ) {
                            showHabitSheet = true
                        }
                        
                        AddOptionCard(
                            title: "Moment",
                            icon: "sparkles",
                            color: .clarityPurple,
                            description: "Journal your day"
                        ) {
                            showMomentSheet = true
                        }
                        
                        AddOptionCard(
                            title: "Transaction",
                            icon: "banknote.fill",
                            color: .clarityTeal,
                            description: "Track expenses"
                        ) {
                            showTransactionSheet = true
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showTaskSheet) {
                AddTaskSheet(userEmail: userEmail)
            }
            .sheet(isPresented: $showHabitSheet) {
                AddHabitSheet(userEmail: userEmail)
            }
            .sheet(isPresented: $showMomentSheet) {
                AddMomentSheet(userEmail: userEmail)
            }
            .sheet(isPresented: $showTransactionSheet) {
                AddTransactionSheet(userEmail: userEmail)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct AddOptionCard: View {
    let title: String
    let icon: String
    let color: Color
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(color)
                    .padding(10)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.clarityCard)
            .cornerRadius(20)
            .shadow(color: color.opacity(0.05), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
