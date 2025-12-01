import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    let userEmail: String
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeeklyReview.date, order: .reverse) private var weeklyReviews: [WeeklyReview]
    
    @State private var isEditing = false
    @State private var editName = ""
    @State private var editEmail = ""
    @State private var showWeeklyReview = false
    
    @StateObject private var notificationSettings = NotificationSettings.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    init(userEmail: String) {
        self.userEmail = userEmail
        _profiles = Query(filter: #Predicate { $0.email == userEmail })
        _weeklyReviews = Query(filter: #Predicate { $0.ownerEmail == userEmail }, sort: \WeeklyReview.date, order: .reverse)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header Section
                        headerSection
                        
                        if !isEditing {
                            // Notification Settings
                            notificationSettingsSection
                            
                            // Weekly Review Button
                            weeklyReviewButton
                            
                            // Weekly Clarity Archive
                            weeklyClaritySection
                            
                            // Sign Out
                            signOutButton
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(isEditing ? "Edit Profile" : "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showWeeklyReview) {
                WeeklyReviewView(userEmail: userEmail)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !isEditing {
                        Button("Done") { dismiss() }
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        Button("Cancel") {
                            withAnimation { isEditing = false }
                        }
                    }
                }
            }
            .onAppear {
                if let profile = profiles.first {
                    editName = profile.name
                    editEmail = profile.email
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundStyle(LinearGradient.clarityPrimary)
                    .background(Circle().fill(Color.clarityCard))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                if !isEditing {
                    Button(action: {
                        withAnimation { isEditing = true }
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title)
                            .foregroundStyle(Color.clarityBlue)
                            .background(Circle().fill(Color.white).padding(2))
                    }
                }
            }
            
            if isEditing {
                VStack(spacing: 16) {
                    CustomTextField(icon: "person.fill", placeholder: "Name", text: $editName)
                    CustomTextField(icon: "envelope.fill", placeholder: "Email", text: $editEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .disabled(true) // Email usually shouldn't be changed easily as it's the ID
                        .opacity(0.6)
                    
                    Button(action: saveProfile) {
                        Text("Save Changes")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clarityBlue)
                            .foregroundStyle(.white)
                            .font(.headline)
                            .cornerRadius(12)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    Text(profiles.first?.name ?? "User")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    
                    Text(profiles.first?.email ?? userEmail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 20)
    }
    
    private var weeklyClaritySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .foregroundStyle(Color.clarityPurple)
                Text("Weekly Clarity Archive")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            if weeklyReviews.isEmpty {
                Text("No weekly reviews yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                    .background(Color.clarityCard)
                    .cornerRadius(12)
                    .padding(.horizontal)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(weeklyReviews) { review in
                        NavigationLink(destination: WeeklyReviewDetailView(review: review)) {
                            WeeklyReviewCard(review: review)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var weeklyReviewButton: some View {
        Button(action: { showWeeklyReview = true }) {
            HStack {
                Image(systemName: "text.book.closed.fill")
                    .font(.title3)
                Text("Start Weekly Review")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.clarityBlue, Color.clarityPurple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.clarityBlue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
    }
    
    private var signOutButton: some View {
        Button(action: {
            // Clear session
            AuthManager.shared.logout()
            
            // Dismiss profile view
            dismiss()
            
            // Force app to restart by exiting to root
            // This triggers AuthGate to re-evaluate since session is cleared
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController = UIHostingController(rootView: ContentView())
                window.makeKeyAndVisible()
            }
        }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
            }
            .foregroundStyle(.red)
            .font(.subheadline.bold())
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    private var notificationSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundStyle(Color.clarityBlue)
                Text("Notifications")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                // Permission Status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notification Permissions")
                            .font(.subheadline.bold())
                        Text(notificationManager.isAuthorized ? "Enabled" : "Disabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if !notificationManager.isAuthorized {
                        Button("Open Settings") {
                            notificationManager.openSettings()
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.clarityBlue)
                        .cornerRadius(8)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding()
                .background(Color.clarityCard)
                .cornerRadius(12)
                
                // Mood Check-in Toggle
                Toggle(isOn: $notificationSettings.moodCheckInEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Mood Check-in")
                            .font(.subheadline.bold())
                        Text("8:00 PM every day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Color.clarityBlue)
                .padding()
                .background(Color.clarityCard)
                .cornerRadius(12)
                .disabled(!notificationManager.isAuthorized)
                .opacity(notificationManager.isAuthorized ? 1 : 0.6)
                
                // Weekly Review Toggle
                Toggle(isOn: $notificationSettings.weeklyReviewEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weekly Review Reminder")
                            .font(.subheadline.bold())
                        Text("Sunday at 6:00 PM")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Color.clarityBlue)
                .padding()
                .background(Color.clarityCard)
                .cornerRadius(12)
                .disabled(!notificationManager.isAuthorized)
                .opacity(notificationManager.isAuthorized ? 1 : 0.6)
            }
            .padding(.horizontal)
        }
    }
    
    private func saveProfile() {
        if let profile = profiles.first {
            profile.name = editName
            // profile.email = editEmail // Email change might require more logic
            try? context.save()
        }
        withAnimation { isEditing = false }
    }
}

struct WeeklyReviewCard: View {
    let review: WeeklyReview
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(dateString(for: review.date))
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(index < review.weekRating ? Color.clarityYellow : Color.gray.opacity(0.3))
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.clarityCard)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Week of " + formatter.string(from: date)
    }
}

struct WeeklyReviewDetailView: View {
    let review: WeeklyReview
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Weekly Review")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    Text(dateString(for: review.date))
                        .font(.title2.bold())
                }
                .padding(.top)
                
                // Rating
                HStack(spacing: 8) {
                    ForEach(0..<5) { index in
                        Image(systemName: "star.fill")
                            .font(.title3)
                            .foregroundStyle(index < review.weekRating ? Color.clarityYellow : Color.gray.opacity(0.3))
                    }
                }
                .padding(.bottom)
                
                // Content Sections
                Group {
                    detailSection(title: "Wins", icon: "trophy.fill", color: .clarityYellow, content: review.wins)
                    detailSection(title: "Challenges", icon: "exclamationmark.triangle.fill", color: .clarityPink, content: review.challenges)
                    detailSection(title: "Learnings", icon: "lightbulb.fill", color: .clarityBlue, content: review.learnings)
                    detailSection(title: "Improvements", icon: "arrow.up.circle.fill", color: .clarityGreen, content: review.improvements)
                }
                
                if !review.topGoals.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Top Goals", systemImage: "target")
                            .font(.headline)
                            .foregroundStyle(Color.clarityPurple)
                        
                        ForEach(review.topGoals, id: \.self) { goal in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                Text(goal)
                            }
                            .font(.body)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.clarityCard)
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.clarityBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func detailSection(title: String, icon: String, color: Color, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
            
            Text(content.isEmpty ? "No entry" : content)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clarityCard)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
