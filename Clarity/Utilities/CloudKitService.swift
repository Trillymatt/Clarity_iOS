import Foundation
import CloudKit
import Combine

/// Manages CloudKit operations for social features
class CloudKitService: ObservableObject {
    static let shared = CloudKitService()
    
    // Lazy initialization - won't create container until actually used
    private lazy var container: CKContainer = {
        CKContainer(identifier: "iCloud.mattknorman.Clarity")
    }()
    
    private lazy var publicDatabase: CKDatabase = {
        container.publicCloudDatabase
    }()
    
    private lazy var privateDatabase: CKDatabase = {
        container.privateCloudDatabase
    }()
    
    @Published var currentUser: ClarityUserRecord?
    @Published var friends: [FriendshipRecord] = []
    @Published var friendRequests: [FriendRequestRecord] = []
    @Published var sharedItems: [SharedItemRecord] = []
    @Published var syncError: String?
    @Published var isSyncing: Bool = false
    
    // Development mode - allows bypassing CloudKit on simulators
    #if targetEnvironment(simulator)
    @Published var isDevelopmentMode: Bool = false
    #endif
    
    private init() {
        // Empty init - container created lazily when first accessed
    }
    
    // MARK: - User Management
    
    /// Sync current user to CloudKit
    func syncCurrentUser(email: String? = nil, displayName: String? = nil) async throws {
        await MainActor.run {
            self.isSyncing = true
            self.syncError = nil
        }
        
        do {
            // First check if the user is even signed into iCloud
            let accountStatus = try await container.accountStatus()
            
            // Log the actual status for debugging
            print("CloudKit Account Status: \(accountStatus.rawValue)")
            
            switch accountStatus {
            case .noAccount:
                throw NSError(domain: "CloudKit", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Not signed into iCloud. Sign in via Settings → [Your Name]."
                ])
            case .restricted:
                throw NSError(domain: "CloudKit", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "iCloud access is restricted on this device."
                ])
            case .couldNotDetermine:
                // This often happens on simulators or when container doesn't exist
                print("⚠️ CloudKit status: couldNotDetermine - likely container doesn't exist or simulator issue")
                throw NSError(domain: "CloudKit", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "CloudKit container 'iCloud.mattknorman.Clarity' may not exist. Create it in Apple Developer Portal or Xcode → Signing & Capabilities → CloudKit Dashboard."
                ])
            case .available:
                print("✅ CloudKit account is available, proceeding with sync...")
                break // Continue with sync
            @unknown default:
                print("⚠️ Unknown CloudKit account status: \(accountStatus.rawValue)")
                // Treat as couldNotDetermine
                throw NSError(domain: "CloudKit", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "CloudKit container 'iCloud.mattknorman.Clarity' may not exist. Create it in Apple Developer Portal or test on a real device."
                ])
            }
            
            // Add timeout to prevent infinite hanging
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await self.performSync(email: email, displayName: displayName)
                }
                
                group.addTask {
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    throw NSError(domain: "CloudKit", code: 408, userInfo: [
                        NSLocalizedDescriptionKey: "Connection timed out. Please check your iCloud settings."
                    ])
                }
                
                // Wait for the first task to complete (either sync or timeout)
                try await group.next()
                group.cancelAll()
            }
            
            await MainActor.run {
                self.isSyncing = false
                print("✅ CloudKit sync completed successfully")
            }
        } catch {
            await MainActor.run {
                self.isSyncing = false
                
                // Log error for debugging
                print("❌ CloudKit Sync Error: \(error)")
                print("Error details: \(error.localizedDescription)")
                
                // Provide user-friendly error messages
                if let ckError = error as? CKError {
                    print("CKError code: \(ckError.code.rawValue)")
                    switch ckError.code {
                    case .notAuthenticated:
                        self.syncError = "Please sign in to iCloud in Settings to use social features."
                    case .networkUnavailable, .networkFailure:
                        self.syncError = "No internet connection. Please check your network."
                    case .serverRejectedRequest:
                        self.syncError = "iCloud is unavailable. Please try again later."
                    case .permissionFailure:
                        self.syncError = "CloudKit permissions not configured. This feature requires CloudKit setup in Apple Developer."
                    default:
                        self.syncError = "iCloud sync failed: \(ckError.localizedDescription)"
                    }
                } else {
                    self.syncError = error.localizedDescription
                }
            }
            throw error
        }
    }
    
    private func performSync(email: String?, displayName: String?) async throws {
        // Get the current user's iCloud record ID
        let userRecordID = try await container.userRecordID()
        
        // Fetch or create user record
        let record: CKRecord
        do {
            record = try await publicDatabase.record(for: userRecordID)
        } catch {
            // Create new user record if doesn't exist
            record = CKRecord(recordType: "ClarityUser", recordID: userRecordID)
            record["joinedDate"] = Date()
        }
        
        // Update user record with provided data
        if let email = email {
            record["email"] = email.lowercased()
        }
        if let displayName = displayName {
            record["displayName"] = displayName
        }
        
        // If we have existing data in the record, prefer that if inputs are nil
        // But for this app, we trust the local inputs more as they come from Auth
        
        _ = try await publicDatabase.save(record)
        
        // Convert to our model
        await MainActor.run {
            self.currentUser = ClarityUserRecord(record: record)
        }
    }
    
    /// Search for users by email
    func searchUsers(email: String) async throws -> [ClarityUserRecord] {
        let predicate = NSPredicate(format: "email == %@", email.lowercased())
        let query = CKQuery(recordType: "ClarityUser", predicate: predicate)
        
        let results = try await publicDatabase.records(matching: query)
        
        return results.matchResults.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return ClarityUserRecord(record: record)
        }
    }
    
    /// Search for multiple users by email (batch lookup)
    func findUsers(byEmails emails: [String]) async throws -> [ClarityUserRecord] {
        guard !emails.isEmpty else { return [] }
        
        // CloudKit has limits, so we'll batch in chunks of 50
        let chunkSize = 50
        var allUsers: [ClarityUserRecord] = []
        
        for chunk in emails.chunked(into: chunkSize) {
            let predicate = NSPredicate(format: "email IN %@", chunk)
            let query = CKQuery(recordType: "ClarityUser", predicate: predicate)
            
            let results = try await publicDatabase.records(matching: query)
            
            let users = results.matchResults.compactMap { _, result -> ClarityUserRecord? in
                guard case .success(let record) = result else { return nil }
                return ClarityUserRecord(record: record)
            }
            
            allUsers.append(contentsOf: users)
        }
        
        return allUsers
    }
    
    // MARK: - Friend Management
    
    /// Send a friend request
    func sendFriendRequest(to user: ClarityUserRecord) async throws {
        guard let currentUser = currentUser else {
            throw CKError(.notAuthenticated)
        }
        
        // Check if already friends
        if friends.contains(where: { $0.friendUserId == user.userId }) {
            throw NSError(domain: "CloudKit", code: 400, userInfo: [NSLocalizedDescriptionKey: "Already friends"])
        }
        
        let record = CKRecord(recordType: "FriendRequest")
        record["fromUserId"] = currentUser.userId
        record["fromUserEmail"] = currentUser.email
        record["fromUserDisplayName"] = currentUser.displayName
        record["toUserId"] = user.userId
        record["toUserEmail"] = user.email
        record["status"] = "pending"
        record["timestamp"] = Date()
        
        _ = try await privateDatabase.save(record)
    }
    
    /// Accept a friend request
    func acceptFriendRequest(_ request: FriendRequestRecord) async throws {
        guard currentUser != nil else {
            throw CKError(.notAuthenticated)
        }
        
        // Update request status
        let requestRecord = try await privateDatabase.record(for: request.recordID)
        requestRecord["status"] = "accepted"
        _ = try await privateDatabase.save(requestRecord)
        
        // Create friendship for current user
        let myFriendship = CKRecord(recordType: "Friendship")
        myFriendship["friendUserId"] = request.fromUserId
        myFriendship["friendEmail"] = request.fromUserEmail
        myFriendship["friendDisplayName"] = request.fromUserDisplayName
        myFriendship["since"] = Date()
        
        _ = try await privateDatabase.save(myFriendship)
        
        // Reload friends list
        try await fetchFriends()
    }
    
    /// Fetch all friends
    func fetchFriends() async throws {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Friendship", predicate: predicate)
        
        let results = try await privateDatabase.records(matching: query)
        
        let friendships = results.matchResults.compactMap { _, result -> FriendshipRecord? in
            guard case .success(let record) = result else { return nil }
            return FriendshipRecord(record: record)
        }
        
        await MainActor.run {
            self.friends = friendships
        }
    }
    
    /// Update privacy settings for a specific friend
    func updateFriendPrivacy(
        friendRecordID: CKRecord.ID,
        shareClarityScore: Bool,
        shareTasks: Bool,
        shareHabits: Bool,
        shareMoments: Bool
    ) async throws {
        let record = try await privateDatabase.record(for: friendRecordID)
        record["shareClarityScore"] = shareClarityScore as CKRecordValue
        record["shareTasks"] = shareTasks as CKRecordValue
        record["shareHabits"] = shareHabits as CKRecordValue
        record["shareMoments"] = shareMoments as CKRecordValue
        _ = try await privateDatabase.save(record)
        
        // Refresh friends list to update local state
        try await fetchFriends()
    }
    
    /// Fetch pending friend requests
    func fetchFriendRequests() async throws {
        guard currentUser != nil else { return }
        
        // Fetch requests sent TO me which are pending
        let predicate = NSPredicate(format: "toUserId == %@ AND status == 'pending'", self.currentUser!.userId)
        let query = CKQuery(recordType: "FriendRequest", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let results = try await privateDatabase.records(matching: query)
        
        let requests = results.matchResults.compactMap { _, result -> FriendRequestRecord? in
            guard case .success(let record) = result else { return nil }
            return FriendRequestRecord(record: record)
        }
        
        await MainActor.run {
            self.friendRequests = requests
        }
    }
    
    // MARK: - Shared Items (Accountability)
    
    /// Share a task or habit with a friend
    func shareItem(
        itemType: String,
        itemId: String,
        itemTitle: String,
        withFriend friend: FriendshipRecord
    ) async throws {
        guard let currentUser = currentUser else {
            throw CKError(.notAuthenticated)
        }
        
        let record = CKRecord(recordType: "SharedItem")
        record["itemType"] = itemType
        record["itemId"] = itemId
        record["itemTitle"] = itemTitle
        record["ownerId"] = currentUser.userId
        record["ownerEmail"] = currentUser.email
        record["partnerId"] = friend.friendUserId
        record["partnerEmail"] = friend.friendEmail
        record["createdDate"] = Date()
        record["ownerCompleted"] = false
        record["partnerCompleted"] = false
        record["lastUpdated"] = Date()
        
        _ = try await privateDatabase.save(record)
        
        // Refresh shared items
        try await fetchSharedItems()
    }
    
    /// Update completion status for a shared item
    func updateSharedItemCompletion(recordID: CKRecord.ID, isCompleted: Bool, isOwner: Bool) async throws {
        let record = try await privateDatabase.record(for: recordID)
        
        if isOwner {
            record["ownerCompleted"] = isCompleted
        } else {
            record["partnerCompleted"] = isCompleted
        }
        record["lastUpdated"] = Date()
        
        _ = try await privateDatabase.save(record)
        
        // Refresh shared items
        try await fetchSharedItems()
    }
    
    /// Fetch all shared items (both owned and partnered)
    func fetchSharedItems() async throws {
        guard let currentUser = currentUser else { return }
        
        // Fetch items where I'm the owner OR the partner
        let ownerPredicate = NSPredicate(format: "ownerId == %@", currentUser.userId)
        let partnerPredicate = NSPredicate(format: "partnerId == %@", currentUser.userId)
        let combinedPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [ownerPredicate, partnerPredicate])
        
        let query = CKQuery(recordType: "SharedItem", predicate: combinedPredicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
        
        let results = try await privateDatabase.records(matching: query)
        
        let items = results.matchResults.compactMap { _, result -> SharedItemRecord? in
            guard case .success(let record) = result else { return nil }
            return SharedItemRecord(record: record)
        }
        
        await MainActor.run {
            self.sharedItems = items
        }
    }
    
    // MARK: - Activity Feed
    
    /// Post an activity
    func postActivity(type: String, title: String, iconName: String? = nil, value: Int? = nil) async {
        guard currentUser != nil else { return }
        
        let record = CKRecord(recordType: "SocialActivity")
        record["type"] = type
        record["title"] = title
        record["iconName"] = iconName
        record["timestamp"] = Date()
        if let value = value {
            record["value"] = value as CKRecordValue
        }
        
        _ = try? await publicDatabase.save(record)
    }
    
    /// Fetch activity feed from friends
    func fetchFeed() async throws -> [SocialActivityRecord] {
        guard !friends.isEmpty else { return [] }
        
        // Get friend user IDs (limited to 10 for CloudKit query)
        let friendIds = Array(friends.prefix(10).map { $0.friendUserId })
        
        // Query activities created by friends
        let predicate = NSPredicate(format: "creatorUserRecordID IN %@", friendIds)
        let query = CKQuery(recordType: "SocialActivity", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let results = try await publicDatabase.records(matching: query, desiredKeys: nil, resultsLimit: 20)
        
        return results.matchResults.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return SocialActivityRecord(record: record)
        }
    }
}

// MARK: - CloudKit Record Models

struct ClarityUserRecord: Identifiable {
    let id: String
    let userId: String
    let email: String
    let displayName: String?
    let photoURL: String?
    let joinedDate: Date
    
    init(record: CKRecord) {
        self.id = record.recordID.recordName
        self.userId = record.recordID.recordName
        self.email = record["email"] as? String ?? ""
        self.displayName = record["displayName"] as? String
        self.photoURL = record["photoURL"] as? String
        self.joinedDate = record["joinedDate"] as? Date ?? Date()
    }
    
    // Manual initializer for development/testing
    init(id: String, userId: String, email: String, displayName: String?, photoURL: String?, joinedDate: Date) {
        self.id = id
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.joinedDate = joinedDate
    }
}

struct FriendshipRecord: Identifiable {
    let id: String
    let recordID: CKRecord.ID
    let friendUserId: String
    let friendEmail: String
    let friendDisplayName: String?
    let since: Date
    
    // Granular sharing controls
    var shareClarityScore: Bool
    var shareTasks: Bool
    var shareHabits: Bool
    var shareMoments: Bool
    
    var isActivityShared: Bool {
        // Helper computed property - true if ANY sharing is enabled
        shareClarityScore || shareTasks || shareHabits || shareMoments
    }
    
    init(record: CKRecord) {
        self.id = record.recordID.recordName
        self.recordID = record.recordID
        self.friendUserId = record["friendUserId"] as? String ?? ""
        self.friendEmail = record["friendEmail"] as? String ?? ""
        self.friendDisplayName = record["friendDisplayName"] as? String
        self.since = record["since"] as? Date ?? Date()
        
        // Default all to true for existing friendships
        self.shareClarityScore = record["shareClarityScore"] as? Bool ?? true
        self.shareTasks = record["shareTasks"] as? Bool ?? true
        self.shareHabits = record["shareHabits"] as? Bool ?? true
        self.shareMoments = record["shareMoments"] as? Bool ?? true
    }
}

struct FriendRequestRecord: Identifiable {
    let id: String
    let recordID: CKRecord.ID
    let fromUserId: String
    let fromUserEmail: String
    let fromUserDisplayName: String?
    let toUserId: String
    let toUserEmail: String
    let status: String
    let timestamp: Date
    
    init(record: CKRecord) {
        self.id = record.recordID.recordName
        self.recordID = record.recordID
        self.fromUserId = record["fromUserId"] as? String ?? ""
        self.fromUserEmail = record["fromUserEmail"] as? String ?? ""
        self.fromUserDisplayName = record["fromUserDisplayName"] as? String
        self.toUserId = record["toUserId"] as? String ?? ""
        self.toUserEmail = record["toUserEmail"] as? String ?? ""
        self.status = record["status"] as? String ?? "pending"
        self.timestamp = record["timestamp"] as? Date ?? Date()
    }
}

struct SocialActivityRecord: Identifiable {
    let id: String
    let userDisplayName: String?
    let type: String
    let title: String
    let iconName: String?
    let timestamp: Date
    let value: Int?
    
    init(record: CKRecord) {
        self.id = record.recordID.recordName
        self.userDisplayName = record.creatorUserRecordID?.recordName // You'll map this to actual display name
        self.type = record["type"] as? String ?? ""
        self.title = record["title"] as? String ?? ""
        self.iconName = record["iconName"] as? String
        self.timestamp = record["timestamp"] as? Date ?? Date()
        self.value = record["value"] as? Int
    }
}

// MARK: - Shared Item for Accountability
struct SharedItemRecord: Identifiable {
    let id: String
    let recordID: CKRecord.ID
    let itemType: String  // "task" or "habit"
    let itemId: String    // UUID of the task/habit
    let itemTitle: String
    let ownerId: String
    let ownerEmail: String
    let partnerId: String
    let partnerEmail: String
    let createdDate: Date
    var ownerCompleted: Bool
    var partnerCompleted: Bool
    var lastUpdated: Date
    
    init(record: CKRecord) {
        self.id = record.recordID.recordName
        self.recordID = record.recordID
        self.itemType = record["itemType"] as? String ?? ""
        self.itemId = record["itemId"] as? String ?? ""
        self.itemTitle = record["itemTitle"] as? String ?? ""
        self.ownerId = record["ownerId"] as? String ?? ""
        self.ownerEmail = record["ownerEmail"] as? String ?? ""
        self.partnerId = record["partnerId"] as? String ?? ""
        self.partnerEmail = record["partnerEmail"] as? String ?? ""
        self.createdDate = record["createdDate"] as? Date ?? Date()
        self.ownerCompleted = record["ownerCompleted"] as? Bool ?? false
        self.partnerCompleted = record["partnerCompleted"] as? Bool ?? false
        self.lastUpdated = record["lastUpdated"] as? Date ?? Date()
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
