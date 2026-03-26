import Foundation
import Combine

// MARK: - User Session (ObservableObject)
// NOTE: This class references FirebaseAuth types as strings to avoid
// direct import dependency. The AuthManager populates this.
@MainActor
class UserSession: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: HMSUser? = nil
    @Published var userRole: UserRole? = nil
    @Published var isLoading: Bool = true

    // OTP verification state
    @Published var needsOTPVerification: Bool = false
    @Published var pendingOTPEmail: String? = nil

    static let shared = UserSession()

    private init() {}

    /// Sets user data. When `requiresOTP` is true (fresh login/register),
    /// the user must verify OTP before reaching the dashboard.
    /// When false (app reopen via auth listener), the user goes straight to dashboard.
    func setUser(_ user: HMSUser, requiresOTP: Bool = false) {
        self.currentUser = user
        self.userRole = user.role
        self.isLoggedIn = true
        self.needsOTPVerification = requiresOTP
        self.pendingOTPEmail = requiresOTP ? user.email : nil
        self.isLoading = false
    }

    func confirmOTPVerification() {
        self.needsOTPVerification = false
        self.pendingOTPEmail = nil
    }

    func clearSession() {
        self.currentUser = nil
        self.userRole = nil
        self.isLoggedIn = false
        self.isLoading = false
        self.needsOTPVerification = false
        self.pendingOTPEmail = nil
    }

    func setLoading(_ loading: Bool) {
        self.isLoading = loading
    }
}
