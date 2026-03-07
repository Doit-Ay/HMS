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

    static let shared = UserSession()

    private init() {}

    func setUser(_ user: HMSUser) {
        self.currentUser = user
        self.userRole = user.role
        self.isLoggedIn = true
        self.isLoading = false
    }

    func clearSession() {
        self.currentUser = nil
        self.userRole = nil
        self.isLoggedIn = false
        self.isLoading = false
    }

    func setLoading(_ loading: Bool) {
        self.isLoading = loading
    }
}
