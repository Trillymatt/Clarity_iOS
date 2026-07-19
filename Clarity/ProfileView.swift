import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context

    let userEmail: String
    @Query private var profiles: [UserProfile]
    
    @State private var isEditing = false
    @State private var editName = ""
    @State private var showWeeklyReview = false
    @State private var exportURL: URL?
    
    init(userEmail: String) {
        self.userEmail = userEmail
        _profiles = Query(filter: #Predicate { $0.email == userEmail })
    }
    
    var userName: String {
        profiles.first?.name ?? "User"
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Header Section
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundStyle(LinearGradient.clarityPrimary)
                        
                        if isEditing {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Name", text: $editName)
                                    .textFieldStyle(.roundedBorder)
                                
                                HStack {
                                    Button("Save") {
                                        saveProfile()
                                        withAnimation { isEditing = false }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.clarityBlue)
                                    
                                    Button("Cancel") {
                                        withAnimation { isEditing = false }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(userName)
                                    .font(.title3.bold())
                                
                                Text(userEmail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                editName = userName
                                withAnimation { isEditing = true }
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.clarityBlue)
                            }
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
            .sheet(isPresented: $showWeeklyReview) {
                WeeklyReviewView(userEmail: userEmail)
            }
            .onAppear {
                editName = userName
                if exportURL == nil {
                    exportURL = DataExporter.exportCSV(context: context, userEmail: userEmail)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveProfile() {
        if let profile = profiles.first {
            profile.name = editName
            try? context.save()
        }
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
