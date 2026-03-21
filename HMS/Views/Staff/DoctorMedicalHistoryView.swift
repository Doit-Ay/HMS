import SwiftUI

struct DoctorMedicalHistoryView: View {
    @Environment(\.dismiss) var dismiss
    
    let patientId: String
    let patientName: String
    
    @State private var documents: [SharedMedicalDocument] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var selectedDocument: SharedMedicalDocument? = nil
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            contentView
        }
        .navigationTitle("\(patientName)'s Records")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchDocuments()
        }
        .sheet(item: $selectedDocument) { doc in
            sheetContent(for: doc)
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            LoadingView()
        } else if let error = errorMessage {
            ErrorView(error: error) {
                Task { await fetchDocuments() }
            }
        } else if documents.isEmpty {
            EmptyStateView(patientName: patientName)
        } else {
            DocumentsListView(
                documents: documents,
                fileIcon: fileIcon(for:),
                fileColor: fileColor(for:),
                cleanFileName: cleanFileName(_:),
                formatDate: formatDate(_:),
                onSelect: { doc in
                    selectedDocument = doc
                }
            )
        }
    }
    
    @ViewBuilder
    private func sheetContent(for doc: SharedMedicalDocument) -> some View {
        if let url = URL(string: doc.fileURL) {
            if doc.fileType.lowercased() == "pdf" {
                PDFViewerSheet(pdfURL: url, title: cleanFileName(doc.name))
            } else {
                InteractiveImageViewer(url: url, title: cleanFileName(doc.name), extensionString: doc.fileType)
            }
        } else {
            Text("Invalid Document URL")
        }
    }
    
    private func fetchDocuments() async {
        do {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            let docs = try await DoctorPatientRepository.shared.fetchPatientMedicalHistory(patientId: patientId)
            await MainActor.run {
                self.documents = docs
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func fileExtension(_ doc: SharedMedicalDocument) -> String {
        doc.fileType.lowercased()
    }

    private func fileIcon(for doc: SharedMedicalDocument) -> String {
        switch fileExtension(doc) {
        case "pdf": return "doc.fill"
        case "jpg", "jpeg", "png", "heic", "gif": return "photo.fill"
        case "doc", "docx": return "doc.text.fill"
        case "xls", "xlsx": return "tablecells.fill"
        default: return "doc.fill"
        }
    }

    private func fileColor(for doc: SharedMedicalDocument) -> Color {
        switch fileExtension(doc) {
        case "pdf": return .red
        case "jpg", "jpeg", "png", "heic", "gif": return .blue
        case "doc", "docx": return .green
        case "xls", "xlsx": return .orange
        default: return AppTheme.primary
        }
    }

    private func cleanFileName(_ name: String) -> String {
        name.components(separatedBy: "_").last ?? name
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Extracted Subviews

private struct LoadingView: View {
    var body: some View {
        ProgressView("Fetching Records...")
    }
}

private struct ErrorView: View {
    let error: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30))
                .foregroundColor(.red)
            Text(error)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Retry") {
                onRetry()
            }
            .padding(.top, 10)
        }
    }
}

private struct EmptyStateView: View {
    let patientName: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.minus")
                .font(.system(size: 40))
                .foregroundColor(Color.gray.opacity(0.5))
            Text("No medical records found")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            Text("\(patientName) has not uploaded any documents to their Medical History folder yet.")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

private struct DocumentsListView: View {
    let documents: [SharedMedicalDocument]
    let fileIcon: (SharedMedicalDocument) -> String
    let fileColor: (SharedMedicalDocument) -> Color
    let cleanFileName: (String) -> String
    let formatDate: (Date) -> String
    let onSelect: (SharedMedicalDocument) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(documents) { doc in
                    Button {
                        onSelect(doc)
                    } label: {
                        HistoryDocumentRow(
                            iconName: fileIcon(doc),
                            iconColor: fileColor(doc),
                            displayName: cleanFileName(doc.name),
                            uploadedText: formatDate(doc.uploadDate),
                            sourceType: doc.folderType,
                            notes: doc.notes
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(24)
        }
    }
}

private struct HistoryDocumentRow: View {
    let iconName: String
    let iconColor: Color
    let displayName: String
    let uploadedText: String
    let sourceType: String
    let notes: String?
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .font(.system(size: 18, weight: .semibold))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(uploadedText)
                        .font(.system(size: 12, design: .rounded))
                }
                .foregroundColor(AppTheme.textSecondary)
                
                if let notes = notes, !notes.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(notes)
                            .font(.system(size: 12, design: .rounded))
                    }
                    .foregroundColor(AppTheme.textSecondary)
                }
                
                Text(sourceType)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(iconColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(iconColor.opacity(0.1))
                    .cornerRadius(6)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.gray.opacity(0.3))
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Simple Image Viewer for non-PDF files
struct InteractiveImageViewer: View {
    @Environment(\.dismiss) var dismiss
    let url: URL
    let title: String
    let extensionString: String
    
    @State private var shareURL: URL? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().tint(.white)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        VStack {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                            Text("Failed to load image")
                                .foregroundColor(.white)
                                .padding(.top, 8)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primaryLight)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let sURL = shareURL {
                        ShareLink(item: sURL) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(AppTheme.primaryLight)
                        }
                    } else {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(AppTheme.primaryLight.opacity(0.5))
                        }
                    }
                }
            }
        }
        .task {
            do {
                let (tempURL, _) = try await URLSession.shared.download(from: url)
                let safeName = title.replacingOccurrences(of: "/", with: "-")
                let ext = extensionString.lowercased()
                let finalName = safeName.lowercased().hasSuffix(".\(ext)") ? safeName : "\(safeName).\(ext)"
                let newURL = FileManager.default.temporaryDirectory.appendingPathComponent(finalName)
                
                if FileManager.default.fileExists(atPath: newURL.path) {
                    try FileManager.default.removeItem(at: newURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: newURL)
                self.shareURL = newURL
            } catch {
                print("❌ Failed to download for share:", error)
            }
        }
    }
}
