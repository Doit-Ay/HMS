import SwiftUI

// MARK: - App Router (Root Navigation)
// Listens to UserSession and routes to the appropriate screen
struct AppRouter: View {
    @ObservedObject var session = UserSession.shared

    var body: some View {
        Group {
            if session.isLoading {
                SplashView()
            } else if !session.isLoggedIn {
                LoginView()
            } else {
                dashboardView
            }
        }
        .animation(.easeInOut(duration: 0.4), value: session.isLoggedIn)
        .animation(.easeInOut(duration: 0.4), value: session.isLoading)
    }

    @ViewBuilder
    private var dashboardView: some View {
        switch session.userRole {
        case .patient:
            NavigationStack {
                PatientHomeView()
            }

        case .admin:
            AdminTabView()

        case .doctor:
            StaffTabView(role: .doctor)

        case .labTechnician:
            StaffTabView(role: .labTechnician)

        case .none:
            LoginView()
        }
    }
}

#Preview {
    AppRouter()
}
