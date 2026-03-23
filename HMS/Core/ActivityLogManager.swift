import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class ActivityLogManager {
    static let shared = ActivityLogManager()
    private var db: Firestore { Firestore.firestore() }
    
    private init() {}
    
    /// Logs a system activity to Firestore.
    /// - Parameters:
    ///   - action: A high-level description of what happened (e.g. "User Login")
    ///   - details: Optional extra context (e.g. "Patient successfully logged in.")
    ///   - userOverride: Optional user to use instead of the current session user (useful for logout).
    func logAction(action: String, details: String? = nil, userOverride: HMSUser? = nil) async {
        guard let user = userOverride ?? UserSession.shared.currentUser else { return }
        
        let log = SystemActivityLog(
            userId: user.id,
            userName: user.fullName,
            userRole: user.role,
            action: action,
            details: details
        )
        
        do {
            let data = try Firestore.Encoder().encode(log)
            try await db.collection("activity_logs").document(log.id).setData(data)
        } catch {
            print("Failed to save activity log: \(error.localizedDescription)")
        }
    }
    
    /// Fetches the recent system activity logs, sorted by timestamp descending.
    func fetchLogs(limit: Int = 100) async throws -> [SystemActivityLog] {
        let snapshot = try await db.collection("activity_logs")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? Firestore.Decoder().decode(SystemActivityLog.self, from: doc.data())
        }
    }
}
