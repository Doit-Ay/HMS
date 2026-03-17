import SwiftUI
import PDFKit

struct PDFViewerSheet: View {
    @Environment(\.dismiss) var dismiss
    let pdfURL: URL
    
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
                        ShareLink(item: pdfURL) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(AppTheme.primary)
                        }
                    }
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
