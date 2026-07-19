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
    var appleUserId: String? // Stable identifier for Apple Sign In
    @Attribute(.externalStorage) var profileImageData: Data? // Profile photo
    
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
    @AppStorage("lastUserEmail") private var lastUserEmail: String?
    
    // Onboarding State
    @State private var onboardingData: OnboardingData?
    @State private var isCheckingSession = true
    @State private var recentCompletedEmail: String?
    
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
         } else if let email = recentCompletedEmail {
             // 0. Immediate priority: User just finished onboarding
             RootTabView(userEmail: email)
                 .onAppear { print("🚀 Showing Dashboard via local override for \(email)") }
         } else if let email = lastUserEmail,
                  let profile = profiles.first(where: { $0.email == email }),
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
                OnboardingFlow(initialName: data.name, initialEmail: data.email, onComplete: { email in
                    // Force refresh and dismiss
                    print("🚀 Onboarding completed for \(email) - forcing transition")
                    // Dismiss first
                    onboardingData = nil
                    // Set local override to ensure immediate switching
                    recentCompletedEmail = email
                })
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
                        let nonce = AppleAuthUtils.randomNonceString()
                        currentNonce = nonce
                        request.nonce = AppleAuthUtils.sha256(nonce)
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
    
    @State private var currentNonce: String?
    
    // MARK: - Apple Sign In Handler
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authResults):
            guard let credential = authResults.credential as? ASAuthorizationAppleIDCredential else { return }
            guard currentNonce != nil else {
                print("❌ Fatal: Nonce missing")
                return
            }
            
            let appleUserId = credential.user
            print("🍎 Apple Sign In - User ID: \(appleUserId)")
            
            // Extract Name and Email
            let givenName = credential.fullName?.givenName ?? ""
            let familyName = credential.fullName?.familyName ?? ""
            let name = [givenName, familyName].joined(separator: " ").trimmingCharacters(in: .whitespaces)
            let email = credential.email
            
            Task {
                do {
                    // 1. Sync to CloudKit (automatic with iCloud)
                    // We pass available details to ensure record is updated
                    try await CloudKitService.shared.syncCurrentUser(email: email, displayName: name.isEmpty ? nil : name)
                    
                    // 2. Handle Local Clarity Profile
                    if let existingProfile = profiles.first(where: { $0.appleUserId == appleUserId }) {
                         AuthManager.shared.saveLastUserEmail(existingProfile.email)
                    } else if let email = email, let existingProfile = profiles.first(where: { $0.email == email }) {
                        // Link by email
                        existingProfile.appleUserId = appleUserId
                        try? context.save()
                        AuthManager.shared.saveLastUserEmail(email)
                    } else {
                        // New User logic
                        let finalEmail = email ?? "apple_\(appleUserId)@privaterelay.appleid.com"
                        let finalName = name.isEmpty ? "Apple User" : name
                        
                        let newProfile = UserProfile(name: finalName, email: finalEmail)
                        newProfile.appleUserId = appleUserId
                        context.insert(newProfile)
                        try? context.save()
                        
                        onStartOnboarding(finalName, finalEmail)
                    }
                } catch {
                    print("❌ Authentication Failed: \(error.localizedDescription)")
                }
            }
            
        case .failure(let error):
            print("❌ Apple Sign In failed: \(error.localizedDescription)")
            // ... (keep existing error handling if needed)
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
        
        // Absolute fallback - return key window from any scene, or a new window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
             return UIWindow(windowScene: windowScene)
        }
        
        // Final fallback for really old contexts or weird states
        return UIWindow()
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
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    
    let userEmail: String
    @State private var selectedTab: Tab = .dashboard
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @State private var showTutorial = false

    enum Tab {
        case dashboard, assistant, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(userEmail: userEmail, selectedTab: $selectedTab)
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
                .tag(Tab.dashboard)

            AssistantView(userEmail: userEmail)
                .tabItem {
                    Label("Assistant", systemImage: "sparkles")
                }
                .tag(Tab.assistant)

            ProfileView(userEmail: userEmail) {
                showTutorial = true
            }
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(Tab.profile)
        }
        .tint(Color.clarityBlue)
        .overlay(alignment: .bottom) {
            if selectedTab != .assistant {
                AssistantDockBar {
                    withAnimation { selectedTab = .assistant }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 78)
            }
        }
        .sheet(isPresented: $showTutorial) {
            FirstLaunchTutorial()
                .onDisappear {
                    hasSeenTutorial = true
                }
        }
        .onAppear {
            // Update widget data when app starts
            WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
            NotificationScheduler.refresh(context: context, userEmail: userEmail)

            // Show tutorial on first launch
            if !hasSeenTutorial {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showTutorial = true
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Update widget data and refresh data-aware notification
                // content when the app returns to foreground.
                WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
                NotificationScheduler.refresh(context: context, userEmail: userEmail)
            }
        }
    }
}



struct ContentView: View {
    var body: some View { AuthGate() }
}








// MARK: - Onboarding Flow

struct OnboardingFlow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var initialName: String
    var initialEmail: String
    var onComplete: ((String) -> Void)?
    
    // Chat State
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var step = 0
    @State private var isTyping = false
    
    // User Data
    @State private var biggestPriority = ""
    @State private var idealDay = ""
    @State private var desiredHabit = ""
    
    init(initialName: String, initialEmail: String, onComplete: ((String) -> Void)? = nil) {
        self.initialName = initialName
        self.initialEmail = initialEmail
        self.onComplete = onComplete
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
                        
                        ChatInputBar(placeholder: placeholderText, text: $inputText) { text in
                            sendMessage(text)
                        }
                        .padding(16)

                        // Disclaimer
                        Text("* Guided reflection using pre-selected questions")
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.6))
                            .padding(.bottom, 4)
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
        print("✅ Calling onComplete with \(initialEmail)")
        onComplete?(initialEmail)
        dismiss()
    }
}

// ChatMessage, ChatBubble, and TypingIndicator now live in
// Components/Shared/ChatComponents.swift so onboarding, the weekly review,
// and the Jarvis assistant all share one styled chat primitive.

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
        .modelContainer(for: [UserProfile.self, TaskItem.self, Habit.self, HabitCheckin.self, JournalEntry.self, LifeMoment.self, Transaction.self, FinancialGoal.self], inMemory: true)
}
