//
//  PatientLabRequestsView.swift
//  HMS
//
//  Created by admin73 on 18/03/26.
//

import SwiftUI
import FirebaseFirestore
import PDFKit

// MARK: - Patient Lab Requests View (List of Requests)
struct PatientLabRequestsView: View {
    
    @State private var labRequests: [PatientLabRequest] = []
    @State private var isLoading = true
    @ObservedObject var session = UserSession.shared
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack {
                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(AppTheme.primary)
                    Spacer()
                } else if labRequests.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.primary.opacity(0.08))
                                .frame(width: 100, height: 100)
                            Image(systemName: "flask")
                                .font(.system(size: 44))
                                .foregroundColor(AppTheme.primary.opacity(0.5))
                        }
                        
                        Text("No Lab Test Requests")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text("Your lab test requests will appear here\nonce you or your doctor submits one.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(labRequests) { request in
                                LabReportCard(request: request)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .navigationTitle("Lab Reports")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await fetchLabRequests() }
        }
        .refreshable { await fetchLabRequests() }
    }
    
    private func fetchLabRequests() async {
        guard let patientId = session.currentUser?.id else {
            await MainActor.run { isLoading = false }
            return
        }
        
        let db = Firestore.firestore()
        var allRequests: [PatientLabRequest] = []
        
        // 0) Fetch price lookup from labTests collection
        var priceLookup: [String: Int] = [:]
        do {
            let labTestsSnapshot = try await db.collection("labTests").getDocuments()
            for doc in labTestsSnapshot.documents {
                let data = doc.data()
                if let name = data["name"] as? String {
                    if let price = data["price"] as? Int {
                        priceLookup[name] = price
                    } else if let price = data["price"] as? Double {
                        priceLookup[name] = Int(price)
                    }
                }
            }
        } catch {}
        
        // 1) Fetch from patient_lab_requests (created via cart checkout)
        do {
            let snapshot = try await db.collection("patient_lab_requests")
                .whereField("patientId", isEqualTo: patientId)
                .getDocuments()
            
            for doc in snapshot.documents {
                let data = doc.data()
                
                guard let pId = data["patientId"] as? String,
                      let pName = data["patientName"] as? String,
                      let timestamp = data["dateRequested"] as? Timestamp else {
                    print("⚠️ Missing basic fields for lab request doc: \(doc.documentID)")
                    continue
                }
                
                let testsRaw = data["tests"] as? [Any] ?? []
                let testsData = testsRaw.compactMap { $0 as? [String: Any] }
                
                var tests: [RequestedTest] = []
                for testData in testsData {
                    if let name = testData["name"] as? String {
                        // Try stored price first, then lookup, then 0
                        var price = 0
                        if let p = testData["price"] as? Int {
                            price = p
                        } else if let p = testData["price"] as? Double {
                            price = Int(p)
                        } else {
                            price = priceLookup[name] ?? 0
                        }
                        
                        tests.append(RequestedTest(
                            name: name,
                            price: price,
                            requestedByDoctor: testData["requestedByDoctor"] as? String,
                            resultURL: testData["resultURL"] as? String,
                            resultFileName: testData["resultFileName"] as? String,
                            completedDate: (testData["completedDate"] as? Timestamp)?.dateValue()
                        ))
                    }
                }
                
                allRequests.append(PatientLabRequest(
                    id: doc.documentID,
                    patientId: pId,
                    patientName: pName,
                    tests: tests,
                    dateRequested: timestamp.dateValue(),
                    status: data["status"] as? String ?? "pending",
                    customName: data["customName"] as? String,
                    collectionName: "patient_lab_requests",
                    assignedLabTechId: data["assignedLabTechId"] as? String,
                    assignedLabTechName: data["assignedLabTechName"] as? String
                ))
            }
        } catch {
            print("⚠️ fetchLabRequests (patient_lab_requests) error: \(error)")
        }
        
        // 2) Fetch from lab_test_requests (created via doctor referral)
        do {
            let snapshot = try await db.collection("lab_test_requests")
                .whereField("patientId", isEqualTo: patientId)
                .getDocuments()
            
            for doc in snapshot.documents {
                let data = doc.data()
                let testNames = data["testNames"] as? [String] ?? []
                
                guard let pId = data["patientId"] as? String,
                      let pName = data["patientName"] as? String,
                      !testNames.isEmpty,
                      let timestamp = data["dateReferred"] as? Timestamp else {
                    continue
                }
                
                let doctorName = data["doctorName"] as? String
                
                let tests = testNames.map { name in
                    RequestedTest(
                        name: name,
                        price: priceLookup[name] ?? 0,
                        requestedByDoctor: doctorName,
                        resultURL: nil,
                        resultFileName: nil,
                        completedDate: nil
                    )
                }
                
                allRequests.append(PatientLabRequest(
                    id: doc.documentID,
                    patientId: pId,
                    patientName: pName,
                    tests: tests,
                    dateRequested: timestamp.dateValue(),
                    status: data["status"] as? String ?? "pending",
                    customName: data["customName"] as? String,
                    collectionName: "lab_test_requests",
                    assignedLabTechId: data["assignedLabTechId"] as? String,
                    assignedLabTechName: data["assignedLabTechName"] as? String
                ))
            }
        } catch {
            print("⚠️ fetchLabRequests (lab_test_requests) error: \(error)")
        }
        
        // 3) Sort and update UI
        let sorted = allRequests.sorted { $0.dateRequested > $1.dateRequested }
        
        await MainActor.run {
            self.labRequests = sorted
            self.isLoading = false
        }
    }
}

// MARK: - Models
struct PatientLabRequest: Identifiable, Hashable {
    let id: String
    let patientId: String
    let patientName: String
    let tests: [RequestedTest]
    let dateRequested: Date
    let status: String
    var customName: String?
    let collectionName: String
    var assignedLabTechId: String?
    var assignedLabTechName: String?
    
    var completedTestsCount: Int {
        tests.filter { $0.isCompleted }.count
    }
    
    var totalTestsCount: Int {
        tests.count
    }
    
    var allCompleted: Bool {
        completedTestsCount == totalTestsCount
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PatientLabRequest, rhs: PatientLabRequest) -> Bool {
        lhs.id == rhs.id
    }
}

struct RequestedTest: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let price: Int
    let requestedByDoctor: String?
    let resultURL: String?
    let resultFileName: String?
    let completedDate: Date?
    
    var isCompleted: Bool {
        resultURL != nil && !resultURL!.isEmpty
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RequestedTest, rhs: RequestedTest) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Lab Report Card (inline card matching screenshot)
struct LabReportCard: View {
    
    let request: PatientLabRequest
    
    private var isCompleted: Bool { request.allCompleted }
    
    /// Picks the first non-empty result URL from any test in this request.
    private var reportURL: String? {
        request.tests.compactMap { $0.resultURL }.first(where: { !$0.isEmpty })
    }
    
    private var statusText: String {
        if isCompleted || request.status.lowercased() == "completed" {
            return "Completed"
        } else if request.status.lowercased() == "in_progress" || request.status.lowercased() == "in progress" {
            return "In Progress"
        } else {
            return "Pending"
        }
    }
    
    private var statusColor: Color {
        if isCompleted || request.status.lowercased() == "completed" {
            return .green
        } else if request.status.lowercased() == "in_progress" || request.status.lowercased() == "in progress" {
            return .blue
        } else {
            return .orange
        }
    }
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 16) {
            
            // HEADER — Date + Status Badge on the same line
            HStack {
                if let custom = request.customName {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(custom)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                        Text(request.dateRequested.formatted(date: .long, time: .omitted))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                } else {
                    Text(request.dateRequested.formatted(date: .long, time: .omitted))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                Spacer()
                
                Text(statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
            }
            
            Divider()
            
            // TESTS
            ForEach(request.tests) { test in
                
                VStack(alignment: .leading, spacing: 10) {
                    
                    HStack {
                        Text(test.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Spacer()
                        
                        Text("₹\(test.price)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    if let date = test.completedDate {
                        Text(date.formatted(date: .long, time: .omitted))
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            
            // Single View Report button for the entire request
            if isCompleted, let urlString = reportURL {
                NavigationLink(destination: CachedFileViewerView(
                    title: request.customName ?? "Lab Report",
                    urlString: urlString,
                    documentId: request.id,
                    collectionName: request.collectionName
                )) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 13))
                        Text("View Report")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.primary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(AppTheme.cardSurface)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Generic Cached File Viewer (PDF & Image)
struct CachedFileViewerView: View {
    @State var title: String
    let urlString: String
    var onRename: ((String) async -> Void)? = nil
    var documentId: String? = nil
    var collectionName: String? = nil
    var document: MedicalDocument? = nil
    
    @State private var pdfDocument: PDFDocument? = nil
    @State private var cachedImage: UIImage? = nil
    @State private var localFileURL: URL? = nil
    @State private var shareURL: URL? = nil
    @State private var isLoading = true
    @State private var loadFailed = false
    
    // Rename state
    @State private var showRenameAlert = false
    @State private var newName = ""
    @State private var showConfirmation = false
    @State private var confirmationMessage = ""
    
    private var isPDF: Bool {
        if let url = URL(string: urlString) {
            return url.pathExtension.lowercased() == "pdf"
        }
        return urlString.lowercased().contains(".pdf")
    }
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            if isLoading {
                VStack(spacing: 18) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(AppTheme.primary)
                    
                    Text(isPDF ? "Loading Document…" : "Loading Image…")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            } else if loadFailed {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Unable to load file")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Button {
                        Task { await loadFile() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(AppTheme.primary)
                        .cornerRadius(10)
                    }
                }
            } else if let pdfDocument {
                CachedPDFKitView(document: pdfDocument)
            } else if let cachedImage {
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: cachedImage)
                        .resizable()
                        .scaledToFit()
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        newName = title
                        // Remove file extension for editing if present
                        if let lastDot = newName.lastIndex(of: ".") {
                            newName = String(newName[..<lastDot])
                        }
                        showRenameAlert = true
                    }) {
                        Label("Rename", systemImage: "pencil")
                    }
                    if let url = shareURL {
                        ShareLink(item: url) {
                            Label("Download / Share", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
        .alert("Rename File", isPresented: $showRenameAlert) {
            TextField("Name", text: $newName)
                .autocapitalization(.none)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                renameDocument()
            }
        } message: {
            Text("Enter a new name for this file")
        }
        .alert(confirmationMessage, isPresented: $showConfirmation) {
            Button("OK", role: .cancel) { }
        }
        .task { await loadFile() }
        .toolbar(.hidden, for: .tabBar)
    }
    
    // MARK: - Rename Functionality
    
    private func renameDocument() {
        let trimmedName = newName.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            confirmationMessage = "Please enter a valid name"
            showConfirmation = true
            return
        }
        
        // Keep the original file extension
        let fileExtension = isPDF ? "pdf" : "jpg"
        let newNameWithExtension = trimmedName.hasSuffix(".\(fileExtension)") ?
            trimmedName : "\(trimmedName).\(fileExtension)"
        
        Task {
            var renameSuccess = false
            
            // Case 1: If we have a MedicalDocument (from PatientRecords)
            if let doc = document {
                do {
                    let db = Firestore.firestore()
                    try await db.collection("documents")
                        .document(doc.id)
                        .updateData([
                            "name": newNameWithExtension
                        ])
                    
                    renameSuccess = true
                    
                    await MainActor.run {
                        self.title = newNameWithExtension
                        confirmationMessage = "Document renamed successfully"
                        showConfirmation = true
                    }
                } catch {
                    await MainActor.run {
                        confirmationMessage = "Failed to rename: \(error.localizedDescription)"
                        showConfirmation = true
                    }
                }
            }
            // Case 2: If we have collection name and document ID (from lab requests)
            else if let collection = collectionName, let docId = documentId {
                do {
                    let db = Firestore.firestore()
                    try await db.collection(collection)
                        .document(docId)
                        .updateData([
                            "customName": newNameWithExtension
                        ])
                    
                    renameSuccess = true
                    
                    await MainActor.run {
                        self.title = newNameWithExtension
                        confirmationMessage = "Document renamed successfully"
                        showConfirmation = true
                    }
                } catch {
                    await MainActor.run {
                        confirmationMessage = "Failed to rename: \(error.localizedDescription)"
                        showConfirmation = true
                    }
                }
            }
            // Case 3: Use the provided onRename callback
            else if let onRename = onRename {
                await onRename(newNameWithExtension)
                
                await MainActor.run {
                    self.title = newNameWithExtension
                    confirmationMessage = "Document renamed successfully"
                    showConfirmation = true
                }
            }
            
            // Update share URL with new name if rename was successful
            if renameSuccess, let localURL = localFileURL {
                updateShareURL(from: localURL)
            }
        }
    }
    
    private func updateShareURL(from localURL: URL) {
        let tempDir = FileManager.default.temporaryDirectory
        let safeName = title.replacingOccurrences(of: "/", with: "-")
        let ext = isPDF ? "pdf" : "jpg"
        let finalName = safeName.lowercased().hasSuffix(".\(ext)") ? safeName : "\(safeName).\(ext)"
        let newURL = tempDir.appendingPathComponent(finalName)
        
        do {
            if FileManager.default.fileExists(atPath: newURL.path) {
                try FileManager.default.removeItem(at: newURL)
            }
            try FileManager.default.copyItem(at: localURL, to: newURL)
            self.shareURL = newURL
        } catch {
            print("❌ Failed to create shareable file:", error)
            self.shareURL = localURL
        }
    }
    
    // MARK: - Load with Cache
    
    private func loadFile() async {
        guard let remoteURL = URL(string: urlString) else {
            await MainActor.run {
                loadFailed = true
                isLoading = false
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            loadFailed = false
        }
        
        if isPDF {
            await loadPDF(remoteURL: remoteURL)
        } else {
            await loadImage(remoteURL: remoteURL)
        }
    }
    
    // MARK: PDF Loading (cache-first + background refresh)
    private func loadPDF(remoteURL: URL) async {
        let cache = PDFCacheManager.shared
        
        // 1) Try cache first (instant)
        if let cachedURL = cache.cachedFileURL(for: remoteURL),
           let doc = PDFDocument(url: cachedURL) {
            await MainActor.run {
                self.pdfDocument = doc
                self.localFileURL = cachedURL
                self.updateShareURL(from: cachedURL)
                self.isLoading = false
            }
            
            // 2) Background refresh
            let didUpdate = await cache.refreshIfNeeded(from: remoteURL)
            if didUpdate,
               let updatedURL = cache.cachedFileURL(for: remoteURL),
               let updatedDoc = PDFDocument(url: updatedURL) {
                await MainActor.run {
                    self.pdfDocument = updatedDoc
                }
            }
            return
        }
        
        // 3) No cache — download fresh
        if let localURL = await cache.download(from: remoteURL),
           let doc = PDFDocument(url: localURL) {
            await MainActor.run {
                self.pdfDocument = doc
                self.localFileURL = localURL
                self.updateShareURL(from: localURL)
                self.isLoading = false
            }
        } else {
            await MainActor.run {
                self.loadFailed = true
                self.isLoading = false
            }
        }
    }
    
    // MARK: Image Loading (cache-first + background refresh)
    private func loadImage(remoteURL: URL) async {
        let cache = PDFCacheManager.shared
        
        // 1) Try cache first (instant)
        if let cachedURL = cache.cachedImageFileURL(for: remoteURL),
           let img = UIImage(contentsOfFile: cachedURL.path) {
            await MainActor.run {
                self.cachedImage = img
                self.localFileURL = cachedURL
                self.updateShareURL(from: cachedURL)
                self.isLoading = false
            }
            
            // 2) Background refresh
            let didUpdate = await cache.refreshImageIfNeeded(from: remoteURL)
            if didUpdate,
               let updatedURL = cache.cachedImageFileURL(for: remoteURL),
               let updatedImg = UIImage(contentsOfFile: updatedURL.path) {
                await MainActor.run {
                    self.cachedImage = updatedImg
                }
            }
            return
        }
        
        // 3) No cache — download fresh
        if let localURL = await cache.downloadImage(from: remoteURL),
           let img = UIImage(contentsOfFile: localURL.path) {
            await MainActor.run {
                self.cachedImage = img
                self.localFileURL = localURL
                self.updateShareURL(from: localURL)
                self.isLoading = false
            }
        } else {
            await MainActor.run {
                self.loadFailed = true
                self.isLoading = false
            }
        }
    }
}
