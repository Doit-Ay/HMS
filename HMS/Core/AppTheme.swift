import SwiftUI

// MARK: - Color Theme
struct AppTheme {
    // Primary palette from the design
    static let primary        = Color(hex: "#05AA97")   // Verdigris
    static let primaryLight   = Color(hex: "#D9FEFE")   // Frozen Water
    static let primaryMid     = Color(hex: "#66BEB3")   // Tropical Teal
    static let primaryDark    = Color(hex: "#74C4BA")   // Pearl Aqual

    // Background tones
    static let background     = Color(hex: "#F0FAFA")
    static let cardBackground = Color.white.opacity(0.7)
    static let darkBackground = Color(hex: "#0A1628")

    // Text
    static let textPrimary    = Color(hex: "#1A2B3C")
    static let textSecondary  = Color(hex: "#6B7B8D")
    static let textOnPrimary  = Color.white

    // Status
    static let success        = Color(hex: "#05AA97")
    static let warning        = Color(hex: "#F59E0B")
    static let error          = Color(hex: "#EF4444")
}

// MARK: - Hex Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Glass Card Modifier
struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(0.25))
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                }
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryMid],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundColor(AppTheme.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(AppTheme.primaryLight.opacity(0.8))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.primary.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Custom TextField Style
struct HMSTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Color.white.opacity(0.8))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.primaryMid.opacity(0.3), lineWidth: 1)
            )
    }
}

extension View {
    func hmsTextFieldStyle() -> some View {
        modifier(HMSTextFieldStyle())
    }
}

// MARK: - Background Gradient
struct HMSBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                AppTheme.primaryLight,
                Color.white,
                AppTheme.primaryLight.opacity(0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
