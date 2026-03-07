import SwiftUI

// MARK: - Forgot Password View
struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var email     = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertTitle   = ""
    @State private var alertMessage = ""
    @State private var isSuccess    = false

    var body: some View {
        NavigationStack {
            ZStack {
                HMSBackground()

                VStack(spacing: 30) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [AppTheme.primary, AppTheme.primaryMid],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 90, height: 90)
                            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

                        Image(systemName: "lock.rotation")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 30)

                    VStack(spacing: 8) {
                        Text("Reset Password")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Enter your email address and we'll send you a link to reset your password.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    }

                    // Form
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 20)
                            TextField("Your Email Address", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .hmsTextFieldStyle()

                        Button {
                            Task { await sendReset() }
                        } label: {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text("Send Reset Link")
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isLoading || email.isEmpty)
                    }
                    .padding(24)
                    .glassCard()
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textSecondary)
                            .font(.system(size: 22))
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {
                    if isSuccess { dismiss() }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func sendReset() async {
        isLoading = true
        do {
            try await AuthManager.shared.sendPasswordReset(email: email.trimmingCharacters(in: .whitespaces))
            alertTitle   = "Email Sent"
            alertMessage = "A password reset link has been sent to \(email). Please check your inbox."
            isSuccess    = true
        } catch {
            alertTitle   = "Error"
            alertMessage = error.localizedDescription
            isSuccess    = false
        }
        showAlert = true
        isLoading = false
    }
}

#Preview {
    ForgotPasswordView()
}
