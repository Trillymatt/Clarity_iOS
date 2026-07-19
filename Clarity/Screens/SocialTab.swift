import SwiftUI
import SwiftData

struct SocialTab: View {
    let userEmail: String
    @StateObject private var cloudKitService = CloudKitService.shared
    @State private var showingAddFriend = false
    @State private var showingProfile = false
    @State private var friendEmailToAdd: String? = nil
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @Query private var profiles: [UserProfile]
    
    init(userEmail: String) {
        self.userEmail = userEmail
        _profiles = Query(filter: #Predicate { $0.email == userEmail })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Spacer for nav bar
                        Color.clear.frame(height: 20)
                        
                        // Main Header Card
                        GradientCard(gradient: .clarityPrimary) {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Connections")
                                        .font(.clarityTitle)
                                        .foregroundStyle(.white)
                                    
                                    if cloudKitService.currentUser != nil {
                                        Text("\(cloudKitService.friends.count) Friends")
                                            .font(.claritySubtitle)
                                            .foregroundStyle(.white.opacity(0.9))
                                    }
                                }
                                
                                Spacer()
                                
                                if cloudKitService.currentUser != nil {
                                    HStack(spacing: 12) {
                                        // Share Invite Link
                                        ShareLink(
                                            item: generateInviteLink(),
                                            subject: Text("Join me on Clarity!"),
                                            message: Text("I'm using Clarity to track my goals and habits. Add me as a friend! \(cloudKitService.currentUser?.email ?? "")")
                                        ) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.headline)
                                                .foregroundStyle(Color.clarityBlue)
                                                .frame(width: 44, height: 44)
                                                .background(.white)
                                                .clipShape(Circle())
                                        }
                                        
                                        // Add Friend Button
                                        Button {
                                            showingAddFriend = true
                                        } label: {
                                            Image(systemName: "person.badge.plus")
                                                .font(.headline)
                                                .foregroundStyle(Color.clarityBlue)
                                                .frame(width: 44, height: 44)
                                                .background(.white)
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                            }
                        }
                        
                        if cloudKitService.currentUser == nil {
                            // CloudKit not available - show message
                            SoftCard {
                                VStack(spacing: 20) {
                                    Image(systemName: "icloud.slash")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.secondary)
                                    
                                    Text("iCloud Required")
                                        .font(.title2.bold())
                                    
                                    Text("Social features require iCloud to sync friends and activities across devices.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    
                                    if let error = cloudKitService.syncError {
                                        VStack(spacing: 8) {
                                            Text("Error Details:")
                                                .font(.caption.bold())
                                                .foregroundStyle(.secondary)
                                            
                                            Text(error)
                                                .font(.caption)
                                                .foregroundStyle(.red)
                                                .multilineTextAlignment(.center)
                                                .padding(.horizontal)
                                            
                                            // Show container identifier for debugging
                                            Text("Container: iCloud.mattknorman.Clarity")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                                .padding(.horizontal)
                                        }
                                        .padding(.top, 12)
                                        .padding(.horizontal)
                                        .padding(.vertical, 12)
                                        .background(Color.red.opacity(0.05))
                                        .cornerRadius(8)
                                        .padding(.horizontal)
                                    }
                                    
                                    VStack(spacing: 12) {
                                        Button {
                                            Task {
                                                if let profile = profiles.first {
                                                    try? await cloudKitService.syncCurrentUser(email: profile.email, displayName: profile.name)
                                                } else {
                                                    try? await cloudKitService.syncCurrentUser()
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                if cloudKitService.isSyncing {
                                                    ProgressView()
                                                        .tint(.white)
                                                    Text("Connecting...")
                                                } else {
                                                    Image(systemName: "arrow.clockwise")
                                                    Text("Try Again")
                                                }
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.clarityBlue)
                                            .foregroundStyle(.white)
                                            .cornerRadius(12)
                                        }
                                        .disabled(cloudKitService.isSyncing)
                                        .padding(.horizontal, 40)
                                        .padding(.top, 8)
                                        
                                        Button {
                                            dismiss()
                                        } label: {
                                            Text("Skip for Now")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.top, 4)
                                        
                                        VStack(spacing: 4) {
                                            Text("Troubleshooting:")
                                                .font(.caption.bold())
                                                .foregroundStyle(.secondary)
                                            Text("1. Check iCloud sign-in (Settings app)")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                            Text("2. Check Xcode console for error code")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                            Text("3. See CLOUDKIT_SETUP.md in project")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(.top, 12)
                                    }
                                }
                                .padding(.vertical, 32)
                            }
                            .task {
                                // Only try once automatically on appear
                                if cloudKitService.syncError == nil && !cloudKitService.isSyncing {
                                    if let profile = profiles.first {
                                        try? await cloudKitService.syncCurrentUser(email: profile.email, displayName: profile.name)
                                    } else {
                                        try? await cloudKitService.syncCurrentUser()
                                    }
                                }
                            }
                        } else {
                            // Friend Requests Section
                            if !cloudKitService.friendRequests.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Friend Requests")
                                        .font(.headline)
                                        .padding(.leading, 4)
                                    
                                    ForEach(cloudKitService.friendRequests) { request in
                                        FriendRequestRow(request: request)
                                    }
                                }
                            }
                            
                            // Friend Status Ring
                            FriendStatusHeader()
                            
                            // Activity Feed
                            ActivityFeedView()
                        }
                        
                        Spacer(minLength: 80)
                    }
                    .padding()
                }
                .refreshable {
                    if let profile = profiles.first {
                        try? await cloudKitService.syncCurrentUser(email: profile.email, displayName: profile.name)
                    } else {
                        try? await cloudKitService.syncCurrentUser()
                    }
                }
            }
            .navigationTitle("Social")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenAddFriendWithEmail"))) { notification in
                if let email = notification.userInfo?["email"] as? String {
                    friendEmailToAdd = email
                    showingAddFriend = true
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendSheet(initialEmail: friendEmailToAdd)
                    .onDisappear {
                        friendEmailToAdd = nil
                    }
            }
        }
        .onAppear {
            if let _ = cloudKitService.currentUser {
                Task {
                    _ = try? await cloudKitService.fetchFriends()
                    _ = try? await cloudKitService.fetchFriendRequests()
                    _ = try? await cloudKitService.fetchSharedItems()
                }
            }
        }
    }
    
    // Helper function to generate invite link
    private func generateInviteLink() -> URL {
        // Create custom scheme link for direct app opening
        let email = cloudKitService.currentUser?.email ?? profiles.first?.email ?? ""
        let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Use custom scheme: clarity://add-friend
        return URL(string: "clarity://add-friend?email=\(encodedEmail)")!
    }
}

struct FriendStatusHeader: View {
    @StateObject private var cloudKitService = CloudKitService.shared
    @State private var selectedFriend: FriendshipRecord?
    @State private var showPrivacySettings = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Friends")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !cloudKitService.friends.isEmpty {
                    Text("Tap circles for privacy")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    // Me
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color.clarityBlue.opacity(0.3), lineWidth: 3)
                                .frame(width: 64, height: 64)
                            
                            AsyncImage(url: URL(string: cloudKitService.currentUser?.photoURL ?? "")) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                        }
                        Text("You")
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                    
                    // Friends
                    ForEach(cloudKitService.friends) { friend in
                        Button {
                            selectedFriend = friend
                            showPrivacySettings = true
                        } label: {
                            VStack(spacing: 8) {
                                ZStack(alignment: .topTrailing) {
                                    Circle()
                                        .stroke(.gray.opacity(0.3), lineWidth: 3)
                                        .frame(width: 64, height: 64)
                                    
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.gray)
                                        .font(.title3)
                                        .frame(width: 56, height: 56)
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(Circle())
                                    
                                    // Privacy indicator
                                    if !friend.isActivityShared {
                                        Image(systemName: "eye.slash.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white)
                                            .padding(5)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                            .offset(x: 4, y: -4)
                                    }
                                }
                                Text(friend.friendDisplayName ?? "Friend")
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .frame(width: 70)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)  // Add padding to prevent edge clipping
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
        .sheet(isPresented: $showPrivacySettings) {
            if let friend = selectedFriend {
                FriendPrivacySheet(friend: friend)
            }
        }
    }
}

struct EmptyFriendState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundStyle(Color.clarityBlue.opacity(0.5))
            
            Text("No Friends Yet")
                .font(.headline)
            
            Text("Add friends to see their activity and share your progress")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
        .padding(.top, 40)
    }
}

struct ActivityFeedView: View {
    @State private var activities: [SocialActivityRecord] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Latest Activity")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(activities) { activity in
                HStack(spacing: 12) {
                    Image(systemName: activity.iconName ?? "star.fill")
                        .font(.title2)
                        .foregroundStyle(Color.clarityBlue)
                        .frame(width: 40, height: 40)
                        .background(Color.clarityBlue.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activity.userDisplayName ?? "Unknown")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("completed **\(activity.title)**")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(activity.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .task {
            if let feed = try? await CloudKitService.shared.fetchFeed() {
                self.activities = feed
            }
        }
    }
}

// MARK: - Friend Request Row
struct FriendRequestRow: View {
    let request: FriendRequestRecord
    @StateObject private var cloudKitService = CloudKitService.shared
    @State private var isProcessing = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture
            ZStack {
                Circle()
                    .fill(Color.clarityBlue.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "person.fill")
                    .foregroundStyle(Color.clarityBlue)
            }
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(request.fromUserDisplayName ?? "Clarity User")
                    .font(.headline)
                Text(request.fromUserEmail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                // Accept Button
                Button {
                    acceptRequest()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.green)
                        .clipShape(Circle())
                }
                
                // Decline Button
                Button {
                    declineRequest()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(Color.clarityCard)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func acceptRequest() {
        isProcessing = true
        Task {
            try? await cloudKitService.acceptFriendRequest(request)
            isProcessing = false
        }
    }
    
    private func declineRequest() {
        // TODO: Implement decline functionality
        isProcessing = true
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            isProcessing = false
        }
    }
}
