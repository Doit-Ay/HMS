//
//  AdminInvoiceListView.swift
//  HMS
//
//  Created by Nishtha on 25/03/26.
//
import SwiftUI
import FirebaseFirestore

// MARK: - Admin Invoice List View
struct AdminInvoiceListView: View {
    @State private var invoices: [HMSInvoice] = []
    @State private var isLoading = true
    @State private var selectedStatus: InvoiceStatus? = nil
    @State private var showGenerateSheet = false
    @State private var selectedInvoice: HMSInvoice? = nil

    private var filtered: [HMSInvoice] {
        guard let status = selectedStatus else { return invoices }
        return invoices.filter { $0.status == status }
    }

    private var pendingCount: Int { invoices.filter { $0.status == .pending }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading Invoices…").tint(AppTheme.primary)
                } else if invoices.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        // Status filter pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                statusPill(nil, label: "All (\(invoices.count))")
                                statusPill(.pending, label: "Pending (\(invoices.filter { $0.status == .pending }.count))", color: .orange)
                                statusPill(.paid, label: "Paid (\(invoices.filter { $0.status == .paid }.count))", color: .green)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }

                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(filtered) { invoice in
                                    AdminInvoiceCard(invoice: invoice)
                                        .onTapGesture { selectedInvoice = invoice }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationTitle("Billing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showGenerateSheet = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.primary)
                    }
                }
            }
            .sheet(isPresented: $showGenerateSheet) {
                AdminGenerateInvoiceView {
                    Task { await loadInvoices() }
                }
            }
            .sheet(item: $selectedInvoice) { invoice in
                AdminInvoiceDetailSheet(invoice: invoice)
            }
            .task { await loadInvoices() }
        }
    }

    // MARK: - Sub-views
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.primary.opacity(0.3))
            Text("No Invoices Yet")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            Text("Tap + to generate a new invoice")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
        }
    }

    @ViewBuilder
    private func statusPill(_ status: InvoiceStatus?, label: String, color: Color = AppTheme.primary) -> some View {
        let isSelected = selectedStatus == status
        Button { selectedStatus = status } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(isSelected ? color : color.opacity(0.1))
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data
    private func loadInvoices() async {
        isLoading = true
        do {
            let fetched = try await InventoryRepository.shared.fetchAllInvoices()
            await MainActor.run {
                invoices = fetched
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Admin Invoice Card
struct AdminInvoiceCard: View {
    let invoice: HMSInvoice
    private var isPaid: Bool { invoice.status == .paid }
    private var statusColor: Color { isPaid ? .green : .orange }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: isPaid ? "checkmark.circle.fill" : "clock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.patientName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Text(invoice.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("₹\(String(format: "%.0f", invoice.totalAmount))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Text(invoice.status.displayName)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(statusColor.opacity(0.12))
                    .cornerRadius(6)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary.opacity(0.4))
        }
        .padding(14)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Admin Invoice Detail Sheet
struct AdminInvoiceDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let invoice: HMSInvoice

    private var isPaid: Bool { invoice.status == .paid }
    private var statusColor: Color { isPaid ? .green : .orange }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(statusColor.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: isPaid ? "checkmark.circle.fill" : "clock.fill")
                                .font(.system(size: 32))
                                .foregroundColor(statusColor)
                        }
                        Text(invoice.status.displayName.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(statusColor)
                            .padding(.horizontal, 12).padding(.vertical, 4)
                            .background(statusColor.opacity(0.12))
                            .cornerRadius(10)
                        Text("₹\(String(format: "%.2f", invoice.totalAmount))")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding(.top, 8)

                    // Patient info
                    infoCard {
                        infoRow("Patient", value: invoice.patientName)
                        infoRow("Invoice Date", value: invoice.date.formatted(date: .long, time: .omitted))
                        if let paidAt = invoice.paidAt {
                            infoRow("Paid On", value: paidAt.formatted(date: .long, time: .shortened))
                        }
                        if let paymentId = invoice.razorpayPaymentId {
                            infoRow("Payment ID", value: paymentId)
                        }
                    }

                    // Line items
                    infoCard {
                        ForEach(invoice.items) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("₹\(String(format: "%.0f", item.unitPrice)) × \(item.quantity)")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                Spacer()
                                Text("₹\(String(format: "%.2f", item.amount))")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            if item.id != invoice.items.last?.id {
                                Divider()
                            }
                        }
                    }

                    // Totals
                    infoCard {
                        HStack {
                            Text("Subtotal").foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Text("₹\(String(format: "%.2f", invoice.subTotal))")
                        }
                        .font(.system(size: 14))
                        Divider()
                        HStack {
                            Text("Tax (5%)").foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Text("₹\(String(format: "%.2f", invoice.tax))")
                        }
                        .font(.system(size: 14))
                        Divider()
                        HStack {
                            Text("Total").fontWeight(.bold)
                            Spacer()
                            Text("₹\(String(format: "%.2f", invoice.totalAmount))")
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.primary)
                        }
                        .font(.system(size: 16))
                    }
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Invoice Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
    }

    @ViewBuilder
    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(16)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}
