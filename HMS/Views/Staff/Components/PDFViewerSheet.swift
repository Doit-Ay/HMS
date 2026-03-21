import SwiftUI
import PDFKit

struct PDFViewerSheet: View {
    @Environment(\.dismiss) var dismiss
    let pdfURL: URL
    var title: String = "Document"
    
    @State private var shareURL: URL? = nil
    
    var body: some View {
        NavigationView {
            PDFKitView(url: pdfURL)
                .edgesIgnoringSafeArea(.bottom)
                .navigationTitle("Prescription")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(AppTheme.primary)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if let sURL = shareURL {
                            ShareLink(item: sURL) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(AppTheme.primary)
                            }
                        } else {
                            ShareLink(item: pdfURL) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(AppTheme.primary.opacity(0.5))
                            }
                        }
                    }
                }
        }
        .task {
            do {
                let (tempURL, _) = try await URLSession.shared.download(from: pdfURL)
                let safeName = title.replacingOccurrences(of: "/", with: "-")
                let finalName = safeName.lowercased().hasSuffix(".pdf") ? safeName : "\(safeName).pdf"
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

struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(url: url)
    }
}
