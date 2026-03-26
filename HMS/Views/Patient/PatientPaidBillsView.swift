import SwiftUI

struct PatientPaidBillsView: View {
    let paidInvoices: [HMSInvoice]
    
    @State private var invoicePDFURL: IdentifiableURL? = nil
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            if paidInvoices.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(AppTheme.primary.opacity(0.08))
                            .frame(width: 100, height: 100)
                        Image(systemName: "doc.text")
                            .font(.system(size: 44))
                            .foregroundColor(AppTheme.primary.opacity(0.5))
                    }
                    Text("No Paid Bills")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Your paid history will appear here.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        ForEach(paidInvoices) { invoice in
                            InvoiceBillCard(invoice: invoice, onPay: nil) {
                                let generator = InvoicePDFGenerator()
                                if let url = generator.generatePDF(invoice: invoice) {
                                    invoicePDFURL = IdentifiableURL(url: url)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("Paid Bills")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $invoicePDFURL) { item in
            PDFViewerSheet(pdfURL: item.url, title: "Invoice")
        }
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}
