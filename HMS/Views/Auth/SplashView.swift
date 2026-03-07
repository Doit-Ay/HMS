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
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.primary, AppTheme.primaryMid],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                        .scaleEffect(pulse ? 1.05 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: pulse
                        )

                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 52, weight: .medium))
                        .foregroundColor(.white)
                }

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
