import SwiftUI

struct FriendPrivacySheet: View {
    let friend: FriendshipRecord
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudKitService = CloudKitService.shared
    
    @State private var shareClarityScore: Bool
    @State private var shareTasks: Bool
    @State private var shareHabits: Bool
    @State private var shareMoments: Bool
    @State private var isSaving = false
    
    init(friend: FriendshipRecord) {
        self.friend = friend
        _shareClarityScore = State(initialValue: friend.shareClarityScore)
        _shareTasks = State(initialValue: friend.shareTasks)
        _shareHabits = State(initialValue: friend.shareHabits)
        _shareMoments = State(initialValue: friend.shareMoments)
    }
    
    private var hasChanges: Bool {
        shareClarityScore != friend.shareClarityScore ||
        shareTasks != friend.shareTasks ||
        shareHabits != friend.shareHabits ||
        shareMoments != friend.shareMoments
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        // Friend Avatar
                        ZStack {
                            Circle()
                                .fill(Color.clarityBlue.opacity(0.2))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "person.fill")
                                .foregroundStyle(Color.clarityBlue)
                                .font(.title2)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(friend.friendDisplayName ?? "Friend")
                                .font(.title3.bold())
                            Text(friend.friendEmail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    Text("Choose what \(friend.friendDisplayName ?? "this friend") can see")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Sharing Preferences")
                }
                
                Section {
                    Toggle(isOn: $shareClarityScore) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clarity Score")
                                    .foregroundStyle(.primary)
                                Text("Overall daily score")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(Color.clarityPurple)
                        }
                    }
                    .tint(Color.clarityBlue)
                    
                    Toggle(isOn: $shareTasks) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tasks")
                                    .foregroundStyle(.primary)
                                Text("Completed task activity")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.clarityBlue)
                        }
                    }
                    .tint(Color.clarityBlue)
                    
                    Toggle(isOn: $shareHabits) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Habits")
                                    .foregroundStyle(.primary)
                                Text("Habit streaks & check-ins")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(Color.clarityOrange)
                        }
                    }
                    .tint(Color.clarityBlue)
                    
                    Toggle(isOn: $shareMoments) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Moments")
                                    .foregroundStyle(.primary)
                                Text("Journal entries & moods")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.clarityTeal)
                        }
                    }
                    .tint(Color.clarityBlue)
                }
                
                Section {
                    Button(role: .destructive) {
                        // TODO: Add unfriend functionality
                    } label: {
                        Label("Remove Friend", systemImage: "person.badge.minus")
                    }
                }
            }
            .navigationTitle("Privacy Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Save") {
                            savePrivacySettings()
                        }
                        .disabled(!hasChanges)
                    }
                }
            }
        }
    }
    
    private func savePrivacySettings() {
        isSaving = true
        Task {
            try? await cloudKitService.updateFriendPrivacy(
                friendRecordID: friend.recordID,
                shareClarityScore: shareClarityScore,
                shareTasks: shareTasks,
                shareHabits: shareHabits,
                shareMoments: shareMoments
            )
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}
