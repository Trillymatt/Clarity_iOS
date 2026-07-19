import SwiftUI

struct SharedItemsView: View {
    @StateObject private var cloudKitService = CloudKitService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if cloudKitService.sharedItems.isEmpty {
                EmptySharedItemsState()
            } else {
                Text("Shared with Friends")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                ForEach(cloudKitService.sharedItems) { item in
                    SharedItemRow(item: item)
                }
            }
        }
    }
}

struct SharedItemRow: View {
    let item: SharedItemRecord
    @StateObject private var cloudKitService = CloudKitService.shared
    
    var isOwner: Bool {
        item.ownerId == cloudKitService.currentUser?.userId
    }
    
    var partnerName: String {
        if isOwner {
            return item.partnerEmail.components(separatedBy: "@").first?.capitalized ?? "Partner"
        } else {
            return item.ownerEmail.components(separatedBy: "@").first?.capitalized ?? "Partner"
        }
    }
    
    var myCompleted: Bool {
        isOwner ? item.ownerCompleted : item.partnerCompleted
    }
    
    var theirCompleted: Bool {
        isOwner ? item.partnerCompleted : item.ownerCompleted
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label(item.itemTitle, systemImage: item.itemType == "task" ? "checkmark.circle" : "flame")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(item.itemType.capitalized)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(item.itemType == "task" ? Color.clarityBlue : Color.clarityOrange)
                    .cornerRadius(4)
            }
            
            // Progress indicators
            HStack(spacing: 20) {
                // Me
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(myCompleted ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: myCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(myCompleted ? Color.green : Color.gray)
                            .font(.title3)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You")
                            .font(.caption.bold())
                        Text(myCompleted ? "Completed" : "Pending")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Connection line
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                    .frame(maxWidth: 40)
                
                // Partner
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(theirCompleted ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: theirCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(theirCompleted ? Color.green : Color.gray)
                            .font(.title3)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(partnerName)
                            .font(.caption.bold())
                        Text(theirCompleted ? "Completed" : "Pending")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.clarityCard)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct EmptySharedItemsState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundStyle(Color.clarityBlue.opacity(0.5))
            
            Text("No Shared Items Yet")
                .font(.headline)
            
            Text("Share tasks or habits with friends to hold each other accountable")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.clarityCard.opacity(0.5))
        .cornerRadius(12)
    }
}
