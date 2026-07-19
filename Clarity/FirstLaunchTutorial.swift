import SwiftUI

struct FirstLaunchTutorial: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var currentPage = 0
    @State private var offset: CGFloat = 0
    
    let pages: [TutorialPage] = [
        TutorialPage(
            icon: "sparkles",
            title: "Welcome to Clarity",
            subtitle: "Your Life, Simplified",
            description: "Track everything that matters in one beautiful, intuitive app.",
            gradient: LinearGradient.clarityPrimary
        ),
        TutorialPage(
            icon: "target",
            title: "Stay Focused",
            subtitle: "Tasks & Projects",
            description: "Organize your day with smart tasks. Break down big goals with AI-powered project planning.",
            gradient: LinearGradient.claritySuccess
        ),
        TutorialPage(
            icon: "repeat.circle.fill",
            title: "Build Habits",
            subtitle: "Consistency Is Key",
            description: "Track daily habits, build streaks, and become your best self one day at a time.",
            gradient: LinearGradient(colors: [.clarityOrange, .clarityYellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        TutorialPage(
            icon: "heart.fill",
            title: "Capture Moments",
            subtitle: "Remember What Matters",
            description: "Journal wins, gratitude, and memories. Reflect on your journey.",
            gradient: LinearGradient(colors: [.clarityPink, .clarityPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        TutorialPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Track Progress",
            subtitle: "Your Clarity Score",
            description: "See your overall well-being at a glance. Balance work, health, and mindfulness.",
            gradient: LinearGradient(colors: [.clarityTeal, .clarityBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        TutorialPage(
            icon: "calendar.badge.clock",
            title: "Weekly Reviews",
            subtitle: "Reflect & Plan",
            description: "Every Sunday, look back on your week and set intentions for the next.",
            gradient: LinearGradient(colors: [.clarityBlue, .clarityPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    ]
    
    var body: some View {
        ZStack {
            // Dynamic gradient background
            pages[currentPage].gradient
                .opacity(0.08)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: currentPage)
            
            Color.clarityBackground
                .opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with skip
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            dismiss()
                        }
                    } label: {
                        Text("Skip")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        TutorialPageView(page: pages[index], pageNumber: index + 1, totalPages: pages.count)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.interpolatingSpring(mass: 1.2, stiffness: 120, damping: 20, initialVelocity: 0), value: currentPage)
                
                // Custom page indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                            .fill(index == currentPage ? pages[currentPage].gradient : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: currentPage)
                    }
                }
                .padding(.bottom, 24)
                
                // Navigation buttons
                HStack(spacing: 12) {
                    if currentPage > 0 {
                        Button {
                            withAnimation(.interpolatingSpring(mass: 1.2, stiffness: 120, damping: 20, initialVelocity: 0)) {
                                currentPage -= 1
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Back")
                                    .font(.headline)
                            }
                            .foregroundStyle(.primary.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.clarityCard)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    
                    Button {
                        withAnimation(.interpolatingSpring(mass: 1.2, stiffness: 120, damping: 20, initialVelocity: 0)) {
                            if currentPage < pages.count - 1 {
                                currentPage += 1
                            } else {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                                .font(.headline)
                            if currentPage < pages.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                            } else {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(pages[currentPage].gradient)
                        .cornerRadius(16)
                        .shadow(color: Color.clarityBlue.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, max(32, 32))
            }
        }
    }
}

struct TutorialPage {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let gradient: LinearGradient
}

struct TutorialPageView: View {
    let page: TutorialPage
    let pageNumber: Int
    let totalPages: Int
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Icon with glassmorphism
            ZStack {
                // Outer glow
                Circle()
                    .fill(page.gradient)
                    .frame(width: 180, height: 180)
                    .blur(radius: 40)
                    .opacity(0.3)
                
                // Card background
                Circle()
                    .fill(Color.clarityCard)
                    .frame(width: 140, height: 140)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                
                // Icon
                Image(systemName: page.icon)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(page.gradient)
            }
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
            .padding(.bottom, 48)
            
            // Content card
            VStack(spacing: 16) {
                // Page number
                Text("\(pageNumber) / \(totalPages)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .padding(.bottom, 4)
                
                // Subtitle
                Text(page.subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(page.gradient)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                // Title
                Text(page.title)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                
                // Description
                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.clarityCard)
                    .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 24)
            .offset(y: appeared ? 0 : 20)
            .opacity(appeared ? 1 : 0)
            
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 1.1, dampingFraction: 0.85).delay(0.25)) {
                appeared = true
            }
        }
        .onChange(of: pageNumber) { _, _ in
            appeared = false
            withAnimation(.spring(response: 1.1, dampingFraction: 0.85).delay(0.3)) {
                appeared = true
            }
        }
    }
}

#Preview {
    FirstLaunchTutorial()
}
