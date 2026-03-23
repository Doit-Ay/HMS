import SwiftUI

// MARK: - Role Selection View
struct RoleSelectionView: View {
    @State private var navigateToPatient = false
    @State private var navigateToStaff   = false
    @State private var animateCards      = false

    var body: some View {
        NavigationStack {
            ZStack {
                HMSBackground()

                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.primary, AppTheme.primaryMid],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

                            Image(systemName: "cross.case.fill")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 60)

                        Text("Welcome to CureIt")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Select your role to continue")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.bottom, 50)

                    // Role Cards
                    VStack(spacing: 20) {
                        RoleCard(
                            title: "Patient",
                            subtitle: "Book appointments, view records",
                            icon: "person.circle.fill",
                            color: AppTheme.primary,
                            delay: 0.1
                        ) {
                            navigateToPatient = true
                        }
                        .offset(x: animateCards ? 0 : -UIScreen.main.bounds.width)

                        RoleCard(
                            title: "Staff",
                            subtitle: "Doctors, lab technicians & administration",
                            icon: "cross.case.fill",
                            color: AppTheme.primaryMid,
                            delay: 0.2
                        ) {
                            navigateToStaff = true
                        }
                        .offset(x: animateCards ? 0 : UIScreen.main.bounds.width)
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Footer
                    Text("Powered by CureIt • Secure & Trusted")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                        .padding(.bottom, 30)
                }
            }
            .navigationDestination(isPresented: $navigateToPatient) {
                PatientLoginView()
            }
            .navigationDestination(isPresented: $navigateToStaff) {
                StaffLoginView()
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                    animateCards = true
                }
            }
        }
    }
}

// MARK: - Role Card
struct RoleCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let delay: Double
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 64, height: 64)

                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(color.opacity(0.6))
            }
            .padding(20)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppTheme.cardSurface)
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.2), lineWidth: 1.5)
                }
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}

#Preview {
    RoleSelectionView()
}
