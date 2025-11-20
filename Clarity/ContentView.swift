import SwiftUI
import SwiftData
import AVFoundation
import Combine

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var email: String
    var reason: String? // why you downloaded the app
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, email: String, reason: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.email = email
        self.reason = reason
        self.createdAt = createdAt
    }
}

struct AuthGate: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var showProfileSheet = false
    
    @State private var pendingRoute: Route? = nil
    enum Route: Identifiable { case email
        var id: String { switch self { case .email: return "email" } }
    }
    
    var body: some View {
        if let profile = profiles.first {
            RootTabView()
                .toolbar { ToolbarItem(placement: .topBarLeading) { Button { showProfileSheet = true } label: { Image(systemName: "person.circle") } } }
                .sheet(isPresented: $showProfileSheet) { ProfileView(profile: profile) }
                .sheet(item: $pendingRoute) { route in
                    switch route {
                    case .email:
                        EmailSignInView(onFinish: { name, email in
                            let profile = UserProfile(name: name, email: email)
                            context.insert(profile)
                            try? context.save()
                            pendingRoute = nil
                        })
                    }
                }
        } else {
            LandingView(
                onContinueWithApple: { /* TODO: hook Sign in with Apple later */ pendingRoute = .email },
                onContinueWithGoogle: { /* TODO: hook Google Sign-In later */ pendingRoute = .email },
                onContinueWithEmail: { pendingRoute = .email },
                onContinueAsGuest: { createGuestAndProceed() }
            )
        }
    }
    
    private func createGuestAndProceed() {
        let profile = UserProfile(name: "Guest", email: "")
        context.insert(profile)
        try? context.save()
    }
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
    @State private var showClarity = false
    @State private var moveUp = false
    @State private var showChoices = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var videoControllerOpt: VideoController? = VideoController(resourceName: "download", ext: "mp4")
    
    var onContinueWithApple: () -> Void
    var onContinueWithGoogle: () -> Void
    var onContinueWithEmail: () -> Void
    var onContinueAsGuest: () -> Void
    
    var body: some View {
        ZStack {
            Group {
                if let controller = videoControllerOpt {
                    VideoBackground(controller: controller)
                        .ignoresSafeArea()
                } else {
                    LinearGradient(
                        colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
            }
            .overlay(Color.black.opacity(0.22).ignoresSafeArea())
            
            VStack(spacing: 20) {
                VStack(spacing: 24) {
                    Image(systemName: "circle.grid.2x2")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: logoScale)
                    
                    Text("Clarity")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .opacity(showClarity ? 1 : 0)
                        .offset(y: moveUp ? -20 : 0)
                        .animation(.easeInOut(duration: 0.8), value: showClarity)
                        .animation(.spring(response: 0.7, dampingFraction: 0.9), value: moveUp)
                    
                    if showChoices {
                        VStack(spacing: 12) {
                            Button(action: onContinueWithApple) {
                                HStack {
                                    Image(systemName: "applelogo")
                                    Text("Continue with Apple")
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(Color.white)
                            }

                            Button(action: onContinueWithGoogle) {
                                HStack {
                                    Image(systemName: "g.circle")
                                    Text("Continue with Google")
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }

                            Button(action: onContinueWithEmail) {
                                HStack {
                                    Image(systemName: "envelope")
                                    Text("Continue with Email")
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        
                        VStack(spacing: 8) {
                            Button(action: onContinueAsGuest) {
                                Text("Continue as Guest")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                
                Spacer(minLength: 0)
            }
        }
        .onAppear(perform: startSequence)
        .preferredColorScheme(.light)
        .onChange(of: scenePhase) { _, newPhase in
            guard let controller = videoControllerOpt else { return }
            switch newPhase {
            case .active:
                controller.player.isMuted = true
                controller.play()
            case .inactive, .background:
                controller.pause()
            @unknown default: break
            }
        }
        .onAppear {
            if videoControllerOpt == nil { print("LandingView: 'download.mp4' not found in bundle; showing gradient fallback.") }
        }
    }
    
    private func startSequence() {
        logoOpacity = 1
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            logoScale = 1.05
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showClarity = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { moveUp = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeInOut(duration: 0.6)) { showChoices = true }
        }
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
            Form {
                TextField("Name", text: $name)
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }
            .navigationTitle("Sign In")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        onFinish(name, email)
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Root Tabs
struct RootTabView: View {
    var body: some View {
        TabView {
            TodayTab()
                .tabItem { Label("Today", systemImage: "sun.max") }
            HabitsTab()
                .tabItem { Label("Habits", systemImage: "heart") }
            MomentsTab()
                .tabItem { Label("Moments", systemImage: "bolt") }
            MoneyTab()
                .tabItem { Label("Clarity", systemImage: "chart.bar") }
        }
    }
}

struct ContentView: View {
    var body: some View { AuthGate() }
}

// MARK: - Today (Tasks)
struct TodayTab: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TaskItem.dueDate) private var tasks: [TaskItem]
    @State private var showAdd = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Top 3 Priorities") {
                    ForEach(tasks.filter { $0.isToday }.prefix(3)) { task in
                        TaskRow(task: task)
                    }
                }
                Section("Today’s Tasks") {
                    ForEach(tasks.filter { isTaskForToday($0) }) { task in
                        TaskRow(task: task)
                    }
                    .onDelete { indexSet in
                        let filtered = tasks.filter { isTaskForToday($0) }
                        indexSet.map { filtered[$0] }.forEach { context.delete($0) }
                        try? context.save()
                    }
                }
                if tasks.isEmpty {
                    ContentUnavailableView("No tasks yet", systemImage: "checkmark.circle", description: Text("Tap + to add your first task."))
                }
            }
            .navigationTitle("Today")
            .toolbar { ToolbarItem(placement: .primaryAction) { Button(action: { showAdd = true }) { Image(systemName: "plus") } } }
            .sheet(isPresented: $showAdd) { AddTaskSheet() }
        }
    }
    
    private func isTaskForToday(_ item: TaskItem) -> Bool {
        if item.isToday { return true }
        if let d = item.dueDate { return Calendar.current.isDateInToday(d) }
        return false
    }
}

private struct TaskRow: View {
    @Environment(\.modelContext) private var context
    @State var task: TaskItem
    var body: some View {
        HStack {
            Button { task.isCompleted.toggle(); try? context.save() } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            VStack(alignment: .leading) {
                Text(task.title).strikethrough(task.isCompleted)
                if let due = task.dueDate { Text(due, style: .date).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            Button { task.isToday.toggle(); try? context.save() } label: {
                Image(systemName: task.isToday ? "star.fill" : "star")
            }
        }
    }
}

private struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var title = ""
    @State private var notes = ""
    @State private var dueDate: Date? = nil
    @State private var isToday = true
    @State private var category: TaskCategory = .personal
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Notes", text: $notes)
                Toggle("Mark as Today", isOn: $isToday)
                DatePicker("Due Date", selection: nonOptional($dueDate, default: Date()), displayedComponents: [.date])
                Picker("Category", selection: $category) {
                    ForEach(TaskCategory.allCases) { c in Text(c.rawValue.capitalized).tag(c) }
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let item = TaskItem(title: title, notes: notes.isEmpty ? nil : notes, dueDate: dueDate, isCompleted: false, isToday: isToday, category: category)
                        context.insert(item)
                        try? context.save()
                        dismiss()
                    }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Habits
struct HabitsTab: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Habit> { $0.isActive == true }) private var habits: [Habit]
    @State private var showAdd = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Today") {
                    let weekday = Calendar.current.component(.weekday, from: Date()) - 1
                    ForEach(habits.filter { $0.daysOfWeek.contains(weekday) }) { habit in
                        HabitRow(habit: habit)
                    }
                }
                Section("All Habits") {
                    ForEach(habits) { habit in HabitRow(habit: habit) }
                    .onDelete { idx in idx.map { habits[$0] }.forEach { context.delete($0) }; try? context.save() }
                }
                if habits.isEmpty {
                    ContentUnavailableView("No habits yet", systemImage: "heart", description: Text("Tap + to create a habit."))
                }
            }
            .navigationTitle("Habits")
            .toolbar { ToolbarItem(placement: .primaryAction) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
            .sheet(isPresented: $showAdd) { AddHabitSheet() }
        }
    }
}

private struct HabitRow: View {
    @Environment(\.modelContext) private var context
    @State var habit: Habit
    @State private var value: Int = 0
    @State private var completed: Bool = false
    
    var body: some View {
        HStack {
            if let icon = habit.iconName, !icon.isEmpty { Image(systemName: icon) }
            Text(habit.name)
            Spacer()
            if let goal = habit.goalPerDay { Text("\(value)/\(goal)").font(.caption).foregroundStyle(.secondary) }
            Button { value += 1; if let goal = habit.goalPerDay { completed = value >= goal } else { completed = value > 0 } } label: { Image(systemName: "plus.circle") }
            Button { completed.toggle() } label: { Image(systemName: completed ? "checkmark.circle.fill" : "circle").foregroundStyle(completed ? .green : .secondary) }
        }
    }
}

private struct AddHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var icon = ""
    @State private var goal: Int = 0
    @State private var days = Set<Int>()
    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Icon (SF Symbol)", text: $icon)
                Stepper("Goal per day: \(goal)", value: $goal, in: 0...100)
                DaysOfWeekPicker(selection: $days)
            }
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let habit = Habit(name: name, iconName: icon.isEmpty ? nil : icon, goalPerDay: goal == 0 ? nil : goal, daysOfWeek: Array(days).sorted(), isActive: true)
                        context.insert(habit)
                        try? context.save()
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct DaysOfWeekPicker: View {
    @Binding var selection: Set<Int>
    private let labels = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    var body: some View {
        VStack(alignment: .leading) {
            Text("Days of Week")
            HStack {
                ForEach(0..<7) { i in
                    let selected = selection.contains(i)
                    Text(labels[i])
                        .padding(8)
                        .background(selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture { if selected { selection.remove(i) } else { selection.insert(i) } }
                }
            }
        }
    }
}

// MARK: - Moments
struct MomentsTab: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LifeMoment.date, order: .reverse) private var moments: [LifeMoment]
    @State private var showAdd = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedByDay(), id: \.key) { day, items in
                    Section(header: Text(day, style: .date)) {
                        ForEach(items) { m in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(m.title).fontWeight(.medium)
                                HStack(spacing: 8) {
                                    Text(m.type.rawValue.capitalized).font(.caption).padding(4).background(Color.secondary.opacity(0.1)).clipShape(Capsule())
                                    if let mood = m.moodScore { Text("Mood: \(mood)").font(.caption).foregroundStyle(.secondary) }
                                }
                                if let note = m.note, !note.isEmpty { Text(note).foregroundStyle(.secondary) }
                            }
                        }
                        .onDelete { idx in idx.map { items[$0] }.forEach { context.delete($0) }; try? context.save() }
                    }
                }
                if moments.isEmpty {
                    ContentUnavailableView("No moments yet", systemImage: "bolt", description: Text("Tap + to capture your first moment."))
                }
            }
            .navigationTitle("Moments")
            .toolbar { ToolbarItem(placement: .primaryAction) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
            .sheet(isPresented: $showAdd) { AddMomentSheet() }
        }
    }
    
    private func groupedByDay() -> [(key: Date, value: [LifeMoment])]{
        let groups = Dictionary(grouping: moments) { Calendar.current.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { $0.date > $1.date }) }
    }
}

private struct AddMomentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var title = ""
    @State private var note = ""
    @State private var type: MomentType = .win
    @State private var mood: Double = 3
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Note", text: $note)
                Picker("Type", selection: $type) { ForEach(MomentType.allCases) { t in Text(t.rawValue.capitalized).tag(t) } }
                HStack { Text("Mood: \(Int(mood))"); Slider(value: $mood, in: 1...5, step: 1) }
            }
            .navigationTitle("Capture a Moment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let m = LifeMoment(date: Date(), title: title, note: note.isEmpty ? nil : note, moodScore: Int(mood), type: type)
                        context.insert(m)
                        try? context.save()
                        dismiss()
                    }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Money (Transactions Snapshot)
struct MoneyTab: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var showAdd = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("This Week") {
                    Text("Total: $\(Int(weeklySpending()))")
                }
                Section("Recent Transactions") {
                    ForEach(transactions) { t in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(t.category.rawValue.capitalized)
                                Text(t.date, style: .date).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("$\(String(format: "%.2f", t.amount))")
                        }
                    }
                    .onDelete { idx in idx.map { transactions[$0] }.forEach { context.delete($0) }; try? context.save() }
                }
                if transactions.isEmpty {
                    ContentUnavailableView("No transactions yet", systemImage: "creditcard", description: Text("Tap + to add a transaction."))
                }
            }
            .navigationTitle("Clarity")
            .toolbar { ToolbarItem(placement: .primaryAction) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
            .sheet(isPresented: $showAdd) { AddTransactionSheet() }
        }
    }
    
    private func weeklySpending() -> Double {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: now))!
        return transactions.filter { $0.date >= start && $0.date <= now }.reduce(0) { $0 + $1.amount }
    }
}

private struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var amount = ""
    @State private var date = Date()
    @State private var category: TransactionCategory = .other
    @State private var note = ""
    @State private var recurring = false
    var body: some View {
        NavigationStack {
            Form {
                TextField("Amount", text: $amount).keyboardType(.decimalPad)
                DatePicker("Date", selection: $date, displayedComponents: [.date])
                Picker("Category", selection: $category) { ForEach(TransactionCategory.allCases) { c in Text(c.rawValue.capitalized).tag(c) } }
                TextField("Note", text: $note)
                Toggle("Recurring", isOn: $recurring)
            }
            .navigationTitle("Add Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let value = Double(amount) ?? 0
                        let txn = Transaction(amount: value, date: date, category: category, note: note.isEmpty ? nil : note, isRecurring: recurring)
                        context.insert(txn)
                        try? context.save()
                        dismiss()
                    }.disabled(Double(amount) == nil)
                }
            }
        }
    }
}

// MARK: - Onboarding Flow

struct OnboardingFlow: View {
    @Environment(\.modelContext) private var context
    @State private var mode: Mode = .welcome
    @State private var name = ""
    @State private var email = ""
    @State private var reason = ""
    @State private var goToApp = false
    
    enum Mode { case welcome, signupInfo, questions }
    
    var body: some View {
        NavigationStack {
            NavigationLink(destination: RootTabView(), isActive: $goToApp) { EmptyView() }
            VStack(spacing: 24) {
                switch mode {
                case .welcome:
                    Text("Welcome to Clarity").font(.largeTitle).fontWeight(.semibold)
                    Text("A calm space to see your life clearly and live intentionally.").multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Get Started") { mode = .signupInfo }
                        .buttonStyle(.borderedProminent)
                case .signupInfo:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Create your profile").font(.title2).fontWeight(.semibold)
                        TextField("Name", text: $name).textFieldStyle(.roundedBorder)
                        TextField("Email (optional)", text: $email).textFieldStyle(.roundedBorder)
                    }
                    Button("Next") { mode = .questions }
                        .buttonStyle(.borderedProminent)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                case .questions:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What brings you to Clarity?").font(.title2).fontWeight(.semibold)
                        Text("Pick one or type your own.").foregroundStyle(.secondary)
                        ReasonChips(selection: $reason)
                        TextField("Your reason (optional)", text: $reason)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button("Finish") {
                        let profile = UserProfile(name: name, email: email.isEmpty ? "" : email, reason: reason.isEmpty ? nil : reason)
                        context.insert(profile)
                        try? context.save()
                        goToApp = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            }
            .padding()
            .navigationTitle(mode == .welcome ? "" : "Sign Up")
        }
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

// MARK: - Profile View

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State var profile: UserProfile
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $profile.name)
                    TextField("Email", text: $profile.email)
                }
                Section("Your Why") {
                    TextField("Reason", text: Binding(get: { profile.reason ?? "" }, set: { profile.reason = $0.isEmpty ? nil : $0 }))
                }
                Section {
                    Button(role: .destructive) {
                        context.delete(profile)
                        try? context.save()
                        dismiss()
                    } label: { Text("Sign Out") }
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { try? context.save(); dismiss() } }
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

