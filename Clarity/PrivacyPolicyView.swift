import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy Policy")
                        .font(.title.bold())
                    
                    Text("Last updated: December 2024")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Introduction
                PolicySection(
                    title: "Introduction",
                    content: "Clarity is designed with your privacy as a priority. We believe your personal data should remain personal. This policy explains how we handle your information."
                )
                
                // Data Storage
                PolicySection(
                    title: "Data Storage",
                    content: "All your data—including tasks, habits, moments, mood entries, and financial information—is stored locally on your device. We do not upload, sync, or store your personal data on external servers."
                )
                
                // Data Collection
                PolicySection(
                    title: "What We Collect",
                    content: """
                    Clarity collects only what you provide:
                    
                    • Your name and email (for account identification)
                    • Tasks, habits, and goals you create
                    • Mood check-ins and journal entries
                    • Transaction records you log
                    • Weekly review reflections
                    
                    This data never leaves your device.
                    """
                )
                
                // Third Parties
                PolicySection(
                    title: "Third-Party Services",
                    content: "Clarity may use AI features powered by OpenAI to help generate suggestions and insights. When you use these features, only the specific content you're working with is temporarily processed. We do not share your personal information or history with any third parties."
                )
                
                // Your Rights
                PolicySection(
                    title: "Your Rights",
                    content: """
                    You have complete control over your data:
                    
                    • Access: View all your data within the app
                    • Delete: Remove any data at any time
                    • Export: Your data is yours (coming soon)
                    
                    Deleting the app will remove all local data permanently.
                    """
                )
                
                // Security
                PolicySection(
                    title: "Security",
                    content: "Your data is protected by your device's built-in security features, including encryption and biometric protection. We recommend keeping your device updated and using a strong passcode."
                )
                
                // Changes
                PolicySection(
                    title: "Changes to This Policy",
                    content: "We may update this privacy policy from time to time. Any changes will be reflected with a new 'Last updated' date at the top of this page."
                )
                
                // Contact
                PolicySection(
                    title: "Contact",
                    content: "If you have questions about this privacy policy or how your data is handled, please contact us through the App Store."
                )
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(Color.clarityBackground)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Policy Section Component
struct PolicySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(content)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
