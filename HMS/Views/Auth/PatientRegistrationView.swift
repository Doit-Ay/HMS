import SwiftUI

// MARK: - Patient Registration View
struct PatientRegistrationView: View {
    @Environment(\.dismiss) var dismiss
    @State private var fullName     = ""
    @State private var email        = ""
    @State private var phone        = ""
    @State private var password     = ""
    @State private var confirmPass  = ""
    @State private var showPass     = false
    @State private var showConfirm  = false
    @State private var isLoading    = false
    @State private var errorMessage = ""
    @State private var showError    = false
    @State private var animate      = false

    var passwordsMatch: Bool { password == confirmPass }
    var formValid: Bool { !fullName.isEmpty && !email.isEmpty && !phone.isEmpty && !password.isEmpty && passwordsMatch && password.count >= 6 }

    var body: some View {
        ZStack {
            HMSBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [AppTheme.primary, AppTheme.primaryMid],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

                            Image(systemName: "person.badge.plus.fill")
                                .font(.system(size: 34))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 10)
                        .scaleEffect(animate ? 1 : 0.5)
                        .opacity(animate ? 1 : 0)

                        Text("Create Account")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Join CureIt as a patient")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.bottom, 28)

                    // Form Card
                    VStack(spacing: 14) {
                        // Full Name
                        HStack(spacing: 12) {
                            Image(systemName: "person.fill")
                                .foregroundColor(AppTheme.primary).frame(width: 20)
                            TextField("Full Name", text: $fullName)
                                .autocapitalization(.words)
                        }
                        .hmsTextFieldStyle()

                        // Email
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(AppTheme.primary).frame(width: 20)
                            TextField("Email Address", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .hmsTextFieldStyle()

                        // Phone
                        HStack(spacing: 12) {
                            Image(systemName: "phone.fill")
                                .foregroundColor(AppTheme.primary).frame(width: 20)
                            TextField("Phone Number", text: $phone)
                                .keyboardType(.phonePad)
                        }
                        .hmsTextFieldStyle()

                        // Password
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(AppTheme.primary).frame(width: 20)
                            if showPass {
                                TextField("Password (min 6 chars)", text: $password)
                                    .autocapitalization(.none)
                            } else {
                                SecureField("Password (min 6 chars)", text: $password)
                            }
                            Button { showPass.toggle() } label: {
                                Image(systemName: showPass ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        .hmsTextFieldStyle()

                        // Confirm Password
                        HStack(spacing: 12) {
                            Image(systemName: confirmPass.isEmpty ? "lock.fill"
                                  : (passwordsMatch ? "lock.shield.fill" : "lock.trianglebadge.exclamationmark.fill"))
                                .foregroundColor(confirmPass.isEmpty ? AppTheme.primary
                                    : (passwordsMatch ? AppTheme.success : AppTheme.error))
                                .frame(width: 20)
                            if showConfirm {
                                TextField("Confirm Password", text: $confirmPass)
                                    .autocapitalization(.none)
                            } else {
                                SecureField("Confirm Password", text: $confirmPass)
                            }
                            Button { showConfirm.toggle() } label: {
                                Image(systemName: showConfirm ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        .hmsTextFieldStyle()

                        if !confirmPass.isEmpty && !passwordsMatch {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppTheme.error)
                                Text("Passwords do not match")
                                    .foregroundColor(AppTheme.error)
                                    .font(.system(size: 13, design: .rounded))
                                Spacer()
                            }
                        }

                        // Register Button
                        Button {
                            Task { await registerPatient() }
                        } label: {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.seal.fill")
                                    Text("Create Account")
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isLoading || !formValid)

                    }
                    .padding(24)
                    .glassCard()
                    .padding(.horizontal, 20)
                    .offset(y: animate ? 0 : 40)
                    .opacity(animate ? 1 : 0)

                    Text("By creating an account, you agree to our Terms of Service and Privacy Policy.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Register")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animate = true
            }
        }
    }

    private func registerPatient() async {
        isLoading = true
        do {
            try await AuthManager.shared.registerPatient(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                fullName: fullName.trimmingCharacters(in: .whitespaces),
                phone: phone.trimmingCharacters(in: .whitespaces)
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        PatientRegistrationView()
    }
}
