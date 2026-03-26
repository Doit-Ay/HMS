import SwiftUI
import FirebaseFirestore
import PDFKit

// MARK: - Unified Revenue Transaction
struct RevenueTransaction: Identifiable {
    let id: String
    let type: TransactionType
    let patientName: String
    let description: String
    let amount: Double
    let date: Date

    enum TransactionType {
        case invoice, appointment, labTest

        var label: String {
            switch self {
            case .invoice:     return "Invoice"
            case .appointment: return "Appointment"
            case .labTest:     return "Lab Test"
            }
        }

        var icon: String {
            switch self {
            case .invoice:     return "doc.plaintext.fill"
            case .appointment: return "stethoscope"
            case .labTest:     return "flask.fill"
            }
        }

        var color: Color {
            switch self {
            case .invoice:     return Color(red: 0.27, green: 0.49, blue: 0.96)
            case .appointment: return Color(red: 0.18, green: 0.72, blue: 0.56)
            case .labTest:     return Color(red: 0.93, green: 0.52, blue: 0.22)
            }
        }
    }
}

// MARK: - Admin Revenue Dashboard View
struct AdminRevenueDashboardView: View {
    @State private var transactions: [RevenueTransaction] = []
    @State private var isLoading = true
    @State private var selectedFilter: RevenueTransaction.TransactionType? = nil

    // Computed revenue per type
    private var invoiceRevenue:     Double { transactions.filter { $0.type == .invoice     }.reduce(0) { $0 + $1.amount } }
    private var appointmentRevenue: Double { transactions.filter { $0.type == .appointment }.reduce(0) { $0 + $1.amount } }
    private var labTestRevenue:     Double { transactions.filter { $0.type == .labTest     }.reduce(0) { $0 + $1.amount } }
    private var totalRevenue:       Double { transactions.reduce(0) { $0 + $1.amount } }

    private var filteredTransactions: [RevenueTransaction] {
        guard let filter = selectedFilter else { return transactions }
        return transactions.filter { $0.type == filter }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView().tint(AppTheme.primary)
                        Text("Loading revenue data…")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {

                            // ── Total Revenue Hero Card ──────────────────────
                            totalRevenueCard

                            // ── Breakdown Cards ──────────────────────────────
                            HStack(spacing: 12) {
                                RevenueBreakdownCard(
                                    title: "Invoices",
                                    amount: invoiceRevenue,
                                    icon: "doc.plaintext.fill",
                                    color: RevenueTransaction.TransactionType.invoice.color,
                                    isSelected: selectedFilter == .invoice
                                ) {
                                    selectedFilter = selectedFilter == .invoice ? nil : .invoice
                                }
                                RevenueBreakdownCard(
                                    title: "Appointments",
                                    amount: appointmentRevenue,
                                    icon: "stethoscope",
                                    color: RevenueTransaction.TransactionType.appointment.color,
                                    isSelected: selectedFilter == .appointment
                                ) {
                                    selectedFilter = selectedFilter == .appointment ? nil : .appointment
                                }
                                RevenueBreakdownCard(
                                    title: "Lab Tests",
                                    amount: labTestRevenue,
                                    icon: "flask.fill",
                                    color: RevenueTransaction.TransactionType.labTest.color,
                                    isSelected: selectedFilter == .labTest
                                ) {
                                    selectedFilter = selectedFilter == .labTest ? nil : .labTest
                                }
                            }
                            .padding(.horizontal, 16)

                            // ── Transaction Feed ─────────────────────────────
                            VStack(spacing: 12) {
                                HStack {
                                    Text(selectedFilter == nil ? "All Transactions" : "\(selectedFilter!.label) Payments")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    if selectedFilter != nil {
                                        Button("Clear") { selectedFilter = nil }
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundColor(AppTheme.primary)
                                    }
                                    NavigationLink(destination: AdminGenerateInvoiceView {
                                        Task { await loadAllRevenue() }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus")
                                            Text("New Invoice")
                                        }
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(AppTheme.primary)
                                        .cornerRadius(9)
                                    }
                                }
                                .padding(.horizontal, 16)

                                if filteredTransactions.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "tray")
                                            .font(.system(size: 36))
                                            .foregroundColor(AppTheme.primary.opacity(0.4))
                                        Text("No transactions yet")
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                } else {
                                    LazyVStack(spacing: 10) {
                                        ForEach(filteredTransactions) { txn in
                                            TransactionRow(transaction: txn)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Financial Overview")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadAllRevenue() }
        }
    }

    // MARK: - Total Revenue Hero
    private var totalRevenueCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Revenue Collected")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    Text(String(format: "₹%.2f", totalRevenue))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 64, height: 64)
                    Image(systemName: "indianrupeesign.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
            }
            Text("\(transactions.count) transactions")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [AppTheme.dashboardCardGradientStart, AppTheme.dashboardCardGradientEnd],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
        .shadow(color: AppTheme.primary.opacity(0.25), radius: 14, x: 0, y: 7)
        .padding(.horizontal, 16)
    }

    // MARK: - Data Loading

    private func loadAllRevenue() async {
        let db = Firestore.firestore()
        var all: [RevenueTransaction] = []

        // ── 1. Paid Invoices ────────────────────────────────────────────────
        do {
            let snap = try await db.collection("invoices")
                .whereField("status", isEqualTo: "paid")
                .getDocuments()
            for doc in snap.documents {
                let d = doc.data()
                guard
                    let name   = d["patientName"] as? String,
                    let amount = d["totalAmount"] as? Double,
                    let dateTS = d["date"] as? Timestamp
                else { continue }

                let itemNames = (d["items"] as? [[String: Any]] ?? [])
                    .compactMap { $0["name"] as? String }
                let desc = itemNames.isEmpty ? "Medical Invoice" : itemNames.joined(separator: ", ")

                all.append(RevenueTransaction(
                    id: doc.documentID, type: .invoice,
                    patientName: name, description: desc,
                    amount: amount, date: dateTS.dateValue()
                ))
            }
        } catch { print("⚠️ Revenue (invoices): \(error)") }

        // ── 2. Completed Appointments ───────────────────────────────────────
        do {
            let snap = try await db.collection("appointments")
                .whereField("status", isEqualTo: "scheduled")
                .getDocuments()
            
            // Fetch all doctors to map their consultation fee
            let doctorsSnap = try await db.collection("doctors").getDocuments()
            var feeMap: [String: Double] = [:]
            for d in doctorsSnap.documents {
                feeMap[d.documentID] = d.data()["consultationFee"] as? Double ?? 499.0
            }

            for doc in snap.documents {
                let d = doc.data()
                guard
                    let name     = d["patientName"] as? String,
                    let doctorId = d["doctorId"]    as? String,
                    let doctor   = d["doctorName"]  as? String,
                    let dateStr  = d["date"]         as? String
                else { continue }

                let dtFormatter = DateFormatter()
                dtFormatter.dateFormat = "yyyy-MM-dd"
                let scheduledDate = dtFormatter.date(from: dateStr) ?? Date()
                
                let createdAtTS = d["createdAt"] as? Timestamp
                let paymentDate = createdAtTS?.dateValue() ?? scheduledDate

                all.append(RevenueTransaction(
                    id: doc.documentID, type: .appointment,
                    patientName: name,
                    description: "Consultation – Dr. \(doctor)",
                    amount: feeMap[doctorId] ?? 499.0,
                    date: paymentDate
                ))
            }
        } catch { print("⚠️ Revenue (appointments): \(error)") }

        // ── 3. Lab Test Payments ────────────────────────────────────────────
        do {
            let snap = try await db.collection("patient_lab_requests").getDocuments()
            for doc in snap.documents {
                let d = doc.data()
                guard
                    let name   = d["patientName"]   as? String,
                    let amount = d["totalAmount"]    as? Double,
                    let dateTS = d["dateRequested"]  as? Timestamp,
                    amount > 0
                else { continue }

                let tests = (d["tests"] as? [[String: Any]] ?? [])
                    .compactMap { $0["name"] as? String }
                let desc = tests.isEmpty ? "Lab Tests" : tests.joined(separator: ", ")

                all.append(RevenueTransaction(
                    id: doc.documentID, type: .labTest,
                    patientName: name, description: desc,
                    amount: amount, date: dateTS.dateValue()
                ))
            }
        } catch { print("⚠️ Revenue (lab tests): \(error)") }

        let sorted = all.sorted { $0.date > $1.date }
        await MainActor.run {
            self.transactions = sorted
            self.isLoading = false
        }
    }
}

// MARK: - Breakdown Card
struct RevenueBreakdownCard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(color)
                    }
                }
                Text(String(format: "₹%.0f", amount))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardSurface)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: RevenueTransaction
    @State private var pdfURL: URL? = nil
    @State private var showPDFPreview = false

    var body: some View {
        HStack(spacing: 14) {
            // Icon Badge
            ZStack {
                Circle()
                    .fill(transaction.type.color.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: transaction.type.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(transaction.type.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.patientName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Text(transaction.description)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(transaction.type.label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(transaction.type.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(transaction.type.color.opacity(0.1))
                        .cornerRadius(4)
                    Text("·")
                        .foregroundColor(AppTheme.textSecondary)
                    Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(String(format: "₹%.2f", transaction.amount))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                if pdfURL != nil {
                    Button(action: { showPDFPreview = true }) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.primary)
                    }
                } else {
                    Button(action: generateReceipt) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardSurface)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        .fullScreenCover(isPresented: $showPDFPreview) {
            if let url = pdfURL {
                LocalPDFPreviewView(url: url)
            }
        }
    }

    private func generateReceipt() {
        let generator = RevenuePDFGenerator()
        if let url = generator.generatePDF(transaction: transaction) {
            pdfURL = url
        }
    }
}

// MARK: - Local PDF Preview Wrapper
struct LocalPDFPreviewView: View {
    let url: URL
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            PDFKitRepresentedView(url: url)
                .edgesIgnoringSafeArea(.all)
                .navigationTitle("Receipt Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

struct PDFKitRepresentedView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
