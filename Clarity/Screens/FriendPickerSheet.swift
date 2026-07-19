import SwiftUI

struct FriendPickerSheet: View {
    let itemType: String
    let itemId: String
    let itemTitle: String
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudKitService = CloudKitService.shared
    @State private var isSharing = false
    @State private var selectedFriend: FriendshipRecord?
    
    var body: some View {
        NavigationStack {
            List {
                if cloudKitService.friends.isEmpty {
                    ContentUnavailableView(
                        "No Friends",
                        systemImage: "person.2.slash",
                        description: Text("Add friends to share this \(itemType) with them")
                    )
                } else {
                    Section {
                        ForEach(cloudKitService.friends) { friend in
                            Button {
                                shareWithFriend(friend)
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.clarityBlue.opacity(0.2))
                                            .frame(width: 40, height: 40)
                                        
                                        Image(systemName: "person.fill")
                                            .foregroundStyle(Color.clarityBlue)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(friend.friendDisplayName ?? "Friend")
                                            .font(.headline)
                                        Text(friend.friendEmail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if isSharing && selectedFriend?.id == friend.id {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .disabled(isSharing)
                        }
                    } header: {
                        Text("Choose an accountability partner")
                    }
                }
            }
            .navigationTitle("Share \(itemType.capitalized)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func shareWithFriend(_ friend: FriendshipRecord) {
        selectedFriend = friend
        isSharing = true
        
        Task {
            try? await cloudKitService.shareItem(
                itemType: itemType,
                itemId: itemId,
                itemTitle: itemTitle,
                withFriend: friend
            )
            
            await MainActor.run {
                isSharing = false
                dismiss()
            }
        }
    }
}
