import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit
import Combine

// MARK: - Lab Technician Repository
/// Singleton repository providing all backend operations for the Lab Technician role.
/// Handles fetching lab requests, uploading reports to Firebase Storage,
/// and updating request status in Firestore.
class LabTechnicianRepository: ObservableObject {
    static let shared = LabTechnicianRepository()
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    // Published state for real-time UI binding
    @Published var pendingRequests: [PatientLabRequest] = []
    @Published var completedRequests: [PatientLabRequest] = []
    @Published var isLoadingPending = false
    @Published var isLoadingCompleted = false
    @Published var errorMessage: String?
    
    // Firestore listeners
    private var pendingListener: ListenerRegistration?
    private var completedListener: ListenerRegistration?
    
    private init() {}
    
    deinit {
        removeListeners()
    }
    
    // MARK: - Role Guard
    
    /// Ensures the current user is a lab technician before performing mutations.
    private func ensureLabTechnician() throws {
        guard UserSession.shared.currentUser?.role == .labTechnician else {
            throw LabTechError.unauthorized("Only Lab Technicians can perform this action.")
        }
    }
    
    // MARK: - Real-time Listeners
    
    /// Starts real-time Firestore listeners for both pending and completed requests.
    /// Call this once when the Lab Technician dashboard appears.
    /// Safe to call multiple times — existing listeners are removed before re-attaching.
    func startListening() {
        // Remove existing listeners to prevent duplicates
        removeListeners()
        listenToPendingRequests()
        listenToCompletedRequests()
    }
    
    /// Removes all active Firestore listeners.
    func removeListeners() {
        pendingListener?.remove()
        completedListener?.remove()
        pendingListener = nil
        completedListener = nil
    }
    
    /// Real-time listener for pending lab requests (includes both "pending" and "in_progress").
    private func listenToPendingRequests() {
        DispatchQueue.main.async { self.isLoadingPending = true }
        
        pendingListener = db.collection("patient_lab_requests")
            .whereField("status", in: ["pending", "in_progress"])
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("LabTechRepo: Error fetching pending requests: \(error)")
                    DispatchQueue.main.async {
                        self.isLoadingPending = false
                        self.errorMessage = "Failed to fetch pending requests: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("LabTechRepo: No pending documents found (nil snapshot)")
                    DispatchQueue.main.async {
                        self.isLoadingPending = false
                        self.pendingRequests = []
                    }
                    return
                }
                
                print("LabTechRepo: Fetched \(documents.count) pending documents")
                let parsed = documents.compactMap { self.parseLabRequest(from: $0) }
                    .sorted { $0.dateRequested > $1.dateRequested }
                print("LabTechRepo: Parsed \(parsed.count) pending requests")
                
                DispatchQueue.main.async {
                    self.isLoadingPending = false
                    self.pendingRequests = parsed
                }
            }
    }
    
    /// Real-time listener for completed lab requests.
    private func listenToCompletedRequests() {
        DispatchQueue.main.async { self.isLoadingCompleted = true }
        
        completedListener = db.collection("patient_lab_requests")
            .whereField("status", isEqualTo: "completed")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("LabTechRepo: Error fetching completed requests: \(error)")
                    DispatchQueue.main.async {
                        self.isLoadingCompleted = false
                        self.errorMessage = "Failed to fetch completed requests: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("LabTechRepo: No completed documents found (nil snapshot)")
                    DispatchQueue.main.async {
                        self.isLoadingCompleted = false
                        self.completedRequests = []
                    }
                    return
                }
                
                print("LabTechRepo: Fetched \(documents.count) completed documents")
                let parsed = documents.compactMap { self.parseLabRequest(from: $0) }
                    .sorted { $0.dateRequested > $1.dateRequested }
                print("LabTechRepo: Parsed \(parsed.count) completed requests")
                
                DispatchQueue.main.async {
                    self.isLoadingCompleted = false
                    self.completedRequests = parsed
                }
            }
    }
    
    // MARK: - Approve Request
    
    /// Approves a lab request by changing its status from "pending" to "in_progress".
    func approveRequest(requestId: String) async throws {
        try ensureLabTechnician()
        
        let docRef = db.collection("patient_lab_requests").document(requestId)
        try await docRef.updateData(["status": "in_progress"])
    }
    
    // MARK: - One-shot Fetchers (for manual refresh)
    
    /// Fetches all pending requests (one-shot, no listener).
    func fetchPendingRequests() async throws -> [PatientLabRequest] {
        let snapshot = try await db.collection("patient_lab_requests")
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        
        return snapshot.documents.compactMap { parseLabRequest(from: $0) }
            .sorted { $0.dateRequested > $1.dateRequested }
    }
    
    /// Fetches all completed requests (one-shot, no listener).
    func fetchCompletedRequests() async throws -> [PatientLabRequest] {
        let snapshot = try await db.collection("patient_lab_requests")
            .whereField("status", isEqualTo: "completed")
            .getDocuments()
        
        return snapshot.documents.compactMap { parseLabRequest(from: $0) }
            .sorted { $0.dateRequested > $1.dateRequested }
    }
    
    // MARK: - Report Upload (Image)
    
    /// Uploads a UIImage as a JPEG to Firebase Storage and returns the download URL.
    ///
    /// - Parameters:
    ///   - requestId: The Firestore document ID of the `patient_lab_requests` record.
    ///   - testIndex: The index of the test within the `tests` array.
    ///   - image: The UIImage to upload.
    /// - Returns: The download URL string of the uploaded image.
    func uploadReport(requestId: String, testIndex: Int, image: UIImage) async throws -> String {
        try ensureLabTechnician()
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw LabTechError.uploadFailed("Failed to convert image to JPEG data.")
        }
        
        let fileName = "\(testIndex)_\(UUID().uuidString).jpg"
        let storageRef = storage.reference().child("lab_reports/\(requestId)/\(fileName)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    // MARK: - Report Upload (Document/PDF)
    
    /// Uploads a document file (PDF, etc.) to Firebase Storage and returns the download URL.
    ///
    /// - Parameters:
    ///   - requestId: The Firestore document ID of the `patient_lab_requests` record.
    ///   - testIndex: The index of the test within the `tests` array.
    ///   - fileURL: The local URL of the file to upload.
    /// - Returns: The download URL string of the uploaded file.
    func uploadReport(requestId: String, testIndex: Int, fileURL: URL) async throws -> String {
        try ensureLabTechnician()
        
        let fileData = try Data(contentsOf: fileURL)
        let originalName = fileURL.lastPathComponent
        let fileName = "\(testIndex)_\(originalName)"
        let storageRef = storage.reference().child("lab_reports/\(requestId)/\(fileName)")
        
        let metadata = StorageMetadata()
        metadata.contentType = mimeType(for: fileURL.pathExtension)
        
        _ = try await storageRef.putDataAsync(fileData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    // MARK: - Mark All Tests Completed (Single Upload)
    
    /// Marks ALL tests in a lab request as completed with the same report URL.
    /// One upload covers the entire request — all tests share the same report file.
    ///
    /// - Parameters:
    ///   - requestId: The Firestore document ID of the `patient_lab_requests` record.
    ///   - reportURL: The Firebase Storage download URL for the uploaded report.
    ///   - fileName: The display name of the uploaded file.
    func markAllTestsCompleted(requestId: String, reportURL: String, fileName: String) async throws {
        try ensureLabTechnician()
        
        let docRef = db.collection("patient_lab_requests").document(requestId)
        let snapshot = try await docRef.getDocument()
        
        guard let data = snapshot.data(),
              var tests = data["tests"] as? [[String: Any]] else {
            throw LabTechError.notFound("Lab request not found or has no tests.")
        }
        
        let now = Timestamp(date: Date())
        
        // Mark every test with the same report
        for i in 0..<tests.count {
            tests[i]["resultURL"] = reportURL
            tests[i]["resultFileName"] = fileName
            tests[i]["completedDate"] = now
        }
        
        // Update tests + set top-level status to completed
        let updates: [String: Any] = [
            "tests": tests,
            "status": "completed"
        ]
        
        try await docRef.updateData(updates)
    }
    
    // MARK: - Upload & Complete All (Combined Convenience)
    
    /// Uploads a report image and marks ALL tests as completed in a single call.
    func uploadAndCompleteAll(requestId: String, image: UIImage) async throws {
        let reportURL = try await uploadReport(requestId: requestId, testIndex: 0, image: image)
        let fileName = "Lab_Report.jpg"
        try await markAllTestsCompleted(requestId: requestId, reportURL: reportURL, fileName: fileName)
    }
    
    /// Uploads a report document and marks ALL tests as completed in a single call.
    func uploadAndCompleteAll(requestId: String, fileURL: URL) async throws {
        let reportURL = try await uploadReport(requestId: requestId, testIndex: 0, fileURL: fileURL)
        let fileName = fileURL.lastPathComponent
        try await markAllTestsCompleted(requestId: requestId, reportURL: reportURL, fileName: fileName)
    }
    
    // MARK: - Parsing
    
    /// Parses a Firestore document into a `PatientLabRequest` model.
    private func parseLabRequest(from doc: QueryDocumentSnapshot) -> PatientLabRequest? {
        let data = doc.data()
        
        guard let patientId = data["patientId"] as? String,
              let patientName = data["patientName"] as? String,
              let testsData = data["tests"] as? [[String: Any]],
              let timestamp = data["dateRequested"] as? Timestamp else {
            return nil
        }
        
        var tests: [RequestedTest] = []
        
        for testData in testsData {
            if let name = testData["name"] as? String,
               let price = testData["price"] as? Int {
                
                let requestedByDoctor = testData["requestedByDoctor"] as? String
                let resultURL = testData["resultURL"] as? String
                let resultFileName = testData["resultFileName"] as? String
                let completedDate = (testData["completedDate"] as? Timestamp)?.dateValue()
                
                let test = RequestedTest(
                    name: name,
                    price: price,
                    requestedByDoctor: requestedByDoctor,
                    resultURL: resultURL,
                    resultFileName: resultFileName,
                    completedDate: completedDate
                )
                tests.append(test)
            }
        }
        
        return PatientLabRequest(
            id: doc.documentID,
            patientId: patientId,
            patientName: patientName,
            tests: tests,
            dateRequested: timestamp.dateValue(),
            status: data["status"] as? String ?? "pending",
            customName: data["customName"] as? String,
            collectionName: "patient_lab_requests"
        )
    }
    
    // MARK: - Helpers
    
    /// Returns a MIME type string for common file extensions.
    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "pdf":  return "application/pdf"
        case "jpg", "jpeg": return "image/jpeg"
        case "png":  return "image/png"
        case "heic": return "image/heic"
        default:     return "application/octet-stream"
        }
    }
}

// MARK: - Error Types
enum LabTechError: LocalizedError {
    case unauthorized(String)
    case uploadFailed(String)
    case notFound(String)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized(let msg): return msg
        case .uploadFailed(let msg): return msg
        case .notFound(let msg):     return msg
        }
    }
}
