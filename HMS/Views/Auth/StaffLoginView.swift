import SwiftUI
import UIKit

// MARK: - Staff Login View
struct StaffLoginView: View {
    @State private var email        = ""
    @State private var password     = ""
    @State private var showPassword = false
    @State private var isLoading    = false
    @State private var errorMessage = ""
    @State private var showError    = false
    @State private var showForgot   = false
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
                                    colors: [AppTheme.primaryMid, AppTheme.primaryDark],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

                            Image(systemName: "cross.case.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                        .scaleEffect(animate ? 1 : 0.5)
                        .opacity(animate ? 1 : 0)

                        Text("Staff Login")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Authorized personnel only")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.bottom, 32)

                    // Glass Card Form
                    VStack(spacing: 16) {
                        // Email
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(AppTheme.primaryMid)
                                .frame(width: 20)
                            TextField("Staff Email", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .hmsTextFieldStyle()

                        // Password
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(AppTheme.primaryMid)
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
                            // Staff badge notice
                            HStack(spacing: 5) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.primaryMid)
                                Text("Use credentials provided by admin")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            Spacer()
                            Button("Forgot Password?") {
                                showForgot = true
                            }
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.primaryMid)
                        }

                        // Login Button
                        Button {
                            Task { await loginStaff() }
                        } label: {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "shield.checkered")
                                    Text("Staff Sign In")
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isLoading || email.isEmpty || password.isEmpty)

                        // Divider
                        HStack {
                            Rectangle().fill(AppTheme.primaryMid.opacity(0.3)).frame(height: 1)
                            Text("or").font(.system(size: 13, design: .rounded)).foregroundColor(AppTheme.textSecondary).padding(.horizontal, 10)
                            Rectangle().fill(AppTheme.primaryMid.opacity(0.3)).frame(height: 1)
                        }

                        // Google Sign-In
                        Button {
                            Task { await googleSignIn() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "globe")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppTheme.primaryMid)
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

                    // No registration notice
                    VStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.primaryMid.opacity(0.5))
                        Text("Staff accounts are created by the administrator.\nContact your hospital admin to get access.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 30)
                    .padding(.horizontal, 40)
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
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animate = true
            }
        }
    }

    // MARK: - Actions
    private func loginStaff() async {
        isLoading = true
        do {
            try await AuthManager.shared.staffLogin(email: email.trimmingCharacters(in: .whitespaces), password: password)
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
            try await AuthManager.shared.googleSignInStaff(presenting: rootVC)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        StaffLoginView()
    }
}
