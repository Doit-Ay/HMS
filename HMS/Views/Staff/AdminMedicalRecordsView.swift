import SwiftUI
import FirebaseFirestore

struct AdminMedicalRecord: Identifiable {
    let id: String
    let name: String
    let fileURL: String
    let folderType: String
    let uploadDate: Date
    let fileType: String
}

struct AdminMedicalRecordsView: View {
    let patientId: String
    let patientName: String
    
    @Environment(\.openURL) var openURL
    @State private var records: [AdminMedicalRecord] = []
    @State private var isLoading = true
    @State private var animate = false
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            if isLoading {
                ProgressView("Fetching Records...")
                    .tint(AppTheme.primary)
            } else if records.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.xmark")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.3))
                    Text("No Medical Records Found")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    Text("The patient hasn't uploaded any documents.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                            NavigationLink(destination: AdminDocumentViewerView(
                                name: record.name,
                                fileURL: record.fileURL,
                                fileType: record.fileType
                            )) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(AppTheme.primary.opacity(0.15))
                                            .frame(width: 50, height: 50)
                                        Image(systemName: "doc.text.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(AppTheme.primary)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(record.name)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundColor(AppTheme.textPrimary)
                                            .lineLimit(1)
                                        
                                        HStack {
                                            Text(record.folderType)
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(AppTheme.primaryDark)
                                            Spacer()
                                            Text(record.uploadDate.formatted(.dateTime.day().month().year()))
                                                .font(.system(size: 12, design: .rounded))
                                                .foregroundColor(AppTheme.textSecondary)
                                        }
                                    }
                                }
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .offset(y: animate ? 0 : 20)
                            .opacity(animate ? 1 : 0)
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.8)
                                .delay(Double(index) * 0.05),
                                value: animate
                            )
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Medical Records")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchRecords()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { animate = true }
            }
        }
    }
    
    private func fetchRecords() async {
        do {
            let dataList = try await DoctorPatientRepository.shared.fetchPatientDocuments(patientId: patientId)
            let mapped = dataList.compactMap { data -> AdminMedicalRecord? in
                guard let id = data["documentID"] as? String,
                      let name = data["name"] as? String,
                      let fileURL = data["fileURL"] as? String,
                      let folderType = data["folderType"] as? String else { return nil }
                
                let uploadDate = (data["uploadDate"] as? Timestamp)?.dateValue() ?? Date()
                let fileType = (data["fileType"] as? String) ?? (name.components(separatedBy: ".").last ?? "pdf")
                return AdminMedicalRecord(id: id, name: name, fileURL: fileURL, folderType: folderType, uploadDate: uploadDate, fileType: fileType)
            }
            withAnimation {
                self.records = mapped.sorted { $0.uploadDate > $1.uploadDate }
                self.isLoading = false
            }
        } catch {
            print("Failed to fetch medical records: \(error)")
            withAnimation { isLoading = false }
        }
    }
}

// MARK: - Admin Document Viewer
import PDFKit

struct AdminDocumentViewerView: View {
    let name: String
    let fileURL: String
    let fileType: String

    var body: some View {
        Group {
            if fileType.lowercased() == "pdf" {
                if let url = URL(string: fileURL) {
                    AdminPDFKitView(url: url)
                } else {
                    Text("Invalid PDF URL")
                }
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()

                    AsyncImage(url: URL(string: fileURL)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        ProgressView().tint(.white)
                    }
                }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AdminPDFKitView: UIViewRepresentable {
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
