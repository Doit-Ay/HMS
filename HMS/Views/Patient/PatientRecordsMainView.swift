//
//  PatientRecordsMainView.swift
//  HMS
//
//  Created by admin73 on 16/03/26.
//

import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import UniformTypeIdentifiers
import PDFKit

// MARK: - Patient Records Main View
struct PatientRecordsMainView: View {

    @State private var animate = false

    var body: some View {

        ZStack {

            AppTheme.background
                .ignoresSafeArea()

            ScrollView {

                VStack(spacing: 28) {

                    header
                    folderCards

                    Spacer(minLength: 60)
                }
                .padding(.top, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            #if DEBUG
            print("📱 PatientRecordsMainView appeared")
            #endif

            withAnimation(.easeOut(duration: 0.5)) {
                animate = true
            }
        }
    }

    private var header: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text("Medical Records")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text("Upload, organize and access all your health documents in one place.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.horizontal, 24)
        .opacity(animate ? 1 : 0)
        .offset(y: animate ? 0 : 10)
    }

    private var folderCards: some View {

        VStack(spacing: 20) {

            RecordsFolderCard(folder: .medicalHistory, icon: "folder.fill", title: "Medical History", subtitle: "Past records & previous reports", color: AppTheme.primary)

            NavigationLink(destination: PatientPrescriptionsView()) {
                HStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppTheme.primaryMid.opacity(0.15))
                            .frame(width: 56, height: 56)

                        Image(systemName: "pills.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(AppTheme.primaryMid)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Doctor Prescriptions")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Prescriptions from your doctors")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(AppTheme.textSecondary.opacity(0.4))
                }
                .padding(18)
                .background(AppTheme.cardSurface)
                .cornerRadius(22)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: PatientLabRequestsView()) {
                HStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppTheme.primaryDark.opacity(0.15))
                            .frame(width: 56, height: 56)

                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(AppTheme.primaryDark)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Lab Test Results")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Blood tests and diagnostic reports")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(AppTheme.textSecondary.opacity(0.4))
                }
                .padding(18)
                .background(AppTheme.cardSurface)
                .cornerRadius(22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .toolbar(.hidden, for: .tabBar)
    }
}

//////////////////////////////////////////////////////////////
// MARK: Folder Card
//////////////////////////////////////////////////////////////

struct RecordsFolderCard: View {

    let folder: RecordFolder
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {

        NavigationLink(destination: FolderDetailView(folder: folder)) {

            HStack(spacing: 18) {

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 6) {

                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.textSecondary.opacity(0.4))
            }
            .padding(18)
            .background(AppTheme.cardSurface)
            .cornerRadius(22)
        }
        .buttonStyle(.plain)
    }
}

//////////////////////////////////////////////////////////////
// MARK: Folder Detail View
//////////////////////////////////////////////////////////////

struct FolderDetailView: View {

    let folder: RecordFolder

    @State private var documents: [MedicalDocument] = []
    @State private var isLoading = true

    @State private var showUploadSheet = false
    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    @State private var showCamera = false

    @State private var uploadProgress: Double = 0
    @State private var isUploading = false

    @ObservedObject var session = UserSession.shared

    var body: some View {

        ZStack {

            AppTheme.background
                .ignoresSafeArea()

            content

            // Upload Progress Overlay
            if isUploading {
                VStack(spacing: 12) {
                    ProgressView(value: uploadProgress)
                        .progressViewStyle(.linear)
                        .tint(AppTheme.primary)
                    
                    Text("Uploading \(Int(uploadProgress * 100))%")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding()
                .background(AppTheme.cardSurface)
                .cornerRadius(16)
                .shadow(radius: 10)
                .padding(.horizontal, 40)
                .transition(.opacity)
            }
        }
        .navigationTitle(folder.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .confirmationDialog("Upload Document", isPresented: $showUploadSheet) {
            Button("Take Photo") { showCamera = true }
            Button("Choose from Gallery") { showImagePicker = true }
            Button("Browse Files") { showDocumentPicker = true }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { handlePickedDocument($0) }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: .photoLibrary) { handlePickedDocument($0) }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { handlePickedDocument($0) }
        }
        .onAppear {
            Task { await loadDocuments() }
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    // MARK: Toolbar Content
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {

        // RIGHT SIDE (+ button)
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showUploadSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
            }
        }
    }

    // MARK: UI Content
    private var content: some View {

        VStack {

            if isLoading {
                Spacer()
                ProgressView().scaleEffect(1.4)
                Spacer()

            } else if documents.isEmpty {
                EmptyFolderView(folder: folder)

            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(documents) { document in
                            DocumentRow(document: document)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}

//////////////////////////////////////////////////////////////
// MARK: Firebase Logic
//////////////////////////////////////////////////////////////

extension FolderDetailView {

    private func loadDocuments() async {

        guard let userId = session.currentUser?.id else {
            #if DEBUG
            print("❌ No user ID")
            #endif
            await MainActor.run { isLoading = false }
            return
        }

        #if DEBUG
        print("📥 Loading docs for:", userId)
        #endif

        let db = Firestore.firestore()

        do {
            let snapshot = try await db.collection("documents")
                .whereField("patientId", isEqualTo: userId)
                .whereField("folderType", isEqualTo: folder.rawValue)
                .getDocuments()

            #if DEBUG
            print("✅ Documents fetched:", snapshot.documents.count)
            #endif

            let fetchedDocs = snapshot.documents.map {
                MedicalDocument(
                    id: $0.documentID,
                    name: $0["name"] as? String ?? "",
                    fileName: $0["fileName"] as? String ?? "",
                    fileURL: $0["fileURL"] as? String ?? "",
                    fileSize: $0["fileSize"] as? Int64 ?? 0,
                    fileType: $0["fileType"] as? String ?? "",
                    folderType: $0["folderType"] as? String ?? "",
                    patientId: $0["patientId"] as? String ?? "",
                    uploadedBy: $0["uploadedBy"] as? String ?? "",
                    uploadedByName: $0["uploadedByName"] as? String ?? "",
                    uploadDate: ($0["uploadDate"] as? Timestamp)?.dateValue() ?? Date(),
                    notes: $0["notes"] as? String
                )
            }
            
            // Sort by upload date (newest first)
            let sortedDocs = fetchedDocs.sorted { $0.uploadDate > $1.uploadDate }

            await MainActor.run {
                documents = sortedDocs
                isLoading = false
            }

        } catch {
            #if DEBUG
            print("❌ Firestore error:", error)
            #endif
            await MainActor.run { isLoading = false }
        }
    }

    private func handlePickedDocument(_ url: URL) {

        #if DEBUG
        print("📂 Picked:", url)
        #endif

        guard let user = session.currentUser else {
            #if DEBUG
            print("❌ No user")
            #endif
            return
        }

        Task {
            await uploadDocument(
                fileURL: url,
                folder: folder,
                patientId: user.id,
                patientName: user.fullName,
                uploadedBy: user.id,
                uploadedByName: user.fullName
            )
        }
    }

    private func uploadDocument(
        fileURL: URL,
        folder: RecordFolder,
        patientId: String,
        patientName: String,
        uploadedBy: String,
        uploadedByName: String
    ) async {

        #if DEBUG
        print("⬆️ Upload started")
        #endif

        let storage = Storage.storage()
        let db = Firestore.firestore()

        let fileName = "\(UUID().uuidString)_\(fileURL.lastPathComponent)"

        let storageRef = storage.reference()
            .child("patients/\(patientId)/\(folder.storagePath)/\(fileName)")

        do {

            #if DEBUG
            print("📤 Upload path:", storageRef.fullPath)
            #endif

            // Read file data into memory to avoid background upload task issues
            guard fileURL.startAccessingSecurityScopedResource() else {
                #if DEBUG
                print("❌ Cannot access file")
                #endif
                return
            }
            defer { fileURL.stopAccessingSecurityScopedResource() }
            
            let fileData = try Data(contentsOf: fileURL)

            await MainActor.run {
                isUploading = true
                uploadProgress = 0
            }

            // Determine content type
            let ext = fileURL.pathExtension.lowercased()
            let metadata = StorageMetadata()
            switch ext {
            case "pdf": metadata.contentType = "application/pdf"
            case "jpg", "jpeg": metadata.contentType = "image/jpeg"
            case "png": metadata.contentType = "image/png"
            case "heic": metadata.contentType = "image/heic"
            default: metadata.contentType = "application/octet-stream"
            }

            _ = try await storageRef.putDataAsync(fileData, metadata: metadata)

            #if DEBUG
            print("✅ Upload success")
            #endif

            let downloadURL = try await storageRef.downloadURL()

            #if DEBUG
            print("🌐 Download URL:", downloadURL.absoluteString)
            #endif

            try await db.collection("documents").addDocument(data: [
                "name": fileURL.lastPathComponent,
                "fileName": fileName,
                "fileURL": downloadURL.absoluteString,
                "fileType": fileURL.pathExtension,
                "folderType": folder.rawValue,
                "patientId": patientId,
                "uploadedBy": uploadedBy,
                "uploadedByName": uploadedByName,
                "uploadDate": Timestamp(date: Date())
            ])

            #if DEBUG
            print("✅ Firestore saved")
            #endif

            await MainActor.run {
                isUploading = false
            }

            await loadDocuments()

        } catch {
            #if DEBUG
            print("❌ Upload failed:", error)
            #endif

            await MainActor.run {
                isUploading = false
            }
        }
    }
    
}

//////////////////////////////////////////////////////////////
// MARK: Models + Views
//////////////////////////////////////////////////////////////

enum RecordFolder: String, CaseIterable {
    case medicalHistory = "Medical History"
    case prescriptions = "Doctor's Prescriptions"
    case labResults = "Lab Test Results"

    var storagePath: String {
        switch self {
        case .medicalHistory: return "medical_history"
        case .prescriptions: return "prescriptions"
        case .labResults: return "lab_results"
        }
    }
}

struct MedicalDocument: Identifiable {
    let id: String
    let name: String
    let fileName: String
    let fileURL: String
    let fileSize: Int64
    let fileType: String
    let folderType: String
    let patientId: String
    let uploadedBy: String
    let uploadedByName: String
    let uploadDate: Date
    let notes: String?
}

struct EmptyFolderView: View {
    let folder: RecordFolder
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.textSecondary.opacity(0.5))
            Text("No Documents")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            Text("Tap the + button to upload your first document")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


//////////////////////////////////////////////////////////////
// MARK: Document Row with Selection
//////////////////////////////////////////////////////////////

struct DocumentRow: View {

    let document: MedicalDocument

    var body: some View {

        NavigationLink {
            DocumentViewerView(document: document)
        } label: {
            HStack(spacing: 16) {
                // FILE TYPE ICON
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(fileColor.opacity(0.15))
                        .frame(width: 55, height: 55)

                    Image(systemName: fileIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(fileColor)
                }

                // INFO
                VStack(alignment: .leading, spacing: 6) {
                    Text(cleanFileName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    Text(document.uploadDate, style: .date)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.textSecondary.opacity(0.5))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: AppTheme.textSecondary.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    // MARK: File Type Logic
    private var fileExtension: String {
        document.fileType.lowercased()
    }

    private var fileIcon: String {
        switch fileExtension {
        case "pdf":
            return "doc.fill"
        case "jpg", "jpeg", "png", "heic", "gif":
            return "photo.fill"
        case "doc", "docx":
            return "doc.text.fill"
        case "xls", "xlsx":
            return "tablecells.fill"
        default:
            return "doc.fill"
        }
    }

    private var fileColor: Color {
        switch fileExtension {
        case "pdf":
            return .red
        case "jpg", "jpeg", "png", "heic", "gif":
            return .blue
        case "doc", "docx":
            return .green
        case "xls", "xlsx":
            return .orange
        default:
            return AppTheme.primary
        }
    }

    private var cleanFileName: String {
        document.name.components(separatedBy: "_").last ?? document.name
    }
}
//////////////////////////////////////////////////////////////
// MARK: Pickers
//////////////////////////////////////////////////////////////

struct DocumentPicker: UIViewControllerRepresentable {

    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.content])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                #if DEBUG
                print("📂 File picked:", url)
                #endif
                onPick(url)
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {

    var sourceType: UIImagePickerController.SourceType
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {

        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {

        var onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

            guard let image = info[.originalImage] as? UIImage else {
                #if DEBUG
                print("❌ No image")
                #endif
                return
            }

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".jpg")

            if let data = image.jpegData(compressionQuality: 0.8) {
                do {
                    try data.write(to: url, options: .atomic)
                    #if DEBUG
                    print("📸 Image saved:", url)
                    #endif
                    onPick(url)
                } catch {
                    #if DEBUG
                    print("❌ Save failed:", error)
                    #endif
                }
            }

            picker.dismiss(animated: true)
        }
    }
}

//////////////////////////////////////////////////////////////
// MARK: Document Viewer (with caching)
//////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////
// MARK: Document Viewer (with caching, download & rename)
//////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////
// MARK: Document Viewer (with caching, download & rename)
//////////////////////////////////////////////////////////////

struct DocumentViewerView: View {

    let document: MedicalDocument

    @State private var pdfDocument: PDFDocument? = nil
    @State private var cachedImage: UIImage? = nil
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var localFileURL: URL? = nil
    @State private var shareURL: URL? = nil
    
    // Rename state
    @State private var showRenameAlert = false
    @State private var newFileName = ""
    @State private var showConfirmation = false
    @State private var confirmationMessage = ""
    
    @ObservedObject var session = UserSession.shared

    private var isPDF: Bool {
        document.fileType.lowercased() == "pdf"
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
        .navigationTitle(cleanFileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showRenameAlert = true }) {
                        Label("Rename", systemImage: "pencil")
                    }
                    if let url = shareURL {
                        ShareLink(item: url) {
                            Label("Download / Share", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .alert("Rename Document", isPresented: $showRenameAlert) {
            TextField("New name", text: $newFileName)
                .autocapitalization(.none)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                renameDocument()
            }
        } message: {
            Text("Enter a new name for this document")
        }
        .alert(confirmationMessage, isPresented: $showConfirmation) {
            Button("OK", role: .cancel) { }
        }
        .task { await loadFile() }
    }

    private var cleanFileName: String {
        document.name.components(separatedBy: "_").last ?? document.name
    }
    
    private func updateShareURL(from localURL: URL) {
        let tempDir = FileManager.default.temporaryDirectory
        let safeName = cleanFileName.replacingOccurrences(of: "/", with: "-")
        let ext = document.fileType.lowercased()
        let finalName = safeName.lowercased().hasSuffix(".\(ext)") ? safeName : "\(safeName).\(ext)"
        let newURL = tempDir.appendingPathComponent(finalName)
        
        do {
            if FileManager.default.fileExists(atPath: newURL.path) {
                try FileManager.default.removeItem(at: newURL)
            }
            try FileManager.default.copyItem(at: localURL, to: newURL)
            self.shareURL = newURL
        } catch {
            #if DEBUG
            print("❌ Failed to create shareable file:", error)
            #endif
            self.shareURL = localURL
        }
    }
    
    // MARK: - Rename Functionality
    
    private func renameDocument() {
        guard !newFileName.trimmingCharacters(in: .whitespaces).isEmpty else {
            confirmationMessage = "Please enter a valid name"
            showConfirmation = true
            return
        }
        
        // Keep the original file extension
        let fileExtension = document.fileType
        let newNameWithExtension = newFileName.hasSuffix(".\(fileExtension)") ?
            newFileName : "\(newFileName).\(fileExtension)"
        
        Task {
            do {
                let db = Firestore.firestore()
                try await db.collection("documents")
                    .document(document.id)
                    .updateData([
                        "name": newNameWithExtension
                    ])
                
                await MainActor.run {
                    confirmationMessage = "Document renamed successfully"
                    showConfirmation = true
                    // Reset the newFileName field
                    newFileName = ""
                }
            } catch {
                await MainActor.run {
                    confirmationMessage = "Failed to rename: \(error.localizedDescription)"
                    showConfirmation = true
                }
            }
        }
    }
    
    // MARK: - Load with Cache
    
    private func loadFile() async {
        guard let remoteURL = URL(string: document.fileURL) else {
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
                    self.localFileURL = updatedURL
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
