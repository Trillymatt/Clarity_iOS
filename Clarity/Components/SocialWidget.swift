import SwiftUI
import CloudKit

struct SocialWidget: View {
    @ObservedObject var cloudKitService = CloudKitService.shared
    var action: () -> Void
    
    @State private var latestActivity: SocialActivityRecord?
    
    var requestCount: Int {
        cloudKitService.friendRequests.count
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon Request Indicator
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.clarityBlue)
                        .padding(12)
                        .background(Color.clarityBlue.opacity(0.1))
                        .clipShape(Circle())
                    
                    if requestCount > 0 {
                        Text("\(requestCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Social")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if requestCount > 0 {
                        Text("\(requestCount) pending request\(requestCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if let activity = latestActivity {
                        // Show latest friend activity
                        HStack(spacing: 4) {
                            if let icon = activity.iconName {
                                Image(systemName: icon)
                                    .font(.caption2)
                            }
                            Text("**\(activity.userDisplayName ?? "Friend")** \(activity.title)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("Connect with friends")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Friend Avatars Stack
                if !cloudKitService.friends.isEmpty {
                    HStack(spacing: -10) {
                        ForEach(Array(cloudKitService.friends.prefix(3).enumerated()), id: \.offset) { index, friend in
                            ZStack {
                                Circle()
                                    .fill(Color.clarityBlue.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(Color.clarityCard, lineWidth: 2))
                                
                                Text(friend.friendDisplayName?.prefix(1).uppercased() ?? "?")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.clarityBlue)
                            }
                            .zIndex(Double(3 - index))
                        }
                        
                        if cloudKitService.friends.count > 3 {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(Color.clarityCard, lineWidth: 2))
                                
                                Text("+\(cloudKitService.friends.count - 3)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .zIndex(-1)
                        }
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.clarityCard)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .task {
            // Fetch data on appear
            Task {
                try? await cloudKitService.fetchFriends()
                try? await cloudKitService.fetchFriendRequests()
                if let feed = try? await cloudKitService.fetchFeed() {
                    await MainActor.run {
                        self.latestActivity = feed.first
                    }
                }
            }
        }
    }
}
