import SwiftUI

// MARK: - Colors
extension Color {
    static let clarityBackground = Color(uiColor: .systemGroupedBackground)
    static let clarityCard = Color(uiColor: .secondarySystemGroupedBackground)
    
    // Brand Colors
    static let clarityBlue = Color(hex: "4A90E2")
    static let clarityPurple = Color(hex: "9013FE")
    static let clarityTeal = Color(hex: "50E3C2")
    static let clarityOrange = Color(hex: "F5A623")
    static let clarityPink = Color(hex: "BD10E0")
    static let clarityYellow = Color(hex: "F8E71C")
    static let clarityGreen = Color(hex: "7ED321")
    
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
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.clarityCard, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
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
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .shadow(color: Color.clarityPurple.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.primary)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Extensions

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
    
    func titleStyle() -> some View {
        self.font(.system(size: 28, weight: .bold, design: .rounded))
    }
    
    func subtitleStyle() -> some View {
        self.font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
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
        .background(Color.clarityCard)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
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
                .frame(height: 100)
                .padding(8)
                .background(Color.clarityCard)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
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
                    isSelected ? AnyShapeStyle(Color.clarityBlue.gradient) : AnyShapeStyle(Color.clarityCard)
                )
                .clipShape(Capsule())
                .shadow(color: isSelected ? Color.clarityBlue.opacity(0.3) : Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}
