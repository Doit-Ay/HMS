import SwiftUI
import UIKit

// MARK: - Patient Login View
struct PatientLoginView: View {
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

                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 38))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                        .scaleEffect(animate ? 1 : 0.5)
                        .opacity(animate ? 1 : 0)

                        Text("Patient Login")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Sign in to access your health records")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 32)

                    // Glass Card Form
                    VStack(spacing: 16) {
                        // Email
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

                        // Password
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

                        // Login Button
                        Button {
                            Task { await loginPatient() }
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
                    .padding(.horizontal, 20)
                    .offset(y: animate ? 0 : 40)
                    .opacity(animate ? 1 : 0)

                    // Register
                    VStack(spacing: 8) {
                        Text("New to CureIt?")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)

                        Button("Create Patient Account") {
                            showRegister = true
                        }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.primary)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
                .padding(.vertical, 20)
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

    // MARK: - Actions
    private func loginPatient() async {
        isLoading = true
        do {
            try await AuthManager.shared.patientLogin(email: email.trimmingCharacters(in: .whitespaces), password: password)
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
            try await AuthManager.shared.googleSignInPatient(presenting: rootVC)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        PatientLoginView()
    }
}
