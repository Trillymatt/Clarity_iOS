import SwiftUI

struct AddFriendSheet: View {
    let initialEmail: String?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudKitService = CloudKitService.shared
    
    @State private var searchText = ""
    @State private var searchResults: [ClarityUserRecord] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var contactsOnClarity: [ClarityUserRecord] = []
    @State private var contactsNotOnClarity: [ContactInfo] = []
    @State private var isLoadingContacts = false
    @State private var showingInviteSheet = false
    @State private var inviteContact: ContactInfo?
    
    init(initialEmail: String? = nil) {
        self.initialEmail = initialEmail
    }
    
    var filteredContactsOnClarity: [ClarityUserRecord] {
        if searchText.isEmpty { return contactsOnClarity }
        return contactsOnClarity.filter { user in
            (user.displayName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            user.email.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var filteredContactsNotOnClarity: [ContactInfo] {
        if searchText.isEmpty { return contactsNotOnClarity }
        return contactsNotOnClarity.filter { contact in
            contact.displayName.localizedCaseInsensitiveContains(searchText) ||
            contact.email.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search name or email", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        // Use default keyboard to allow typing names easily
                        .keyboardType(.default)
                        .submitLabel(.search)
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                .padding()
                
                // Find from Contacts Button
                Button {
                    findFromContacts()
                } label: {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(.white)
                        Text("Find from Contacts")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.clarityBlue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(isLoadingContacts)
                
                // Results
                if isSearching || isLoadingContacts {
                    ProgressView()
                        .padding()
                } else if let error = errorMessage {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // Contacts on Clarity
                            if !filteredContactsOnClarity.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("On Clarity")
                                        .font(.headline)
                                        .padding(.horizontal)
                                    
                                    ForEach(filteredContactsOnClarity) { user in
                                        UserSearchResultRow(user: user) {
                                            sendRequest(to: user)
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // Contacts not on Clarity - Invite them
                            if !filteredContactsNotOnClarity.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Invite to Clarity")
                                        .font(.headline)
                                        .padding(.horizontal)
                                    
                                    ForEach(filteredContactsNotOnClarity) { contact in
                                        ContactInviteRow(contact: contact) {
                                            inviteContact = contact
                                            showingInviteSheet = true
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // Search Results (Remote)
                            if !searchResults.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Search Results")
                                        .font(.headline)
                                        .padding(.horizontal)
                                    
                                    ForEach(searchResults) { user in
                                        UserSearchResultRow(user: user) {
                                            sendRequest(to: user)
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // Empty State
                            if searchResults.isEmpty && 
                               filteredContactsOnClarity.isEmpty && 
                               filteredContactsNotOnClarity.isEmpty && 
                               !searchText.isEmpty &&
                               // Only show "No Results" if we have actually loaded something or searched
                               (!contactsOnClarity.isEmpty || !contactsNotOnClarity.isEmpty || !searchResults.isEmpty) {
                                ContentUnavailableView("No Results", systemImage: "person.slash", description: Text("No users found"))
                                    .padding()
                            }
                        }
                        .padding(.vertical)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingInviteSheet) {
                if let contact = inviteContact {
                    ShareSheet(items: [createInviteMessage(for: contact)])
                }
            }
            .onAppear {
                // Auto-fill and search if email was provided via deep link
                if let email = initialEmail, !email.isEmpty {
                    searchText = email
                    performSearch()
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await cloudKitService.searchUsers(email: searchText)
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }
    
    private func findFromContacts() {
        isLoadingContacts = true
        errorMessage = nil
        
        Task {
            do {
                // Fetch contacts with names and emails
                let allContacts = try await ContactsManager.shared.fetchContactInfo()
                
                // Extract just emails for CloudKit lookup
                let emails = allContacts.map { $0.email }
                
                // Find users matching these emails in CloudKit
                let usersOnClarity = try await cloudKitService.findUsers(byEmails: emails)
                
                // Filter out current user and existing friends
                let filteredUsers = usersOnClarity.filter { user in
                    user.userId != cloudKitService.currentUser?.userId &&
                    !cloudKitService.friends.contains(where: { $0.friendUserId == user.userId })
                }
                
                // Determine which contacts are NOT on Clarity
                let clarityEmails = Set(usersOnClarity.map { $0.email.lowercased() })
                let contactsNotFound = allContacts.filter { contact in
                    !clarityEmails.contains(contact.email.lowercased())
                }
                
                await MainActor.run {
                    self.contactsOnClarity = filteredUsers
                    self.contactsNotOnClarity = contactsNotFound
                    self.isLoadingContacts = false
                }
            } catch let error as ContactsError {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoadingContacts = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load contacts: \(error.localizedDescription)"
                    self.isLoadingContacts = false
                }
            }
        }
    }
    
    private func createInviteMessage(for contact: ContactInfo) -> String {
        return """
        Hey \(contact.displayName)! 👋
        
        I'm using Clarity to stay organized and boost my productivity. It helps me track tasks, habits, moods, and more - all in one beautiful app.
        
        Join me on Clarity!
        
        🔗 Get it here: https://testflight.apple.com/join/49jdnaAc
        """
    }
    
    private func sendRequest(to user: ClarityUserRecord) {
        Task {
            do {
                try await cloudKitService.sendFriendRequest(to: user)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct UserSearchResultRow: View {
    let user: ClarityUserRecord
    let onAdd: () -> Void
    
    var body: some View {
        HStack {
            // Profile Picture Placeholder
            ZStack {
                Circle()
                    .fill(Color.clarityBlue.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                if let photoURL = user.photoURL, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color.clarityBlue)
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .foregroundStyle(Color.clarityBlue)
                }
            }
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName ?? "Clarity User")
                    .font(.headline)
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Add Button
            Button {
                onAdd()
            } label: {
                Text("Add")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.clarityBlue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct ContactInviteRow: View {
    let contact: ContactInfo
    let onInvite: () -> Void
    
    var body: some View {
        HStack {
            // Profile Picture Placeholder
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "person.fill")
                    .foregroundStyle(Color.orange)
            }
            
            // Contact Info
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.displayName)
                    .font(.headline)
                Text(contact.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Invite Button
            Button {
                onInvite()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "paperplane.fill")
                    Text("Invite")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

// Share Sheet wrapper for UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
