import Foundation
import Security
import Combine

/// Manages persistent authentication state using Keychain
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    private let service = "com.clarity.app"
    private let lastUserEmailKey = "lastUserEmail"
    private let appleUserIdKey = "appleUserId" // Store Apple's stable user identifier
    
    private init() {}
    
    // MARK: - Last Logged In User
    
    /// Save the last logged-in user email to UserDefaults
    func saveLastUserEmail(_ email: String) {
        UserDefaults.standard.set(email, forKey: lastUserEmailKey)
    }
    
    /// Get the last logged-in user email
    func getLastUserEmail() -> String? {
        return UserDefaults.standard.string(forKey: lastUserEmailKey)
    }
    
    /// Clear the last logged-in user
    func clearLastUserEmail() {
        UserDefaults.standard.removeObject(forKey: lastUserEmailKey)
    }
    
    // MARK: - Apple Sign In User ID Mapping
    
    /// Save mapping between Apple User ID and email
    func saveAppleUserMapping(appleUserId: String, email: String) {
        let key = "apple_\(appleUserId)"
        UserDefaults.standard.set(email, forKey: key)
    }
    
    /// Get email for Apple User ID
    func getEmailForAppleUser(_ appleUserId: String) -> String? {
        let key = "apple_\(appleUserId)"
        return UserDefaults.standard.string(forKey: key)
    }
    
    // MARK: - Session State
    
    /// Check if user is logged in (has a valid last email)
    var isLoggedIn: Bool {
        return getLastUserEmail() != nil
    }
    
    /// Logout (clear session)
    func logout() {
        clearLastUserEmail()
        print("✅ User logged out")
    }
    
    // MARK: - Session Validation
    
    /// Validate that the session is still valid by checking both UserDefaults and SwiftData
    /// Returns false and clears the session if the profile doesn't exist in the database
    func validateSession(profiles: [UserProfile]) -> Bool {
        guard let email = getLastUserEmail() else {
            return false
        }
        
        // Check if the profile still exists in SwiftData
        if profiles.contains(where: { $0.email == email && $0.onboardingCompleted }) {
            return true
        }
        
        // Session is stale - clear it
        logout()
        print("⚠️ Session validation failed: Profile not found or incomplete for \(email)")
        return false
    }
}
