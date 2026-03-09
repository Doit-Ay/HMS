import SwiftUI
import UIKit

// MARK: - Unified Login View
struct LoginView: View {
    @State private var email        = ""
    @State private var password     = ""
    @State private var showPassword = false
    @State private var isLoading    = false
    @State private var errorMessage = ""
    @State private var showError    = false
    @State private var showForgot   = false
    @State private var showRegister = false
    @State private var animate      = false

    var body: some View {
        NavigationStack {
            ZStack {
                HMSBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerSection
                        formCard
                        registerSection
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showForgot) {
                ForgotPasswordView()
            }
            .navigationDestination(isPresented: $showRegister) {
                PatientRegistrationView()
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    animate = true
                }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 10) {
            HMSLogo(size: 80)
            .padding(.top, 20)
            .scaleEffect(animate ? 1 : 0.5)
            .opacity(animate ? 1 : 0)

            Text("Welcome to HMS")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text("Sign in to continue")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 32)
    }

    // MARK: - Form Card
    private var formCard: some View {
        VStack(spacing: 16) {
            // Email Field
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .foregroundColor(AppTheme.primary)
                    .frame(width: 20)
                TextField("Email Address", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .hmsTextFieldStyle()

            // Password Field
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundColor(AppTheme.primary)
                    .frame(width: 20)
                if showPassword {
                    TextField("Password", text: $password)
                        .autocapitalization(.none)
                } else {
                    SecureField("Password", text: $password)
                }
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .hmsTextFieldStyle()

            // Forgot Password
            HStack {
                Spacer()
                Button("Forgot Password?") {
                    showForgot = true
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.primary)
            }

            // Sign In Button
            Button {
                Task { await login() }
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Sign In")
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isLoading || email.isEmpty || password.isEmpty)

            // Divider
            HStack {
                Rectangle()
                    .fill(AppTheme.primaryMid.opacity(0.3))
                    .frame(height: 1)
                Text("or")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal, 10)
                Rectangle()
                    .fill(AppTheme.primaryMid.opacity(0.3))
                    .frame(height: 1)
            }

            // Google Sign-In
            Button {
                Task { await googleSignIn() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.primary)
                    Text("Continue with Google")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(24)
        .glassCard()
        .padding(.horizontal, 20)
        .offset(y: animate ? 0 : 40)
        .opacity(animate ? 1 : 0)
    }

    // MARK: - Register Section
    private var registerSection: some View {
        VStack(spacing: 8) {
            Text("New here?")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)

            Button("Register as Patient") {
                showRegister = true
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(AppTheme.primary)
        }
        .padding(.top, 24)
        .padding(.bottom, 40)
    }

    // MARK: - Actions

    private func login() async {
        isLoading = true
        do {
            try await AuthManager.shared.login(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }

    private func googleSignIn() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        isLoading = true
        do {
            try await AuthManager.shared.googleSignInUnified(presenting: rootVC)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
}

#Preview {
    LoginView()
}
