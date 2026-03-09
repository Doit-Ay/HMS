import SwiftUI

// MARK: - Splash Screen
struct SplashView: View {
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0
    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            HMSBackground()

            VStack(spacing: 24) {
                // App logo / icon
                HMSLogo(size: 120)
                    .scaleEffect(pulse ? 1.05 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: pulse
                    )

                VStack(spacing: 6) {
                    Text("HMS")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Hospital Management System")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                    scale = 1.0
                    opacity = 1.0
                }
                pulse = true
            }
        }
    }
}

#Preview {
    SplashView()
}
