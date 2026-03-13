import SwiftUI

// MARK: - OTP Verification View
struct OTPVerificationView: View {
    @ObservedObject var session = UserSession.shared

    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var animate = false
    @State private var resendCountdown = 60
    @State private var canResend = false
    @State private var timer: Timer?
    @State private var showSuccess = false

    @FocusState private var focusedField: Int?

    private var otpCode: String {
        otpDigits.joined()
    }

    private var isOTPComplete: Bool {
        otpCode.count == 6 && otpDigits.allSatisfy { !$0.isEmpty }
    }

    private var maskedEmail: String {
        guard let email = session.pendingOTPEmail else { return "your email" }
        let parts = email.split(separator: "@")
        guard parts.count == 2 else { return email }
        let name = String(parts[0])
        let domain = String(parts[1])
        if name.count <= 2 {
            return "\(name)@\(domain)"
        }
        let visible = String(name.prefix(2))
        let masked = String(repeating: "•", count: min(name.count - 2, 4))
        return "\(visible)\(masked)@\(domain)"
    }

    var body: some View {
        ZStack {
            HMSBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    otpCard
                    resendSection
                }
                .padding(.vertical, 40)
            }
        }
        .alert("Verification Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animate = true
            }
            startResendTimer()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = 0
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(AppTheme.primary.opacity(0.1))
                    .frame(width: 110, height: 110)

                Circle()
                    .fill(LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryMid],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 88, height: 88)
                    .shadow(color: AppTheme.primary.opacity(0.3), radius: 12, x: 0, y: 6)

                Image(systemName: showSuccess ? "checkmark.shield.fill" : "envelope.badge.shield.half.filled.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .scaleEffect(animate ? 1 : 0.4)
            .opacity(animate ? 1 : 0)

            Text("Verify Your Email")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text("We've sent a 6-digit code to")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)

            Text(maskedEmail)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.primary)
        }
        .padding(.bottom, 36)
    }

    // MARK: - OTP Card
    private var otpCard: some View {
        VStack(spacing: 24) {
            // 6-digit OTP fields
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    OTPDigitField(
                        text: $otpDigits[index],
                        isFocused: focusedField == index,
                        onTap: { focusedField = index }
                    )
                    .focused($focusedField, equals: index)
                    .onChange(of: otpDigits[index]) { _, newValue in
                        handleDigitChange(index: index, newValue: newValue)
                    }
                }
            }
            .padding(.horizontal, 4)

            // Verify button
            Button {
                Task { await verifyOTP() }
            } label: {
                HStack(spacing: 8) {
                    if isVerifying {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Verify Code")
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isVerifying || !isOTPComplete)
            .opacity(isOTPComplete ? 1 : 0.6)
        }
        .padding(24)
        .glassCard()
        .padding(.horizontal, 20)
        .offset(y: animate ? 0 : 50)
        .opacity(animate ? 1 : 0)
    }

    // MARK: - Resend Section
    private var resendSection: some View {
        VStack(spacing: 12) {
            Text("Didn't receive the code?")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)

            if canResend {
                Button {
                    Task { await resendOTP() }
                } label: {
                    HStack(spacing: 6) {
                        if isResending {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(AppTheme.primary)
                        } else {
                            Image(systemName: "arrow.clockwise.circle.fill")
                        }
                        Text("Resend Code")
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.primary)
                }
                .disabled(isResending)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 13))
                    Text("Resend in \(resendCountdown)s")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundColor(AppTheme.textSecondary.opacity(0.7))
            }

            // Sign out option
            Button {
                try? AuthManager.shared.signOut()
            } label: {
                Text("Use a different account")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.top, 8)
        }
        .padding(.top, 28)
        .padding(.bottom, 40)
    }

    // MARK: - Digit Input Handling

    private func handleDigitChange(index: Int, newValue: String) {
        // Only allow single digit
        if newValue.count > 1 {
            // Handle paste: distribute digits across all fields
            let digits = Array(newValue.filter { $0.isNumber })
            if digits.count >= 6 {
                for i in 0..<6 {
                    otpDigits[i] = String(digits[i])
                }
                focusedField = 5
                return
            }
            otpDigits[index] = String(newValue.suffix(1))
        }

        // Auto-advance to next field
        if !newValue.isEmpty && index < 5 {
            focusedField = index + 1
        }
    }

    // MARK: - Actions

    private func verifyOTP() async {
        guard let email = session.pendingOTPEmail else { return }
        isVerifying = true
        do {
            let success = try await EmailOTPManager.shared.verifyOTP(email: email, code: otpCode)
            if success {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showSuccess = true
                }
                // Brief delay to show success state
                try? await Task.sleep(nanoseconds: 600_000_000)
                UserSession.shared.confirmOTPVerification()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            // Clear OTP fields on error
            otpDigits = Array(repeating: "", count: 6)
            focusedField = 0
        }
        isVerifying = false
    }

    private func resendOTP() async {
        guard let email = session.pendingOTPEmail else { return }
        isResending = true
        do {
            try await EmailOTPManager.shared.resendOTP(to: email)
            // Reset timer
            canResend = false
            resendCountdown = 60
            startResendTimer()
        } catch {
            errorMessage = "Failed to resend code. Please try again."
            showError = true
        }
        isResending = false
    }

    private func startResendTimer() {
        timer?.invalidate()
        canResend = false
        resendCountdown = 60
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if resendCountdown > 1 {
                    resendCountdown -= 1
                } else {
                    canResend = true
                    timer?.invalidate()
                }
            }
        }
    }
}

// MARK: - Single OTP Digit Field
struct OTPDigitField: View {
    @Binding var text: String
    let isFocused: Bool
    let onTap: () -> Void

    var body: some View {
        TextField("", text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 26, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
            .frame(width: 48, height: 58)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isFocused
                          ? AppTheme.primaryLight
                          : Color.white.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isFocused ? AppTheme.primary : AppTheme.primaryMid.opacity(0.3),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .shadow(color: isFocused ? AppTheme.primary.opacity(0.15) : .clear,
                    radius: 6, x: 0, y: 2)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
            .onTapGesture { onTap() }
    }
}

#Preview {
    OTPVerificationView()
}
