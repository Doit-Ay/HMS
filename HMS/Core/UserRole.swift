import Foundation

// MARK: - User Role
enum UserRole: String, Codable, CaseIterable {
    case patient       = "patient"
    case admin         = "admin"
    case doctor        = "doctor"
    case nurse         = "nurse"
    case labTechnician = "lab_technician"
    case pharmacist    = "pharmacist"

    var displayName: String {
        switch self {
        case .patient:       return "Patient"
        case .admin:         return "Admin"
        case .doctor:        return "Doctor"
        case .nurse:         return "Nurse"
        case .labTechnician: return "Lab Technician"
        case .pharmacist:    return "Pharmacist"
        }
    }

    var sfSymbol: String {
        switch self {
        case .patient:       return "person.circle.fill"
        case .admin:         return "shield.checkered"
        case .doctor:        return "stethoscope.circle.fill"
        case .nurse:         return "cross.case.fill"
        case .labTechnician: return "flask.fill"
        case .pharmacist:    return "pills.fill"
        }
    }

    var isStaff: Bool { self != .patient }
}

// MARK: - Firestore `users` Collection
// Master record for EVERY app user — role assignment lives here.
// Document ID = Firebase Auth UID
struct HMSUser: Codable, Identifiable {
    var id: String
    var email: String
    var fullName: String
    var role: UserRole
    var phoneNumber: String?
    var dateOfBirth: String?
    var gender: String?
    var profileImageURL: String?
    var department: String?
    var specialization: String?   // doctors only
    var employeeID: String?        // staff only
    var bloodGroup: String?        // patients only
    var createdAt: Date?
    var isActive: Bool

    init(id: String, email: String, fullName: String, role: UserRole) {
        self.id        = id
        self.email     = email
        self.fullName  = fullName
        self.role      = role
        self.isActive  = true
        self.createdAt = Date()
    }
}

// MARK: - Firestore `patients` Collection
// Patient-specific clinical/personal details stored separately.
// Document ID = same Firebase Auth UID   →   users/{uid} ←→ patients/{uid}
struct PatientProfile: Codable, Identifiable {
    var id: String                      // Auth UID — foreign key to users/{id}
    var email: String
    var fullName: String
    var phoneNumber: String?
    var dateOfBirth: String?
    var gender: String?
    var bloodGroup: String?
    var address: String?
    var emergencyContactName: String?
    var emergencyContactPhone: String?
    var allergies: [String]?
    var medicalHistory: [String]?
    var createdAt: Date?
    var isActive: Bool

    /// Convenience init — copies basic fields from HMSUser
    init(from user: HMSUser) {
        self.id          = user.id
        self.email       = user.email
        self.fullName    = user.fullName
        self.phoneNumber = user.phoneNumber
        self.bloodGroup  = user.bloodGroup
        self.isActive    = true
        self.createdAt   = Date()
    }
}
