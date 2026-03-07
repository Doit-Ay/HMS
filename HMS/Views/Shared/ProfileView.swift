import SwiftUI

// MARK: - Shared Profile View (used by all roles)
struct ProfileView: View {
    @ObservedObject var session = UserSession.shared
    @State private var showLogoutAlert = false
    @State private var isLoggingOut    = false

    var user: HMSUser? { session.currentUser }

    var body: some View {
        ZStack {
            HMSBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // Avatar Header
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [AppTheme.primary, AppTheme.primaryMid],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 100, height: 100)
                                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

                            Image(systemName: user?.role.sfSymbol ?? "person.circle.fill")
                                .font(.system(size: 46))
                                .foregroundColor(.white)
                        }

                        VStack(spacing: 4) {
                            Text(user?.fullName ?? "—")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)

                            Text(user?.role.displayName ?? "")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 5)
                                .background(AppTheme.primary)
                                .cornerRadius(20)
                        }
                    }
                    .padding(.top, 20)

                    // Info Card
                    VStack(spacing: 0) {
                        ProfileRow(icon: "envelope.fill",       label: "Email",        value: user?.email)
                        Divider().padding(.horizontal, 16)
                        ProfileRow(icon: "phone.fill",          label: "Phone",        value: user?.phoneNumber)
                        if let dob = user?.dateOfBirth {
                            Divider().padding(.horizontal, 16)
                            ProfileRow(icon: "calendar",        label: "Date of Birth", value: dob)
                        }
                        if let gender = user?.gender {
                            Divider().padding(.horizontal, 16)
                            ProfileRow(icon: "person.fill",     label: "Gender",       value: gender)
                        }
                        if let blood = user?.bloodGroup {
                            Divider().padding(.horizontal, 16)
                            ProfileRow(icon: "drop.fill",       label: "Blood Group",  value: blood)
                        }
                        if let dept = user?.department {
                            Divider().padding(.horizontal, 16)
                            ProfileRow(icon: "building.2.fill", label: "Department",   value: dept)
                        }
                        if let spec = user?.specialization {
                            Divider().padding(.horizontal, 16)
                            ProfileRow(icon: "stethoscope",     label: "Specialization", value: spec)
                        }
                        if let empID = user?.employeeID {
                            Divider().padding(.horizontal, 16)
                            ProfileRow(icon: "creditcard.fill", label: "Employee ID",  value: empID)
                        }
                    }
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
                    .padding(.horizontal, 20)

                    // Logout Button
                    Button {
                        showLogoutAlert = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                            Text("Sign Out")
                        }
                    }
                    .buttonStyle(LogoutButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("My Profile")
        .navigationBarTitleDisplayMode(.large)
        .alert("Sign Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    private func signOut() {
        try? AuthManager.shared.signOut()
    }
}

// MARK: - Profile Row
struct ProfileRow: View {
    let icon: String
    let label: String
    let value: String?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.primary)
                .frame(width: 28)

            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 110, alignment: .leading)

            Spacer()

            Text(value ?? "Not provided")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(value != nil ? AppTheme.textPrimary : AppTheme.textSecondary.opacity(0.5))
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Logout Button Style
struct LogoutButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(AppTheme.error)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(AppTheme.error.opacity(0.1))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.error.opacity(0.3), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
