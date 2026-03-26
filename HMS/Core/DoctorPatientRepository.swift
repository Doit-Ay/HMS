import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class DoctorPatientRepository {
    static let shared = DoctorPatientRepository()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
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

    /// Fetches all consultation notes for a specific patient
    func fetchPatientConsultationNotes(patientId: String) async throws -> [ConsultationNote] {
        let snapshot = try await db.collection("consultation_notes")
            .whereField("patientId", isEqualTo: patientId)
            .getDocuments()
        
        let notes = snapshot.documents.compactMap { try? $0.data(as: ConsultationNote.self) }
        return notes.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
    }

    // MARK: - Medicines

    /// Fetches all medicines from the `medicines` collection
    func fetchMedicines() async throws -> [AppMedicine] {
        let snapshot = try await db.collection("medicines").getDocuments()
        return snapshot.documents.compactMap { doc -> AppMedicine? in
            let data = doc.data()
            guard let name = data["name"] as? String else { return nil }
            return AppMedicine(
                id: doc.documentID,
                name: name,
                type: data["type"] as? String,
                manufacturer: data["manufacturer"] as? String
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    // MARK: - Lab Test Requests

    /// Saves a referred lab test request to Firestore
    func saveLabTestRequest(_ request: LabTestRequest) async throws {
        let data = try Firestore.Encoder().encode(request)
        try await db.collection("lab_test_requests").document(request.id).setData(data)
    }
    
    /// Fetches lab test requests for a patient by a specific doctor
    func fetchLabTestRequests(patientId: String, doctorId: String) async throws -> [LabTestRequest] {
        let snapshot = try await db.collection("lab_test_requests")
            .whereField("patientId", isEqualTo: patientId)
            .whereField("doctorId", isEqualTo: doctorId)
            .getDocuments()
            
        let requests = snapshot.documents.compactMap { try? $0.data(as: LabTestRequest.self) }
        return requests.sorted { $0.dateReferred > $1.dateReferred }
    }
    
    // MARK: - Prescriptions (PDF PDFs & Metadata)
    
    /// Uploads a generated local PDF file to Firebase Storage
    /// Returns the permanent download URL
    func uploadPrescriptionPDF(localURL: URL, appointmentId: String) async throws -> String {
        let storageRef = storage.reference().child("prescriptions/\(appointmentId)_\(UUID().uuidString).pdf")
        
        // Convert to data
        let pdfData = try Data(contentsOf: localURL)
        
        let metadata = StorageMetadata()
        metadata.contentType = "application/pdf"
        
        _ = try await storageRef.putDataAsync(pdfData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    /// Saves the prescription metadata document to Firestore
    func savePrescriptionDocument(_ doc: PrescriptionDocument) async throws {
        let data = try Firestore.Encoder().encode(doc)
        try await db.collection("prescriptions").document(doc.id).setData(data)
    }
    
    /// Fetches all prescriptions for a specific patient
    func fetchPatientPrescriptions(patientId: String) async throws -> [PrescriptionDocument] {
        let snapshot = try await db.collection("prescriptions")
            .whereField("patientId", isEqualTo: patientId)
            .getDocuments()
            
        let docs = snapshot.documents.compactMap { try? $0.data(as: PrescriptionDocument.self) }
        return docs.sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - Medical Documents
    
    // Note: MedicalDocument struct is currently local to PatientRecordsMainView.swift. 
    // Creating an alternative generic fetch for Admin views since it's just raw data parsing.
    
    /// Fetches the patient's medical history: uploaded documents + prescription PDFs
    func fetchPatientMedicalHistory(patientId: String) async throws -> [SharedMedicalDocument] {
        var allDocs: [SharedMedicalDocument] = []
        
        // 1) Fetch uploaded documents from `documents` collection (all folder types)
        let docSnapshot = try await db.collection("documents")
            .whereField("patientId", isEqualTo: patientId)
            .getDocuments()
        
        let uploadedDocs = docSnapshot.documents.compactMap { try? $0.data(as: SharedMedicalDocument.self) }
        allDocs.append(contentsOf: uploadedDocs)
        
        // 2) Fetch prescription PDFs from `prescriptions` collection
        let rxSnapshot = try await db.collection("prescriptions")
            .whereField("patientId", isEqualTo: patientId)
            .getDocuments()
        
        for doc in rxSnapshot.documents {
            let data = doc.data()
            if let pdfUrl = data["pdfUrl"] as? String,
               let doctorName = data["doctorName"] as? String,
               let date = data["date"] as? String {
                let startTime = data["startTime"] as? String ?? ""
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                
                allDocs.append(SharedMedicalDocument(
                    id: doc.documentID,
                    name: "Prescription - Dr. \(doctorName) (\(date))",
                    fileName: "prescription_\(doc.documentID).pdf",
                    fileURL: pdfUrl,
                    fileSize: nil,
                    fileType: "pdf",
                    folderType: "Prescription",
                    patientId: patientId,
                    uploadedBy: data["doctorId"] as? String ?? "",
                    uploadedByName: "Dr. \(doctorName)",
                    uploadDate: createdAt,
                    notes: startTime.isEmpty ? nil : "Appointment: \(date) at \(startTime)"
                ))
            }
        }
        
        return allDocs.sorted { $0.uploadDate > $1.uploadDate }
    }
    
    /// Fetches patient documents (MedicalHistory, LabResults) for a given patient
    func fetchPatientDocuments(patientId: String, folderType: String? = nil) async throws -> [[String: Any]] {
        var query: Query = db.collection("documents").whereField("patientId", isEqualTo: patientId)
        
        if let folderType = folderType {
            query = query.whereField("folderType", isEqualTo: folderType)
        }
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.map { doc in
            var data = doc.data()
            data["documentID"] = doc.documentID
            return data
        }
    }
    
    // MARK: - Completed Lab Reports
    
    /// Fetches completed lab reports from `patient_lab_requests` for a specific patient.
    /// Only returns entries with `status == "completed"` that have at least one test with a `resultURL`.
    func fetchCompletedLabReports(patientId: String) async throws -> [PatientLabRequest] {
        let snapshot = try await db.collection("patient_lab_requests")
            .whereField("patientId", isEqualTo: patientId)
            .whereField("status", isEqualTo: "completed")
            .getDocuments()
        
        let requests = snapshot.documents.compactMap { doc -> PatientLabRequest? in
            let data = doc.data()
            
            guard let pId = data["patientId"] as? String,
                  let pName = data["patientName"] as? String,
                  let testsData = data["tests"] as? [[String: Any]],
                  let timestamp = data["dateRequested"] as? Timestamp else {
                return nil
            }
            
            var tests: [RequestedTest] = []
            for testData in testsData {
                if let name = testData["name"] as? String {
                    var price = 0
                    if let p = testData["price"] as? Int {
                        price = p
                    } else if let p = testData["price"] as? Double {
                        price = Int(p)
                    }
                    
                    let resultURL = testData["resultURL"] as? String
                    let resultFileName = testData["resultFileName"] as? String
                    let completedDate = (testData["completedDate"] as? Timestamp)?.dateValue()
                    
                    tests.append(RequestedTest(
                        name: name,
                        price: price,
                        requestedByDoctor: testData["requestedByDoctor"] as? String,
                        resultURL: resultURL,
                        resultFileName: resultFileName,
                        completedDate: completedDate
                    ))
                }
            }
            
            // Only include requests that have at least one test with a resultURL
            let hasReport = tests.contains { $0.resultURL != nil && !$0.resultURL!.isEmpty }
            guard hasReport else { return nil }
            
            return PatientLabRequest(
                id: doc.documentID,
                patientId: pId,
                patientName: pName,
                tests: tests,
                dateRequested: timestamp.dateValue(),
                status: data["status"] as? String ?? "completed",
                customName: data["customName"] as? String,
                collectionName: "patient_lab_requests"
            )
        }
        
        return requests.sorted { $0.dateRequested > $1.dateRequested }
    }
}


