import Foundation
import UserNotifications
import FirebaseFirestore
import Combine

// MARK: - Notification Manager
/// Handles local push notifications and Firestore notification records.
/// Local notifications fire even when the app is closed/backgrounded.
@MainActor
class NotificationManager: NSObject, ObservableObject {

    static let shared = NotificationManager()
    private var db: Firestore { Firestore.firestore() }
    private var listener: ListenerRegistration?

    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0 {
        didSet {
            UNUserNotificationCenter.current().setBadgeCount(unreadCount) { _ in }
        }
    }

    private override init() {
        super.init()
    }

    // MARK: - Request Permission

    /// Request notification permissions — call once at app launch.
    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("⚠️ Notification permission error: \(error.localizedDescription)")
            }
            print("🔔 Notification permission granted: \(granted)")
        }
        // Set delegate so notifications show even while app is in foreground
        center.delegate = self
    }

    // MARK: - Schedule Local Notification

    /// Schedules a local push notification that appears immediately (within 1 second).
    /// Works when app is backgrounded or closed.
    func sendLocalNotification(title: String, body: String, identifier: String? = nil) {
        // Trigger after 1 second — ensures delivery even if app is in foreground
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: unreadCount + 1)
        
        // iOS 15+: Time-sensitive notifications stay on screen longer and bypass Focus modes
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        // Trigger after 1 second — ensures delivery even if app is in foreground
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = identifier ?? UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Firestore Listener

    /// Start listening for notifications for a specific user (real-time).
    func startListening(for userId: String) {
        stopListening()

        listener = db.collection("notifications")
            .whereField("recipientId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("⚠️ Notification listener error: \(error.localizedDescription)")
                    return
                }
                guard let documents = snapshot?.documents else { return }

                let fetched = documents.compactMap { doc -> AppNotification? in
                    try? Firestore.Decoder().decode(AppNotification.self, from: doc.data())
                }.sorted { $0.createdAt > $1.createdAt }

                Task { @MainActor in
                    self.notifications = fetched
                    self.unreadCount = fetched.filter { !$0.isRead }.count
                }

                // Check for newly added documents and fire local notifications
                // Since this is for single-device testing (logging out and in),
                // we want to notify for ANY unread notification that we haven't alerted for yet.
                snapshot?.documentChanges.forEach { change in
                    if change.type == .added {
                        if let notif = try? Firestore.Decoder().decode(AppNotification.self, from: change.document.data()) {
                            // Fire if it's unread
                            if !notif.isRead {
                                // To avoid spam, we'd normally only fire if it's very recent,
                                // but for simulator testing across accounts, we'll fire for any unread.
                                self.sendLocalNotification(
                                    title: notif.title,
                                    body: notif.message,
                                    identifier: notif.id
                                )
                            }
                        }
                    }
                }
            }
    }

    /// Stop the Firestore listener.
    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Mark as Read

    func markAsRead(notificationId: String) async {
        do {
            try await db.collection("notifications").document(notificationId).updateData([
                "isRead": true
            ])
        } catch {
            print("⚠️ Failed to mark notification as read: \(error.localizedDescription)")
        }
    }

    /// Mark all notifications as read for a user
    func markAllAsRead(for userId: String) async {
        do {
            let snapshot = try await db.collection("notifications")
                .whereField("recipientId", isEqualTo: userId)
                .whereField("isRead", isEqualTo: false)
                .getDocuments()
            for doc in snapshot.documents {
                try await doc.reference.updateData(["isRead": true])
            }
            await MainActor.run {
                for i in notifications.indices {
                    notifications[i].isRead = true
                }
                unreadCount = 0
            }
        } catch {
            print("⚠️ Failed to mark all as read: \(error.localizedDescription)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Show notification banner even when app is in the foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Could navigate to notifications view here in the future
        completionHandler()
    }
}
