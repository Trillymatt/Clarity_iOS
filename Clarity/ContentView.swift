import SwiftUI
import SwiftData
import AVFoundation
import Combine
import AuthenticationServices

@Model
final class UserProfile {
    var name: String
    var email: String
    var reason: String?
    var joinDate: Date
    var passwordHash: String?
    var focusAreas: [String] = []
    var onboardingCompleted: Bool = false
    
    // New onboarding context fields for LLM personalization
    var biggestPriority: String?
    var idealDay: String?
    var desiredHabit: String?
    
    init(name: String, email: String, reason: String? = nil, passwordHash: String? = nil) {
        self.name = name
        self.email = email
        self.reason = reason
        self.joinDate = Date()
        self.passwordHash = passwordHash
        self.onboardingCompleted = false
        self.biggestPriority = nil
        self.idealDay = nil
        self.desiredHabit = nil
    }
}

struct AuthGate: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var showProfileSheet = false
    
    // Onboarding State
    @State private var onboardingData: OnboardingData?
    @State private var isCheckingSession = true
    
    var body: some View {
        if isCheckingSession {
            // Show loading while checking session
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
            }
            .onAppear {
                // Check for existing session
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isCheckingSession = false
                }
            }
         } else if let lastEmail = AuthManager.shared.getLastUserEmail(),
                  let profile = profiles.first(where: { $0.email == lastEmail }),
                  profile.onboardingCompleted {
            // User is logged in and completed onboarding - go straight to app
            RootTabView(userEmail: profile.email)
                .onAppear {
                    print("✅ Restored session for: \(profile.email)")
                }
        } else if let profile = profiles.first, profile.onboardingCompleted {
            // Fallback: any completed profile
            RootTabView(userEmail: profile.email)
                .onAppear {
                    AuthManager.shared.saveLastUserEmail(profile.email)
                }
        } else if let profile = profiles.first, !profile.onboardingCompleted {
            // Profile exists but onboarding not complete
            OnboardingFlow(initialName: profile.name, initialEmail: profile.email)
        } else {
            // No session - show landing
            LandingView(
                onStartOnboarding: { name, email in
                    print("📝 AuthGate: Starting onboarding with name: '\(name)', email: \(email)")
                    self.onboardingData = OnboardingData(name: name, email: email)
                }
            )
            .fullScreenCover(item: $onboardingData) { data in
                OnboardingFlow(initialName: data.name, initialEmail: data.email)
            }
        }
    }
}

struct OnboardingData: Identifiable {
    let id = UUID()
    let name: String
    let email: String
}

final class VideoController: ObservableObject {
    let player: AVQueuePlayer
    private var looper: AVPlayerLooper?
    
    init?(resourceName: String, ext: String? = "mp4") {
        // Try to resolve the resource whether the caller passed a name with or without extension
        let resolvedURL: URL? = {
            if let ext, !resourceName.lowercased().hasSuffix(".\(ext)") {
                // Try name + extension first
                if let u = Bundle.main.url(forResource: resourceName, withExtension: ext) { return u }
                // Fallback: maybe the resourceName already includes the dot-ext; try raw
                return Bundle.main.url(forResource: resourceName, withExtension: nil)
            } else {
                // If resourceName already includes an extension or ext is nil, try raw first
                if let u = Bundle.main.url(forResource: resourceName, withExtension: nil) { return u }
                // If ext provided and name lacked it, try with ext as a fallback
                if let ext { return Bundle.main.url(forResource: resourceName.replacingOccurrences(of: ".\(ext)", with: ""), withExtension: ext) }
                return nil
            }
        }()
        guard let url = resolvedURL else {
            let extDesc = ext != nil ? ".\(ext!)" : ""
            print("VideoController: Failed to find resource \(resourceName)\(extDesc) in bundle.")
            return nil
        }
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer(items: [item])
        queue.isMuted = true
        // No-audio policy: keep player muted; video may render silently.
        queue.actionAtItemEnd = .none
        self.player = queue
        self.looper = AVPlayerLooper(player: queue, templateItem: item)
    }
    
    func play() { player.play() }
    func pause() { player.pause() }
}

struct VideoBackground: UIViewRepresentable {
    @ObservedObject var controller: VideoController
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = AVPlayerLayer(player: controller.player)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        layer.needsDisplayOnBoundsChange = true
        view.layer.addSublayer(layer)
        // Start silent playback
        controller.player.isMuted = true
        controller.play()
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = uiView.layer.sublayers?.compactMap({ $0 as? AVPlayerLayer }).first {
            playerLayer.frame = uiView.bounds
        }
    }
}


struct LandingView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    
    @State private var showContent = false
    @State private var showButtons = false
    @State private var isSigningInGoogle = false
    @State private var showEmailAuth = false
    @State private var showGuestSheet = false
    
    var onStartOnboarding: (String, String) -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background
            Color.clarityBackground
                .ignoresSafeArea()
            
            LinearGradient(
                colors: [Color.clarityBlue.opacity(0.2), Color.clarityPurple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Floating Orbs (Decorative)
            Circle()
                .fill(Color.clarityBlue.opacity(0.3))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(Color.clarityPurple.opacity(0.3))
                .frame(width: 250, height: 250)
                .blur(radius: 60)
                .offset(x: 100, y: 150)
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo Section
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.primaryGradient)
                        .symbolEffect(.bounce, value: showContent)
                    
                    Text("Clarity")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                    
                    Text("See your life clearly.\nLive intentionally.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                
                Spacer()
                
                // Buttons Section
                VStack(spacing: 16) {
                    // Apple Sign In
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    
                    // Google Sign In (Real OAuth)
                    Button(action: startGoogleSignIn) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                            Text("Continue with Google")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    // Email Sign In
                    Button(action: { showEmailAuth = true }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Continue with Email")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    // Guest
                    Button(action: { showGuestSheet = true }) {
                        Text("Continue as Guest")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .opacity(showButtons ? 1 : 0)
                .offset(y: showButtons ? 0 : 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                showContent = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
                showButtons = true
            }
        }
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView { profile in
                showEmailAuth = false
                // If profile is new/incomplete, start onboarding
                if !profile.onboardingCompleted {
                    onStartOnboarding(profile.name, profile.email)
                }
            }
        }
        .sheet(isPresented: $showGuestSheet) {
            GuestInfoSheet { name, email in
                showGuestSheet = false
                onStartOnboarding(name, email)
            }
        }
    }
    
    // MARK: - Apple Sign In Handler
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authResults):
            guard let credential = authResults.credential as? ASAuthorizationAppleIDCredential else { return }
            
            let appleUserId = credential.user
            print("🍎 Apple Sign In - User ID: \(appleUserId)")
            
            // Check if we have seen this Apple User before
            if let existingEmail = AuthManager.shared.getEmailForAppleUser(appleUserId),
               let existingProfile = getExistingProfile(email: existingEmail) {
                // Returning user - restore session and skip onboarding
                print("✅ Returning Apple user: \(existingEmail), Profile complete: \(existingProfile.onboardingCompleted)")
                AuthManager.shared.saveLastUserEmail(existingEmail)
                // AuthGate will pick up the session and show the app
                return
            }
            
            // First time sign in - get name and email
            let givenName = credential.fullName?.givenName ?? ""
            let familyName = credential.fullName?.familyName ?? ""
            var email = credential.email ?? ""
            var name = [givenName, familyName].joined(separator: " ").trimmingCharacters(in: .whitespaces)
            
            print("🍎 Apple provided - Name: '\(name)', Email: '\(email)'")
            
            // Apple only provides email/name on FIRST sign in
            // If empty, this is a returning user but we don't have mapping
            if email.isEmpty {
                // Create a unique email based on Apple User ID
                email = "apple_\(appleUserId)@privaterelay.appleid.com"
                print("⚠️ Apple didn't provide email (returning user). Using: \(email)")
            }
            
            if name.isEmpty {
                name = "Apple User"
                print("⚠️ Apple didn't provide name (subsequent login). Using default.")
            }
            
            print("🍎 Final values - Name: '\(name)', Email: '\(email)'")
            
            // Save the mapping for future logins
            AuthManager.shared.saveAppleUserMapping(appleUserId: appleUserId, email: email)
            
            // Check if profile already exists
            if let existingProfile = getExistingProfile(email: email) {
                if existingProfile.onboardingCompleted {
                    // User exists and completed onboarding - just restore session
                    print("✅ Found existing completed profile for: \(email), Name: \(existingProfile.name)")
                    AuthManager.shared.saveLastUserEmail(email)
                } else {
                    // User exists but didn't complete onboarding
                    // Use fresh name from Apple to override possibly empty profile name
                    print("⚠️ User exists but onboarding incomplete. Using name: '\(name)'")
                    print("🎯 Calling onStartOnboarding with name: '\(name)', email: \(existingProfile.email)")
                    onStartOnboarding(name, existingProfile.email)
                }
            } else {
                // New user - create minimal profile immediately to capture the name
                // Apple only provides name on FIRST sign in, so we must save it now
                print("🆕 New Apple user: \(email), Name: '\(name)'")
                let newProfile = UserProfile(name: name, email: email)
                newProfile.onboardingCompleted = false
                context.insert(newProfile)
                try? context.save()
                print("💾 Created profile to capture name before onboarding")
                
                // Now start onboarding with the saved profile's data
                print("🎯 Calling onStartOnboarding with name: '\(name)', email: \(email)")
                onStartOnboarding(name, email)
            }
            
        case .failure(let error):
            print("❌ Apple Sign In failed: \(error.localizedDescription)")
            if (error as NSError).code == 1000 {
                print("DEBUG: Missing 'Sign In with Apple' capability. Add it in Xcode > Signing & Capabilities.")
            }
        }
    }
    
    private func getExistingProfile(email: String) -> UserProfile? {
        return profiles.first(where: { $0.email == email })
    }
    
    // MARK: - Google Sign In
    
    private func startGoogleSignIn() {
        guard let authURL = GoogleAuthHelper.getAuthURL() else { return }
        let scheme = GoogleAuthHelper.urlScheme
        
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { callbackURL, error in
            if let error = error {
                print("Google Sign In Error: \(error.localizedDescription)")
                return
            }
            
            if let url = callbackURL {
                GoogleAuthHelper.handleCallback(url: url) { name, email in
                    DispatchQueue.main.async {
                        guard let email = email, !email.isEmpty else {
                            print("❌ Google didn't provide email")
                            return
                        }
                        
                        // Check for existing profile
                        if let existingProfile = getExistingProfile(email: email) {
                            if existingProfile.onboardingCompleted {
                                print("✅ Found existing Google user: \(email)")
                                AuthManager.shared.saveLastUserEmail(email)
                            } else {
                                onStartOnboarding(existingProfile.name, existingProfile.email)
                            }
                        } else {
                            // New user
                            onStartOnboarding(name ?? "Google User", email)
                        }
                    }
                }
            }
        }
        
        // Ensure the session can present on the current window
        session.presentationContextProvider = ContextProvider.shared
        session.start()
    }
}

struct GuestInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onContinue: (String, String) -> Void
    
    @State private var name = ""
    @State private var email = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Guest Access")
                        .titleStyle()
                    Text("Please provide your details to personalize your experience.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top)
                
                VStack(spacing: 16) {
                    TextField("Name", text: $name)
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(12)
                    
                    TextField("Email (Optional)", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let finalEmail = email.isEmpty ? "guest_\(UUID().uuidString)@clarity.app" : email
                    print("👤 Guest sign in - Name: '\(trimmedName)', Email: \(finalEmail)")
                    onContinue(trimmedName, finalEmail)
                    dismiss()
                }) {
                    Text("Continue")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Spacer()
            }
            .padding()
            .background(Color.clarityBackground.ignoresSafeArea())
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

// Helper for ASWebAuthenticationSession presentation
class ContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = ContextProvider()
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        
        // Try to find the key window
        if let window = scenes.first?.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        
        // Fallback: Create a window attached to the first scene
        if let scene = scenes.first {
            return UIWindow(windowScene: scene)
        }
        
        // Last resort (should rarely happen)
        if let firstScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return UIWindow(windowScene: firstScene)
        }
        
        // Absolute fallback - return any window
        return UIApplication.shared.windows.first ?? UIWindow()
    }
}

// The rest of the file remains unchanged...

struct EmailSignInView: View {
    @Environment(\.dismiss) private var dismiss
    var onFinish: (_ name: String, _ email: String) -> Void
    @State private var name = ""
    @State private var email = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome Back")
                        .titleStyle()
                    Text("Sign in to continue your journey.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top)
                
                VStack(spacing: 16) {
                    TextField("Name", text: $name)
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(12)
                    
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    onFinish(name, email)
                    dismiss()
                }) {
                    Text("Continue")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Spacer()
            }
            .padding()
            .background(Color.clarityBackground.ignoresSafeArea())
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

// MARK: - Root Tabs
struct RootTabView: View {
    let userEmail: String
    @State private var selectedTab: Tab = .home
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @State private var showTutorial = false
    
    enum Tab {
        case home, focus, habits, moments, money
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(userEmail: userEmail)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(Tab.home)
            
            EnhancedTodayTab(userEmail: userEmail)
                .tabItem {
                    Label("Focus", systemImage: "target")
                }
                .tag(Tab.focus)
            
            EnhancedHabitsTab(userEmail: userEmail)
                .tabItem {
                    Label("Habits", systemImage: "repeat.circle.fill")
                }
                .tag(Tab.habits)
            
            EnhancedMomentsTab(userEmail: userEmail)
                .tabItem {
                    Label("Moments", systemImage: "sparkles")
                }
                .tag(Tab.moments)
            
            EnhancedFinanceTab(userEmail: userEmail)
                .tabItem {
                    Label("Money", systemImage: "banknote.fill")
                }
                .tag(Tab.money)
        }
        .tint(Color.clarityBlue)
        .sheet(isPresented: $showTutorial) {
            FirstLaunchTutorial()
                .onDisappear {
                    hasSeenTutorial = true
                }
        }
        .onAppear {
            // Show tutorial on first launch
            if !hasSeenTutorial {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showTutorial = true
                }
            }
        }
    }
}

struct ContentView: View {
    var body: some View { AuthGate() }
}








struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let userEmail: String
    var prefillAmount: Double = 0.0
    var prefillCategory: TransactionCategory = .other
    var prefillNote: String = ""
    
    @State private var amount = ""
    @State private var date = Date()
    @State private var category: TransactionCategory = .other
    @State private var note = ""
    @State private var recurring = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Amount Input (Big & Prominent)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            HStack {
                                Text("$")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(.secondary)
                                TextField("0.00", text: $amount)
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .keyboardType(.decimalPad)
                            }
                            .padding()
                            .background(Color.clarityCard)
                            .cornerRadius(16)
                        }
                        
                        // Category Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(TransactionCategory.allCases) { cat in
                                        SelectionChip(
                                            title: cat.rawValue.capitalized,
                                            isSelected: category == cat
                                        ) {
                                            withAnimation { category = cat }
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        
                        // Note
                        CustomTextField(icon: "note.text", placeholder: "What was this for?", text: $note)
                        
                        // Date
                        VStack(alignment: .leading, spacing: 12) {
                            Text("When?")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            DatePicker("Date", selection: $date, displayedComponents: [.date])
                                .datePickerStyle(.graphical)
                                .padding()
                                .background(Color.clarityCard)
                                .cornerRadius(16)
                        }
                        
                        // Recurring Toggle
                        Toggle(isOn: $recurring) {
                            Label("Recurring Transaction", systemImage: "repeat")
                        }
                        .padding()
                        .background(Color.clarityCard)
                        .cornerRadius(12)
                        
                        Spacer(minLength: 20)
                        
                        Button(action: saveTransaction) {
                            Text("Add Transaction")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(Double(amount) == nil || amount.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear {
                if prefillAmount > 0 {
                    amount = String(format: "%.2f", prefillAmount)
                }
                if prefillCategory != .other {
                    category = prefillCategory
                }
                if !prefillNote.isEmpty {
                    note = prefillNote
                }
            }
        }
    }
    
    private func saveTransaction() {
        let value = Double(amount) ?? 0
        let txn = Transaction(ownerEmail: userEmail, amount: value, date: date, category: category, note: note.isEmpty ? nil : note, isRecurring: recurring)
        context.insert(txn)
        try? context.save()
        dismiss()
    }
}

// MARK: - Onboarding Flow

struct OnboardingFlow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var initialName: String
    var initialEmail: String
    
    // Chat State
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var step = 0
    @State private var isTyping = false
    @FocusState private var isInputFocused: Bool
    @State private var glowRotation: Double = 0
    
    // User Data
    @State private var biggestPriority = ""
    @State private var idealDay = ""
    @State private var desiredHabit = ""
    
    init(initialName: String, initialEmail: String) {
        self.initialName = initialName
        self.initialEmail = initialEmail
        print("🎬 OnboardingFlow INIT - Name: '\(initialName)', Email: '\(initialEmail)'")
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.clarityBackground.ignoresSafeArea()
            
            // Gradient overlay
            LinearGradient(
                colors: [Color.clarityBlue.opacity(0.1), Color.clarityPurple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Floating Orbs
            Circle()
                .fill(Color.clarityBlue.opacity(colorScheme == .dark ? 0.15 : 0.2))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -100, y: -200)
            
            VStack(spacing: 0) {
                // Header
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.primaryGradient)
                    Text("Clarity AI")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // Invisible spacer to balance the layout
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                // Chat History
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            Spacer(minLength: 20)
                            
                            ForEach(messages) { message in
                                ChatBubble(text: message.text, isAI: message.isAI)
                                    .id(message.id)
                            }
                            
                            if isTyping {
                                TypingIndicator()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 24)
                                    .id("typing")
                            }
                            
                            // Completion View (Embedded in chat)
                            if step == 4 {
                                completionView
                                    .padding(.top, 20)
                                    .id("completion")
                            }
                            
                            Spacer(minLength: 20)
                        }
                        .padding(.bottom, 20)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastId = messages.last?.id {
                            withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                        }
                    }
                    .onChange(of: isTyping) { _, typing in
                        if typing {
                            withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                        }
                    }
                    .onChange(of: step) { _, newStep in
                        if newStep == 4 {
                            // Auto-scroll to completion view so user sees the button
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation { proxy.scrollTo("completion", anchor: .bottom) }
                            }
                        }
                    }
                }
                
                // Bottom Input Bar
                if step < 4 {
                    VStack(spacing: 0) {
                        // Suggestions
                        if step >= 1 && step <= 3 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(suggestionsForStep(step), id: \.self) { opt in
                                        Button(action: { sendMessage(opt) }) {
                                            Text(opt)
                                                .font(.caption.bold())
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color.clarityBlue.opacity(0.1), in: Capsule())
                                                .foregroundStyle(Color.clarityBlue)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            }
                        }
                        
                        HStack(alignment: .bottom, spacing: 12) {
                            TextField(placeholderText, text: $inputText, axis: .vertical)
                                .focused($isInputFocused)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .lineLimit(1...5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(
                                            AngularGradient(
                                                gradient: Gradient(colors: [
                                                    Color.clarityBlue,
                                                    Color.clarityPurple,
                                                    Color.clarityBlue
                                                ]),
                                                center: .center,
                                                startAngle: .degrees(glowRotation),
                                                endAngle: .degrees(glowRotation + 360)
                                            ),
                                            lineWidth: isInputFocused ? 2 : 0
                                        )
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            AngularGradient(
                                                gradient: Gradient(colors: [
                                                    Color.clarityBlue,
                                                    Color.clarityPurple,
                                                    Color.clarityBlue
                                                ]),
                                                center: .center,
                                                startAngle: .degrees(glowRotation),
                                                endAngle: .degrees(glowRotation + 360)
                                            ),
                                            lineWidth: 4
                                        )
                                        .blur(radius: 8) // Inner glow
                                        .opacity(isInputFocused ? 0.6 : 0)
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            AngularGradient(
                                                gradient: Gradient(colors: [
                                                    Color.clarityBlue,
                                                    Color.clarityPurple,
                                                    Color.clarityBlue
                                                ]),
                                                center: .center,
                                                startAngle: .degrees(glowRotation),
                                                endAngle: .degrees(glowRotation + 360)
                                            ),
                                            lineWidth: 4
                                        )
                                        .blur(radius: 16) // Outer glow
                                        .opacity(isInputFocused ? 0.4 : 0)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: isInputFocused ? 0 : 1)
                                )
                                .onAppear {
                                    withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                                        glowRotation = 360
                                    }
                                }
                            
                            Button(action: { sendMessage(inputText) }) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.5) : Color.clarityBlue)
                            }
                            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(16)
                    }
                }
            }
        }
        .onAppear {
            print("🔍 OnboardingFlow onAppear - initialName: '\(initialName)', initialEmail: '\(initialEmail)'")
            
            if messages.isEmpty {
                // Extract first name for friendlier greeting
                let firstName = initialName.components(separatedBy: " ").first ?? "there"
                print("👋 Starting onboarding conversation for: '\(firstName)' (full initialName: '\(initialName)')")
                print("🔎 firstName isEmpty: \(firstName.isEmpty), count: \(firstName.count)")
                
                addMessage("Hey \(firstName)! 👋 Welcome to Clarity. Let's personalize your experience.", isAI: true)
                addMessage("To customize your experience, I need to know: What is your single biggest priority right now?", isAI: true)
                step = 1
            }
        }
    }
    
    var placeholderText: String {
        switch step {
        case 1: return "e.g., Get promoted..."
        case 2: return "e.g., Morning run, deep work..."
        case 3: return "e.g., Read 10 pages..."
        default: return "Type a message..."
        }
    }
    
    var completionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.clarityTeal)
                .symbolEffect(.bounce)
            
            Text("All Set! Your dashboard is ready.")
                .font(.title3.bold())
                .foregroundStyle(.primary)
            
            Button(action: completeOnboarding) {
                HStack {
                    Text("Go to Dashboard")
                    Image(systemName: "arrow.right")
                }
                .fontWeight(.bold)
                .frame(width: 200)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    // MARK: - Logic
    
    func addMessage(_ text: String, isAI: Bool) {
        withAnimation {
            messages.append(ChatMessage(text: text, isAI: isAI))
        }
    }
    
    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let userText = text
        inputText = "" // Clear input
        
        // Add user message
        addMessage(userText, isAI: false)
        
        // Save data based on step
        switch step {
        case 1: biggestPriority = userText
        case 2: idealDay = userText
        case 3: desiredHabit = userText
        default: break
        }
        
        // Simulate AI processing
        isTyping = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isTyping = false
            advanceStep()
        }
    }
    
    func advanceStep() {
        step += 1
        
        switch step {
        case 2:
            addMessage("That's a great goal. To help you achieve that, what does a successful day look like for you?", isAI: true)
        case 3:
            addMessage("Understood. Last question: What is one small habit you'd like to start building immediately?", isAI: true)
        case 4:
            addMessage("Perfect! I've set up your dashboard to focus on \(biggestPriority). Let's make it happen!", isAI: true)
        default:
            break
        }
    }
    
    func suggestionsForStep(_ step: Int) -> [String] {
        switch step {
        case 1: // Priority
            return ["Career Growth", "Health & Fitness", "Family Time", "Financial Freedom", "Mental Peace"]
        case 2: // Ideal Day
            return ["Morning Run", "Deep Work Block", "Reading Time", "Dinner with Family", "Meditation"]
        case 3: // Habit
            return ["Drink Water", "Read 10 Pages", "Meditate 5 min", "Walk 10k Steps", "Journal"]
        default:
            return []
        }
    }
    
    func completeOnboarding() {
        // Fetch existing profile or create new one
        let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.email == initialEmail })
        
        print("🔍 Completing onboarding with name: '\(initialName)', email: \(initialEmail)")
        
        if let existingProfile = try? context.fetch(descriptor).first {
            existingProfile.name = initialName
            existingProfile.biggestPriority = biggestPriority.isEmpty ? nil : biggestPriority
            existingProfile.idealDay = idealDay.isEmpty ? nil : idealDay
            existingProfile.desiredHabit = desiredHabit.isEmpty ? nil : desiredHabit
            existingProfile.onboardingCompleted = true
            
            // Save session
            AuthManager.shared.saveLastUserEmail(existingProfile.email)
            print("✅ Onboarding completed for existing user: \(existingProfile.email), Name: '\(existingProfile.name)'")
        } else {
            // Create new profile
            let newProfile = UserProfile(name: initialName, email: initialEmail)
            newProfile.biggestPriority = biggestPriority.isEmpty ? nil : biggestPriority
            newProfile.idealDay = idealDay.isEmpty ? nil : idealDay
            newProfile.desiredHabit = desiredHabit.isEmpty ? nil : desiredHabit
            newProfile.onboardingCompleted = true
            context.insert(newProfile)
            
            // Save session
            AuthManager.shared.saveLastUserEmail(newProfile.email)
            print("✅ Onboarding completed for new user: \(newProfile.email), Name: '\(newProfile.name)'")
        }
        
        try? context.save()
        dismiss()
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isAI: Bool
}

// MARK: - Chat Components

struct ChatBubble: View {
    let text: String
    let isAI: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !isAI { Spacer() }
            
            Text(text)
                .font(.body)
                .lineSpacing(4)
                .padding(16)
                .background(isAI ? Color.clarityCard : Color.clarityBlue)
                .foregroundStyle(isAI ? Color.primary : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            if isAI { Spacer() }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: isAI ? .leading : .trailing)
    }
}

struct TypingIndicator: View {
    @State private var offset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .offset(y: offset)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(i) * 0.2),
                        value: offset
                    )
            }
        }
        .padding(16)
        .background(Color.clarityCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear { offset = -5 }
    }
}

// MARK: - Completion Feature Card
struct CompletionFeatureCard: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.clarityCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct ReasonChips: View {
    @Binding var selection: String
    private let options = [
        "Find focus today",
        "Build consistent habits",
        "Reflect on moments",
        "See a calm dashboard",
        "Improve my wellbeing"
    ]
    var body: some View {
        FlowLayout(alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { option in
                let selected = selection == option
                Text(option)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                    .onTapGesture { selection = option }
            }
        }
    }
}



// MARK: - Helpers
private func nonOptional(_ source: Binding<Date?>, default defaultDate: Date) -> Binding<Date> {
    Binding<Date>(
        get: { source.wrappedValue ?? defaultDate },
        set: { newValue in source.wrappedValue = newValue }
    )
}

struct FlowLayout<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content
    
    init(alignment: HorizontalAlignment = .leading, spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        return GeometryReader { geo in
            ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
                content()
                    .alignmentGuide(.leading) { d in
                        if (abs(width - d.width) > geo.size.width) {
                            width = 0
                            height -= (d.height + spacing)
                        }
                        let result = width
                        if d.width != 0 { width -= d.width + spacing }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if height != 0 { }
                        return result
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, TaskItem.self, Habit.self, HabitCheckin.self, JournalEntry.self, LifeMoment.self, Transaction.self, FinancialGoal.self, LifeAreaScore.self], inMemory: true)
}

