import Foundation
import FirebaseFirestore
import FirebaseAuth

class DoctorPatientRepository {
    static let shared = DoctorPatientRepository()
    private let db = Firestore.firestore()
    
    private init() {}
    
    /// Fetches the profile of a specific patient from the `patients` collection.
    /// Uses MANUAL decoding because PatientProfileView saves some fields as Int
    /// (height, weight, age) while the PatientProfile struct expects String?.
    /// Also, allergies is saved as a single String, not [String].
    func fetchPatientProfile(patientId: String) async throws -> PatientProfile {
        let docRef = db.collection("patients").document(patientId)
        let snapshot = try await docRef.getDocument()
        
        guard let data = snapshot.data() else {
            throw NSError(domain: "DoctorPatientRepository", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Patient not found in patients collection"])
        }
        
        // Build PatientProfile manually to handle type mismatches
        // The patients table stores height/weight/age as Int, but also might have String variants
        let profile = buildPatientProfile(id: patientId, data: data)
        return profile
    }
    
    /// Builds a PatientProfile from raw Firestore data, handling Int/String mismatches
    private func buildPatientProfile(id: String, data: [String: Any]) -> PatientProfile {
        // Helper: read a field as String regardless of whether it's stored as Int or String
        func stringValue(_ key: String) -> String? {
            if let s = data[key] as? String, !s.isEmpty { return s }
            if let i = data[key] as? Int { return "\(i)" }
            if let d = data[key] as? Double { return "\(Int(d))" }
            return nil
        }
        
        // Helper: read a field as [String] even if stored as a single String
        func stringArrayValue(_ key: String) -> [String]? {
            if let arr = data[key] as? [String] {
                return arr.isEmpty ? nil : arr
            }
            if let s = data[key] as? String, !s.isEmpty, s != "None" {
                // Split comma-separated values
                return s.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            return nil
        }
        
        // Helper: read a Date from Firestore Timestamp
        func dateValue(_ key: String) -> Date? {
            if let ts = data[key] as? Timestamp { return ts.dateValue() }
            return nil
        }
        
        // We need a dummy HMSUser to use the init, but it's easier to build manually.
        // Create a minimal HMSUser for the init
        let dummyUser = HMSUser(
            id: id,
            email: data["email"] as? String ?? "",
            fullName: data["fullName"] as? String ?? "Unknown",
            role: .patient
        )
        var profile = PatientProfile(from: dummyUser)
        
        // Override all fields from actual Firestore data
        profile.phoneNumber = stringValue("phoneNumber")
        profile.dateOfBirth = stringValue("dateOfBirth")
        profile.gender = stringValue("gender")
        profile.bloodGroup = stringValue("bloodGroup")
        
        // Height and weight: stored as Int in DB, we convert to String with unit
        if let h = data["height"] as? Int {
            profile.height = "\(h) cm"
        } else if let h = data["height"] as? String, !h.isEmpty {
            profile.height = h
        }
        
        if let w = data["weight"] as? Int {
            profile.weight = "\(w) kg"
        } else if let w = data["weight"] as? String, !w.isEmpty {
            profile.weight = w
        }
        
        profile.address = stringValue("address")
        profile.emergencyContactName = stringValue("emergencyContactName")
        profile.emergencyContactPhone = stringValue("emergencyContactPhone")
        profile.allergies = stringArrayValue("allergies")
        profile.medicalHistory = stringArrayValue("medicalHistory")
        profile.currentMedications = stringArrayValue("currentMedications")
        profile.age = data["age"] as? Int
        profile.createdAt = dateValue("createdAt")
        profile.isActive = data["isActive"] as? Bool ?? true
        
        return profile
    }
    
    /// Fetches all appointments for a specific patient with the current doctor.
    func fetchPatientAppointments(patientId: String, doctorId: String) async throws -> [Appointment] {
        let querySnapshot = try await db.collection("appointments")
            .whereField("patientId", isEqualTo: patientId)
            .whereField("doctorId", isEqualTo: doctorId)
            .order(by: "date", descending: true)
            .getDocuments()
        
        return querySnapshot.documents.compactMap { try? $0.data(as: Appointment.self) }
    }

    // MARK: - Consultation Notes
    
    /// Saves a consultation note to Firestore
    func saveConsultationNote(_ note: ConsultationNote) async throws {
        let data = try Firestore.Encoder().encode(note)
        try await db.collection("consultation_notes").document(note.id).setData(data)
    }
    
    /// Fetches a consultation note for a specific appointment
    func fetchConsultationNote(appointmentId: String) async throws -> ConsultationNote? {
        let snapshot = try await db.collection("consultation_notes")
            .whereField("appointmentId", isEqualTo: appointmentId)
            .limit(to: 1)
            .getDocuments()
            
        guard let document = snapshot.documents.first else {
            return nil
        }
        
        return try document.data(as: ConsultationNote.self)
    }
}
