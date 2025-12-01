import SwiftUI
import SwiftData

struct EmailAuthView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    
    var onFinish: (UserProfile) -> Void
    
    @State private var isSignUp = true
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color.clarityBackground.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.clarityBlue)
                    
                    Text(isSignUp ? "Create Account" : "Welcome Back")
                        .titleStyle()
                    
                    Text(isSignUp ? "Sign up to start your journey" : "Sign in to continue")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // Form
                VStack(spacing: 20) {
                    if isSignUp {
                        TextField("Full Name", text: $name)
                            .padding()
                            .background(Color.clarityCard)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .textContentType(.name)
                    }
                    
                    TextField("Email", text: $email)
                        .padding()
                        .background(Color.clarityCard)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textContentType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color.clarityCard)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .textContentType(isSignUp ? .newPassword : .password)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 24)
                
                // Action Button
                Button(action: performAuth) {
                    Text(isSignUp ? "Sign Up" : "Log In")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .disabled(email.isEmpty || password.isEmpty || (isSignUp && name.isEmpty))
                
                // Toggle Mode
                Button(action: {
                    withAnimation {
                        isSignUp.toggle()
                        errorMessage = nil
                    }
                }) {
                    Text(isSignUp ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                        .font(.subheadline)
                        .foregroundStyle(Color.clarityBlue)
                }
                
                Spacer()
            }
        }
    }
    
    private func performAuth() {
        if isSignUp {
            // Check if email already exists
            if profiles.contains(where: { $0.email.lowercased() == email.lowercased() }) {
                errorMessage = "Account with this email already exists."
                return
            }
            
            // Create new profile
            let newProfile = UserProfile(name: name, email: email, passwordHash: password) // In real app, hash this!
            context.insert(newProfile)
            try? context.save()
            onFinish(newProfile)
            
        } else {
            // Log In
            if let profile = profiles.first(where: { $0.email.lowercased() == email.lowercased() }) {
                if profile.passwordHash == password {
                    onFinish(profile)
                } else {
                    errorMessage = "Incorrect password."
                }
            } else {
                errorMessage = "No account found with this email."
            }
        }
    }
}
