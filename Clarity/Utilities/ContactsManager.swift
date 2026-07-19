import Foundation
import Contacts

/// Contact information for friend discovery
struct ContactInfo: Identifiable {
    let id = UUID()
    let name: String
    let email: String
    
    var displayName: String {
        name.isEmpty ? email : name
    }
}

/// Manages access to user's contacts for friend discovery
class ContactsManager {
    static let shared = ContactsManager()
    
    private let contactStore = CNContactStore()
    
    private init() {}
    
    /// Request permission to access contacts
    func requestAccess() async throws -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        
        switch status {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return try await contactStore.requestAccess(for: .contacts)
        default:
            return false
        }
    }
    
    /// Fetch contact information (name and email) from contacts
    func fetchContactInfo() async throws -> [ContactInfo] {
        // First request access
        let hasAccess = try await requestAccess()
        guard hasAccess else {
            throw ContactsError.permissionDenied
        }
        
        // Define keys we want to fetch
        let keys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactEmailAddressesKey
        ] as [CNKeyDescriptor]
        
        // Fetch all contacts
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        // Capture contactStore to avoid actor isolation issues
        let store = self.contactStore
        
        // Run enumeration on background thread to avoid blocking UI
        return try await Task.detached(priority: .userInitiated) {
            var contacts: [ContactInfo] = []
            
            try store.enumerateContacts(with: request) { contact, _ in
                let fullName = [contact.givenName, contact.familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                
                for emailValue in contact.emailAddresses {
                    let email = (emailValue.value as String).lowercased()
                    contacts.append(ContactInfo(name: fullName, email: email))
                }
            }
            
            return contacts
        }.value
    }
    
    /// Fetch all email addresses from contacts (legacy method for backward compatibility)
    func fetchContactEmails() async throws -> [String] {
        // First request access
        let hasAccess = try await requestAccess()
        guard hasAccess else {
            throw ContactsError.permissionDenied
        }
        
        // Define keys we want to fetch
        let keys = [CNContactEmailAddressesKey] as [CNKeyDescriptor]
        
        // Fetch all contacts
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        // Capture contactStore to avoid actor isolation issues
        let store = self.contactStore
        
        // Run enumeration on background thread to avoid blocking UI
        return try await Task.detached(priority: .userInitiated) {
            var emails: [String] = []
            
            try store.enumerateContacts(with: request) { contact, _ in
                for emailValue in contact.emailAddresses {
                    let email = emailValue.value as String
                    // Convert to lowercase for consistency with our search
                    emails.append(email.lowercased())
                }
            }
            
            // Remove duplicates
            return Array(Set(emails))
        }.value
    }
}

enum ContactsError: LocalizedError {
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission to access contacts was denied. Please enable in Settings."
        }
    }
}
