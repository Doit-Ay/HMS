import Foundation
import FirebaseFirestore

// MARK: - User Role
enum UserRole: String, Codable, CaseIterable {
    case patient       = "patient"
    case admin         = "admin"
    case doctor        = "doctor"
    case labTechnician = "lab_technician"

    var displayName: String {
        switch self {
        case .patient:       return "Patient"
        case .admin:         return "Admin"
        case .doctor:        return "Doctor"
        case .labTechnician: return "Lab Technician"
        }
    }

    
    var sfSymbol: String {
        switch self {
        case .patient:       return "person.circle.fill"
        case .admin:         return "shield.checkered"
        case .doctor:        return "stethoscope.circle.fill"
        case .labTechnician: return "flask.fill"
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
    var specialization: String?    // doctors only
    var consultationFee: Double?   // doctors only
    var employeeID: String?        // staff only
    var bloodGroup: String?        // patients only
    var defaultSlots: [String]?    // doctors only — e.g. ["morning","afternoon","17:00-22:00"]
    var averageRating: Double?     // doctors only
    var reviewCount: Int?          // doctors only
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
    var height: String?
    var weight: String?
    var address: String?
    var emergencyContactName: String?
    var emergencyContactPhone: String?
    var allergies: [String]?
    var medicalHistory: [String]?
    var currentMedications: [String]?
    var age: Int?
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

// MARK: - Firestore `doctors` Collection
// Doctor-specific professional details stored separately.
// Document ID = same Firebase Auth UID   →   users/{uid} ←→ doctors/{uid}
struct DoctorProfile: Codable, Identifiable {
    var id: String                      // Auth UID — foreign key to users/{id}
    var email: String
    var fullName: String
    var phoneNumber: String?
    var dateOfBirth: String?
    var gender: String?
    var department: String?
    var specialization: String?
    var employeeID: String?
    var licenseNumber: String?
    var qualifications: [String]?
    var consultationFee: Double?
    var averageRating: Double?
    var reviewCount: Int?
    var createdAt: Date?
    var isActive: Bool

    /// Convenience init — copies basic fields from HMSUser
    init(from user: HMSUser) {
        self.id             = user.id
        self.email          = user.email
        self.fullName       = user.fullName
        self.phoneNumber    = user.phoneNumber
        self.dateOfBirth    = user.dateOfBirth
        self.gender         = user.gender
        self.department     = user.department
        self.specialization = user.specialization
        self.employeeID     = user.employeeID
        self.consultationFee = user.consultationFee
        self.averageRating  = user.averageRating
        self.reviewCount    = user.reviewCount
        self.isActive       = true
        self.createdAt      = Date()
    }
}

// MARK: - Firestore `lab_technicians` Collection
// Lab Technician-specific professional details stored separately.
// Document ID = same Firebase Auth UID   →   users/{uid} ←→ lab_technicians/{uid}
struct LabTechnicianProfile: Codable, Identifiable {
    var id: String                      // Auth UID — foreign key to users/{id}
    var email: String
    var fullName: String
    var phoneNumber: String?
    var dateOfBirth: String?
    var gender: String?
    var department: String?
    var employeeID: String?
    var certifications: [String]?
    var labSection: String?
    var createdAt: Date?
    var isActive: Bool

    /// Convenience init — copies basic fields from HMSUser
    init(from user: HMSUser) {
        self.id          = user.id
        self.email       = user.email
        self.fullName    = user.fullName
        self.phoneNumber = user.phoneNumber
        self.department  = user.department
        self.employeeID  = user.employeeID
        self.isActive    = true
        self.createdAt   = Date()
    }
}

// MARK: - Slot Status
enum SlotStatus: String, Codable, CaseIterable {
    case available   = "available"
    case unavailable = "unavailable"
    case booked      = "booked"

    var displayName: String {
        switch self {
        case .available:   return "Available"
        case .unavailable: return "Unavailable"
        case .booked:      return "Booked"
        }
    }
}

// MARK: - Firestore `doctor_slots` Collection
// Each document represents one time slot for a doctor on a specific date.
// Document ID = auto-generated
struct DoctorSlot: Codable, Identifiable {
    var id: String
    var doctorId: String                  // FK → users/{uid}
    var doctorName: String
    var department: String?
    var date: String                       // "yyyy-MM-dd"
    var startTime: String                  // "HH:mm"
    var endTime: String                    // "HH:mm"
    var status: SlotStatus
    var createdAt: Date?
    var updatedAt: Date?
}

// MARK: - Firestore `appointments` Collection
// Each document represents a booked appointment.
// Document ID = auto-generated
struct Appointment: Codable, Identifiable {
    var id: String
    var slotId: String                     // FK → doctor_slots/{id}
    var doctorId: String                   // FK → users/{uid}
    var doctorName: String
    var patientId: String                  // FK → users/{uid}
    var patientName: String
    var department: String?
    var date: String                        // "yyyy-MM-dd"
    var startTime: String
    var endTime: String
    var status: String                      // "scheduled", "completed", "cancelled"
    var cancelReason: String? = nil
    var patientNotified: Bool? = nil
    var ratingGiven: Int? = nil
    var reviewText: String? = nil
    var createdAt: Date? = nil
}

// MARK: - Firestore `doctor_unavailability` Collection
// Each document represents a day-level unavailability entry for a doctor.
// Document ID = auto-generated UUID
struct DoctorUnavailability: Codable, Identifiable {
    var id: String                      // auto-generated UUID
    var doctorId: String                // FK → users/{uid}
    var date: String                    // "yyyy-MM-dd"
    var type: String                    // "unavailable" | "halfDay"
    var startTime: String?             // only for halfDay, "HH:mm"
    var endTime: String?               // only for halfDay, "HH:mm"
    var createdAt: Date?
}

// MARK: - Firestore `medicines` Collection (legacy, kept for backwards compat)
struct AppMedicine: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var type: String?           // e.g. "tablet", "syrup"
    var manufacturer: String?
}

// MARK: - Firestore `consultation_notes` Collection
struct ConsultationNote: Codable, Identifiable {
    var id: String
    var appointmentId: String
    var doctorId: String
    var doctorName: String
    var patientId: String
    var patientName: String
    var date: String                    // "yyyy-MM-dd"
    var startTime: String               // "HH:mm"
    var endTime: String                 // "HH:mm"
    var notes: String
    var prescription: String
    var createdAt: Date?
    // Prescribed medicines stored in sub-collection: consultation_notes/{id}/prescribed_medicines
}

// MARK: - Firestore `lab_test_requests` Collection
// Each document represents a lab test referred by a doctor for a patient.
struct LabTestRequest: Codable, Identifiable {
    var id: String
    var doctorId: String
    var doctorName: String
    var patientId: String
    var patientName: String
    var testNames: [String]
    var status: String                  // "pending", "completed", etc.
    var dateReferred: Date
}

// MARK: - Firestore `prescriptions` Collection
// Each document represents a generated PDF prescription uploaded to Firebase Storage.
struct PrescriptionDocument: Codable, Identifiable {
    var id: String                      // UUID
    var appointmentId: String
    var doctorId: String
    var doctorName: String
    var patientId: String
    var patientName: String
    var date: String                    // "yyyy-MM-dd"
    var startTime: String               // Slot time
    var pdfUrl: String                  // Download URL from Firebase Storage
    var createdAt: Date
    var customName: String?             // User-assigned name
}

// MARK: - Firestore `documents` Collection
// Shared document reference representing a patient's uploaded file (Medical History, Lab Results, etc.).
struct SharedMedicalDocument: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var fileName: String
    var fileURL: String
    var fileSize: Int64?       // Optional — not always stored by the upload flow
    var fileType: String
    var folderType: String
    var patientId: String
    var uploadedBy: String
    var uploadedByName: String
    var uploadDate: Date
    var notes: String?
}
