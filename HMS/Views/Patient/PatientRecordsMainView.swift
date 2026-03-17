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
            print("📱 PatientRecordsMainView appeared")

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

            RecordsFolderCard(folder: .prescriptions, icon: "pills.fill", title: "Doctor Prescriptions", subtitle: "Prescriptions from your doctors", color: AppTheme.primaryMid)

            RecordsFolderCard(folder: .labResults, icon: "waveform.path.ecg", title: "Lab Test Results", subtitle: "Blood tests and diagnostic reports", color: AppTheme.primaryDark)
        }
        .padding(.horizontal, 24)
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
            .background(Color.white)
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
    @State private var isEditMode = false
    @State private var selectedDocuments = Set<String>()
    
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

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

            VStack {
                if isEditMode && !documents.isEmpty {
                    // Selection header
                    selectionHeader
                }
                
                content
            }

            // Delete Progress Overlay
            if isDeleting {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(AppTheme.primary)
                    
                    Text("Deleting selected files...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(30)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(radius: 15)
            }

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
                .background(Color.white)
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
        .confirmationDialog(
            "Delete \(selectedDocuments.count) file\(selectedDocuments.count == 1 ? "" : "s")?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await deleteSelectedDocuments() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
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
    }
    
    // MARK: Selection Header
    private var selectionHeader: some View {
        HStack {
            Button(action: {
                if selectedDocuments.count == documents.count {
                    selectedDocuments.removeAll()
                } else {
                    selectedDocuments = Set(documents.map { $0.id })
                }
            }) {
                Text(selectedDocuments.count == documents.count ? "Deselect All" : "Select All")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.primary)
            }
            
            Spacer()
            
            Text("\(selectedDocuments.count) selected")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
            
            Spacer()
            
            if !selectedDocuments.isEmpty {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: Toolbar Content
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {

        // LEFT SIDE (Edit / Cancel)
        ToolbarItem(placement: .navigationBarLeading) {
            if !documents.isEmpty {
                Button {
                    withAnimation(.easeInOut) {
                        isEditMode.toggle()
                        if !isEditMode {
                            selectedDocuments.removeAll()
                        }
                    }
                } label: {
                    Text(isEditMode ? "Cancel" : "Select")
                        .font(.system(size: 16, weight: .regular))
                }
            }
        }

        // RIGHT SIDE (+ button)
        ToolbarItem(placement: .navigationBarTrailing) {
            if !isEditMode {
                Button {
                    showUploadSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                }
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
                            DocumentRow(
                                document: document,
                                isEditMode: $isEditMode,
                                isSelected: selectedDocuments.contains(document.id),
                                onSelect: {
                                    if selectedDocuments.contains(document.id) {
                                        selectedDocuments.remove(document.id)
                                    } else {
                                        selectedDocuments.insert(document.id)
                                    }
                                }
                            )
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
            print("❌ No user ID")
            await MainActor.run { isLoading = false }
            return
        }

        print("📥 Loading docs for:", userId)

        let db = Firestore.firestore()

        do {
            let snapshot = try await db.collection("documents")
                .whereField("patientId", isEqualTo: userId)
                .whereField("folderType", isEqualTo: folder.rawValue)
                .getDocuments()

            print("✅ Documents fetched:", snapshot.documents.count)

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
            print("❌ Firestore error:", error)
            await MainActor.run { isLoading = false }
        }
    }

    private func handlePickedDocument(_ url: URL) {

        print("📂 Picked:", url)

        guard let user = session.currentUser else {
            print("❌ No user")
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

        print("⬆️ Upload started")

        let storage = Storage.storage()
        let db = Firestore.firestore()

        let fileName = "\(UUID().uuidString)_\(fileURL.lastPathComponent)"

        let storageRef = storage.reference()
            .child("patients/\(patientId)/\(folder.storagePath)/\(fileName)")

        do {

            print("📤 Upload path:", storageRef.fullPath)

            let uploadTask = storageRef.putFile(from: fileURL)

            await MainActor.run {
                isUploading = true
                uploadProgress = 0
            }

            // Observe progress
            uploadTask.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    let percent = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)

                    DispatchQueue.main.async {
                        uploadProgress = percent
                    }
                }
            }

            // Await completion
            try await withCheckedThrowingContinuation { continuation in

                uploadTask.observe(.success) { _ in
                    continuation.resume()
                }

                uploadTask.observe(.failure) { snapshot in
                    if let error = snapshot.error {
                        continuation.resume(throwing: error)
                    }
                }
            }

            print("✅ Upload success")

            let downloadURL = try await storageRef.downloadURL()

            print("🌐 Download URL:", downloadURL.absoluteString)

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

            print("✅ Firestore saved")

            await MainActor.run {
                isUploading = false
            }

            await loadDocuments()

        } catch {
            print("❌ Upload failed:", error)

            await MainActor.run {
                isUploading = false
            }
        }
    }
    
    // MARK: Delete Function
    private func deleteSelectedDocuments() async {
        guard !selectedDocuments.isEmpty else { return }
        
        await MainActor.run {
            isDeleting = true
        }
        
        let db = Firestore.firestore()
        let storage = Storage.storage()
        
        for documentId in selectedDocuments {
            if let document = documents.first(where: { $0.id == documentId }) {
                do {
                    // Delete from Storage
                    if !document.fileName.isEmpty {
                        let storageRef = storage.reference()
                            .child("patients/\(document.patientId)/\(folder.storagePath)/\(document.fileName)")
                        
                        try await storageRef.delete()
                        print("✅ Deleted from Storage: \(document.fileName)")
                    }
                    
                    // Delete from Firestore
                    try await db.collection("documents").document(documentId).delete()
                    print("✅ Deleted from Firestore: \(documentId)")
                    
                } catch {
                    print("❌ Error deleting document \(documentId): \(error)")
                }
            }
        }
        
        // Refresh documents
        await loadDocuments()
        
        await MainActor.run {
            isDeleting = false
            isEditMode = false
            selectedDocuments.removeAll()
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
    @Binding var isEditMode: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {

        HStack(spacing: 12) {
            if isEditMode {
                // Selection circle
                Button(action: onSelect) {
                    ZStack {
                        Circle()
                            .stroke(isSelected ? AppTheme.primary : Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Circle()
                                .fill(AppTheme.primary)
                                .frame(width: 18, height: 18)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Document content
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

                    if !isEditMode {
                        Image(systemName: "chevron.right")
                            .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(isEditMode ? 0.8 : 1)
        }
        .padding(.leading, isEditMode ? 8 : 14)
        .padding(.trailing, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isEditMode && isSelected ? AppTheme.primary.opacity(0.05) : Color.white)
        )
        .cornerRadius(16)
        .shadow(color: AppTheme.textSecondary.opacity(0.08), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isEditMode && isSelected ? AppTheme.primary.opacity(0.3) : Color.clear, lineWidth: 2)
        )
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
                print("📂 File picked:", url)
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
                print("❌ No image")
                return
            }

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".jpg")

            if let data = image.jpegData(compressionQuality: 0.8) {
                do {
                    try data.write(to: url, options: .atomic)
                    print("📸 Image saved:", url)
                    onPick(url)
                } catch {
                    print("❌ Save failed:", error)
                }
            }

            picker.dismiss(animated: true)
        }
    }
}

//////////////////////////////////////////////////////////////
// MARK: Document Viewer
//////////////////////////////////////////////////////////////

struct DocumentViewerView: View {

    let document: MedicalDocument

    var body: some View {

        Group {
            if document.fileType.lowercased() == "pdf" {

                PDFKitView(url: URL(string: document.fileURL)!)

            } else {

                ZStack {
                    Color.black.ignoresSafeArea()

                    AsyncImage(url: URL(string: document.fileURL)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        ProgressView().tint(.white)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PatientPDFKitView: UIViewRepresentable {

    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = PDFDocument(url: url)
    }
}
