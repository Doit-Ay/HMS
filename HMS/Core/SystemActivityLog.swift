import Foundation
import FirebaseFirestore

// MARK: - System Activity Log
struct SystemActivityLog: Codable, Identifiable {
    var id: String
    var userId: String
    var userName: String
    var userRole: UserRole
    var action: String
    var details: String?
    var timestamp: Date
    
    // For initializing new logs
    init(id: String = UUID().uuidString, userId: String, userName: String, userRole: UserRole, action: String, details: String? = nil, timestamp: Date = Date()) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.userRole = userRole
        self.action = action
        self.details = details
        self.timestamp = timestamp
    }
}
