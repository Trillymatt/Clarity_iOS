import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context

    let userEmail: String
    var onStartWalkthrough: (() -> Void)? = nil
    @Query private var profiles: [UserProfile]
    
    @State private var showEditProfile = false
    @State private var showCreateBudget = false
    @State private var showEditBudget = false
    @State private var showDailyReview = false
    @State private var showWeeklyReview = false
    @State private var exportURL: URL?
    
    init(userEmail: String, onStartWalkthrough: (() -> Void)? = nil) {
        self.userEmail = userEmail
        self.onStartWalkthrough = onStartWalkthrough
        _profiles = Query(filter: #Predicate { $0.email == userEmail })
    }
    
    var userName: String {
        profiles.first?.name ?? "User"
    }
    
    var currentEmail: String {
        profiles.first?.email ?? userEmail
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Header Section
                Section {
                    HStack(spacing: 16) {
                        if let profile = profiles.first,
                           let data = profile.profileImageData,
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundStyle(LinearGradient.clarityPrimary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(userName)
                                .font(.title3.bold())
                            
                            Text(currentEmail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            showEditProfile = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.clarityBlue)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Settings Section
                Section("Settings") {
                    NavigationLink {
                        NotificationsSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell.fill")
                            .foregroundStyle(.primary)
                    }
                    
                    NavigationLink {
                        DashboardCustomizationView()
                    } label: {
                        Label("Customize Dashboard", systemImage: "rectangle.3.group.fill")
                            .foregroundStyle(.primary)
                    }
                    
                    NavigationLink {
                        ClarityScoreSettingsView()
                    } label: {
                        Label("Clarity Score Settings", systemImage: "slider.horizontal.3")
                            .foregroundStyle(.primary)
                    }
                }
                
                // Privacy Section
                Section("Privacy") {
                    Toggle(isOn: Binding(
                        get: { UserDefaults.standard.bool(forKey: "shareActivityWithFriends") },
                        set: { UserDefaults.standard.set($0, forKey: "shareActivityWithFriends") }
                    )) {
                        Label("Share Activity with Friends", systemImage: "person.2.fill")
                            .foregroundStyle(.primary)
                    }
                    .tint(Color.clarityBlue)
                    
                    Text("When enabled, your completed tasks and habits will be visible to your friends on their activity feed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Reviews Section
                Section("Reviews") {
                    
                    // Replay App Tutorial
                    Button {
                        onStartWalkthrough?()
                    } label: {
                        HStack {
                            Label("Replay App Tutorial", systemImage: "questionmark.circle.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(Color.clarityBlue)
                }
                
                // Finance Section
                Section("Finance") {
                    Button {
                        showCreateBudget = true
                    } label: {
                        Label("Create Budget Plan", systemImage: "wand.and.stars")
                            .foregroundStyle(.primary)
                    }
                    
                    Button {
                        showEditBudget = true
                    } label: {
                        Label("Manage Monthly Limits", systemImage: "slider.horizontal.3")
                            .foregroundStyle(.primary)
                    }
                }
                
                // Daily Clarity Section
                Section("Daily Clarity") {
                    Button {
                        showDailyReview = true
                    } label: {
                        HStack {
                            Label("Start Daily Review", systemImage: "sun.max.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(Color.clarityOrange)
                }

                // Weekly Clarity Section
                Section("Weekly Clarity") {
                    Button {
                        showWeeklyReview = true
                    } label: {
                        HStack {
                            Label("Start Weekly Review", systemImage: "text.book.closed.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(Color.clarityPurple)
                    
                    NavigationLink {
                        WeeklyClarityArchiveView(userEmail: userEmail)
                    } label: {
                        Label("View Archive", systemImage: "sparkles.rectangle.stack.fill")
                            .foregroundStyle(.primary)
                    }
                }
                
                // Data Section
                Section("Data") {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Export Data (CSV)", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        HStack {
                            Label("Export Data (CSV)", systemImage: "square.and.arrow.up")
                                .foregroundStyle(.secondary)
                            Spacer()
                            ProgressView()
                        }
                    }
                }

                // About Section
                Section("About") {
                    ShareLink(item: createShareMessage()) {
                        Label("Share Clarity", systemImage: "square.and.arrow.up.fill")
                            .foregroundStyle(.primary)
                    }
                    
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                            .foregroundStyle(.primary)
                    }

                    HStack {
                        Label("Version", systemImage: "info.circle.fill")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Sign Out Section
                Section {
                    Button(action: signOut) {
                        HStack {
                            Spacer()
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .contentMargins(.bottom, 90, for: .scrollContent)
            .sheet(isPresented: $showEditProfile) {
                if let profile = profiles.first {
                    EditProfileView(profile: profile)
                }
            }
            .sheet(isPresented: $showCreateBudget) {
                CreateBudgetView()
            }
            .sheet(isPresented: $showEditBudget) {
                EditBudgetSheet(userEmail: userEmail)
            }
            .sheet(isPresented: $showDailyReview) {
                DailyReviewView(userEmail: userEmail)
            }
            .sheet(isPresented: $showWeeklyReview) {
                WeeklyReviewView(userEmail: userEmail)
            }
            .onAppear {
                if exportURL == nil {
                    exportURL = DataExporter.exportCSV(context: context, userEmail: userEmail)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func createShareMessage() -> String {
        return """
        Hey! 👋
        
        I'm using Clarity to stay organized and boost my productivity. It helps me track tasks, habits, moods, finances, and more - all in one beautiful app.
        
        Join me on Clarity!
        
        🔗 Download here: https://testflight.apple.com/join/49jdnaAc
        """
    }
    
    private func signOut() {
        // Clear session
        AuthManager.shared.logout()

        // Force app to restart by exiting to root
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = UIHostingController(rootView: ContentView())
            window.makeKeyAndVisible()
        }
    }
}

#Preview {
    ProfileView(userEmail: "test@example.com")
        .modelContainer(for: [UserProfile.self, WeeklyReview.self])
}
