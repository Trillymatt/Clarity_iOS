import SwiftUI

// MARK: - Colors
// Jarvis-style dark glass palette. Names are kept stable across the app so every
// existing call site re-themes automatically — only values change here.
extension Color {
    /// Near-black void background (the base of every screen)
    static let clarityBackground = Color(hex: "#05070C")
    /// Elevated dark surface used beneath glass materials
    static let claritySurface = Color(hex: "#121722")
    /// Solid card fallback (used where materials aren't appropriate, e.g. widgets)
    static let clarityCard = Color(hex: "#131826")

    // Brand / accent colors — electric, built to glow on near-black
    static let clarityBlue = Color(hex: "#4DC8FF")
    static let clarityPurple = Color(hex: "#8C7CFF")
    static let clarityTeal = Color(hex: "#35E6C0")
    static let clarityOrange = Color(hex: "#FFB454")
    static let clarityPink = Color(hex: "#FF6EA8")
    static let clarityYellow = Color(hex: "#FFD666")
    static let clarityGreen = Color(hex: "#3ADD97")

    // Gradients
    static let primaryGradient = LinearGradient(
        colors: [clarityBlue, clarityPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warmGradient = LinearGradient(
        colors: [clarityOrange, clarityPink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let coolGradient = LinearGradient(
        colors: [clarityTeal, clarityBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let claritySuccess = LinearGradient(
        colors: [clarityGreen, clarityTeal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Hex Color Helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 20
    var glow: Color? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(Color.claritySurface.opacity(0.6), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: (glow ?? .clear).opacity(glow == nil ? 0 : 0.28), radius: 18, x: 0, y: 8)
            .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 8)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.primaryGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .shadow(color: Color.clarityBlue.opacity(0.45), radius: 16, x: 0, y: 6)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.primary)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Jarvis Glow Border
// A rotating angular-gradient glow, generalized from the input-focus effect
// originally built for WeeklyReviewView. Used for the assistant dock/chat input
// and anywhere else that should read as "AI is listening."
struct JarvisGlowBorder: ViewModifier {
    var isActive: Bool
    var cornerRadius: CGFloat = 20
    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        AngularGradient(
                            colors: [Color.clarityBlue, Color.clarityPurple, Color.clarityBlue],
                            center: .center,
                            startAngle: .degrees(rotation),
                            endAngle: .degrees(rotation + 360)
                        ),
                        lineWidth: isActive ? 2 : 0
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        AngularGradient(
                            colors: [Color.clarityBlue, Color.clarityPurple, Color.clarityBlue],
                            center: .center,
                            startAngle: .degrees(rotation),
                            endAngle: .degrees(rotation + 360)
                        ),
                        lineWidth: 4
                    )
                    .blur(radius: 10)
                    .opacity(isActive ? 0.5 : 0)
            )
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Extensions

extension View {
    func cardStyle(padding: CGFloat = 16, cornerRadius: CGFloat = 20, glow: Color? = nil) -> some View {
        modifier(CardStyle(padding: padding, cornerRadius: cornerRadius, glow: glow))
    }

    func titleStyle() -> some View {
        self.font(.system(size: 28, weight: .bold, design: .rounded))
    }

    func subtitleStyle() -> some View {
        self.font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
    }

    /// Rotating glow border that reads as "AI is listening / active."
    func jarvisGlow(active: Bool, cornerRadius: CGFloat = 20) -> some View {
        modifier(JarvisGlowBorder(isActive: active, cornerRadius: cornerRadius))
    }
}

// MARK: - Shared Components

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .font(.body)

            TextField(placeholder, text: $text)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct CustomTextEditor: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .frame(height: 100)
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

struct SelectionChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(
                    isSelected ? AnyShapeStyle(Color.clarityBlue.gradient) : AnyShapeStyle(.ultraThinMaterial)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(isSelected ? 0 : 0.1), lineWidth: 1)
                )
                .shadow(color: isSelected ? Color.clarityBlue.opacity(0.35) : .clear, radius: 8, x: 0, y: 3)
        }
    }
}
