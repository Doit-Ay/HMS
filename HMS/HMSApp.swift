import SwiftUI
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        // Request notification permissions early so local notifications work when app is closed
        NotificationManager.shared.requestPermission()
        return true
    }
}

@main
struct HMSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @ObservedObject private var session = UserSession.shared

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environmentObject(UserSession.shared)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    // Firebase is now configured — safe to start auth listener
                    _ = AuthManager.shared
                }
                .onChange(of: session.currentUser?.id) { newUserId in
                    if let userId = newUserId {
                        // Start listening for notifications when user logs in
                        NotificationManager.shared.startListening(for: userId)
                    } else {
                        NotificationManager.shared.stopListening()
                    }
                }
        }
    }
}
