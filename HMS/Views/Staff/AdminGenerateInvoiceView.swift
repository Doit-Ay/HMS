import SwiftUI
import FirebaseFirestore

// MARK: - Admin Generate Invoice View (upgraded to use inventory items)
struct AdminGenerateInvoiceView: View {
    var onSaved: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session = UserSession.shared

    @State private var patients: [HMSUser] = []
    @State private var inventoryItems: [InventoryItem] = []
    @State private var selectedPatientId: String = ""
    @State private var lineItems: [InvoiceLineItem] = []
    @State private var isSaving = false
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var showItemPicker = false

    // Custom item alert states
    @State private var showCustomItemAlert = false
    @State private var customItemName = ""
    @State private var customItemQty = ""
    @State private var customItemPrice = ""

    private var selectedPatient: HMSUser? { patients.first { $0.id == selectedPatientId } }

    private let taxRate: Double = 0.05
    private var subTotal: Double { lineItems.reduce(0) { $0 + $1.amount } }
    private var tax: Double { subTotal * taxRate }
    private var total: Double { subTotal + tax }

    var body: some View {
        NavigationStack {
            Form {
                // Patient Section
                Section(header: Text("Patient")) {
                    if isLoading {
                        HStack {
                            ProgressView().tint(AppTheme.primary)
                            Text("Loading…").foregroundColor(AppTheme.textSecondary)
                        }
                    } else {
                        Picker("Select Patient", selection: $selectedPatientId) {
                            Text("Choose a patient…").tag("")
                            ForEach(patients, id: \.id) { p in
                                Text(p.fullName).tag(p.id)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }

                // Line Items
                Section(header: Text("Items")) {
                    ForEach($lineItems) { $item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.name)
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Button(role: .destructive) {
                                    lineItems.removeAll { $0.id == item.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            HStack {
                                Text("₹\(String(format: "%.0f", item.unitPrice)) × ")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.textSecondary)
                                Stepper("\(item.quantity)", value: $item.quantity, in: 1...9999)
                                    .labelsHidden()
                                    .font(.system(size: 13))
                                Spacer()
                                Text("₹\(String(format: "%.2f", item.amount))")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(AppTheme.primary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Button {
                        showItemPicker = true
                    } label: {
                        Label("Add Item", systemImage: "plus.circle.fill")
                            .foregroundColor(AppTheme.primary)
                    }
                }

                // Summary
                Section(header: Text("Summary")) {
                    HStack {
                        Text("Subtotal").foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        Text("₹\(String(format: "%.2f", subTotal))")
                    }
                    HStack {
                        Text("Tax (5%)").foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        Text("₹\(String(format: "%.2f", tax))")
                    }
                    HStack {
                        Text("Total").font(.system(size: 16, weight: .bold))
                        Spacer()
                        Text("₹\(String(format: "%.2f", total))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.primary)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red).font(.system(size: 13))
                    }
                }

                Section {
                    Button(action: saveInvoice) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "doc.badge.plus")
                                Text("Generate Invoice").fontWeight(.bold)
                            }
                            Spacer()
                        }
                        .foregroundColor(.white)
                    }
                    .listRowBackground(canSave ? AppTheme.primary : Color.gray)
                    .disabled(!canSave || isSaving)
                }
            }
            .navigationTitle("New Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(AppTheme.primary)
                }
            }
            .sheet(isPresented: $showItemPicker) {
                InvoiceAddItemSheet(bedItems: inventoryItems.filter { $0.category == .beds }) { item in
                    lineItems.append(item)
                }
            }
            .task { await loadData() }
        }
    }

    private var canSave: Bool {
        !selectedPatientId.isEmpty && !lineItems.isEmpty && total > 0
    }

    private func loadData() async {
        do {
            async let patientsFetch = AuthManager.shared.fetchPatients()
            async let inventoryFetch = InventoryRepository.shared.fetchAllInventory()
            let (p, inv) = try await (patientsFetch, inventoryFetch)
            await MainActor.run {
                patients = p
                inventoryItems = inv
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Could not load data."
                isLoading = false
            }
        }
    }

    private func saveInvoice() {
        guard let patient = selectedPatient,
              let adminId = session.currentUser?.id else { return }
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let invoiceItems: [HMSInvoiceItem] = lineItems.map {
                    HMSInvoiceItem(id: UUID().uuidString,
                                   inventoryItemId: $0.inventoryItemId,
                                   name: $0.name,
                                   quantity: $0.quantity,
                                   unitPrice: $0.unitPrice,
                                   amount: $0.amount)
                }
                let invoice = HMSInvoice(
                    patientId: patient.id,
                    patientName: patient.fullName,
                    items: invoiceItems,
                    subTotal: subTotal,
                    tax: tax,
                    totalAmount: total,
                    status: .pending,
                    date: Date(),
                    generatedBy: adminId
                )
                _ = try await InventoryRepository.shared.createInvoice(invoice)

                // Deduct stock for each inventory-linked item
                for item in lineItems {
                    if let itemId = item.inventoryItemId {
                        try? await InventoryRepository.shared.deductStock(itemId: itemId, quantity: item.quantity)
                    }
                }

                await MainActor.run {
                    isSaving = false
                    onSaved?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Invoice Add Item Sheet (Beds + Custom Item)
struct InvoiceAddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    let bedItems: [InventoryItem]
    let onAdd: (InvoiceLineItem) -> Void

    @State private var quantities: [String: Int] = [:]

    // Custom item states
    @State private var showCustomItemForm = false
    @State private var customName = ""
    @State private var customQty = "1"
    @State private var customPrice = ""

    var body: some View {
        NavigationStack {
            List {
                // Beds Section
                Section(header: Label("Beds", systemImage: "bed.double.fill")) {
                    if bedItems.isEmpty {
                        Text("No beds available in inventory")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)
                    } else {
                        ForEach(bedItems) { bed in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(bed.name)
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("₹\(String(format: "%.0f", bed.unitPrice))/\(bed.unit) · \(bed.quantity) available")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                Spacer()
                                Stepper("\(quantities[bed.firestoreId, default: 1])",
                                        value: Binding(
                                            get: { quantities[bed.firestoreId, default: 1] },
                                            set: { quantities[bed.firestoreId] = $0 }
                                        ),
                                        in: 1...max(1, bed.quantity))
                                .labelsHidden()
                                .font(.system(size: 13))

                                Button {
                                    let qty = quantities[bed.firestoreId, default: 1]
                                    onAdd(InvoiceLineItem(
                                        inventoryItemId: bed.firestoreId,
                                        name: bed.name,
                                        unitPrice: bed.unitPrice,
                                        quantity: qty
                                    ))
                                    dismiss()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(AppTheme.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Custom Item Section
                Section(header: Label("Custom Item", systemImage: "pencil.circle")) {
                    if showCustomItemForm {
                        TextField("Item Name", text: $customName)
                            .font(.system(size: 15))
                        HStack {
                            Text("Quantity")
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            TextField("1", text: $customQty)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        .font(.system(size: 15))
                        HStack {
                            Text("Unit Price (₹)")
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            TextField("0", text: $customPrice)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                        .font(.system(size: 15))

                        Button {
                            let qty = Int(customQty) ?? 1
                            let price = Double(customPrice) ?? 0
                            guard !customName.trimmingCharacters(in: .whitespaces).isEmpty, price > 0 else { return }
                            onAdd(InvoiceLineItem(
                                name: customName.trimmingCharacters(in: .whitespaces),
                                unitPrice: price,
                                quantity: max(1, qty)
                            ))
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Add Custom Item").fontWeight(.semibold)
                                Spacer()
                            }
                            .foregroundColor(.white)
                        }
                        .listRowBackground(AppTheme.primary)
                    } else {
                        Button {
                            showCustomItemForm = true
                        } label: {
                            Label("Add Custom Item", systemImage: "plus.circle")
                                .foregroundColor(AppTheme.primary)
                        }
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }
}

// MARK: - Local helper models for the form
struct InvoiceLineItem: Identifiable {
    let id = UUID()
    var inventoryItemId: String? = nil
    var name: String
    var unitPrice: Double
    var quantity: Int
    var amount: Double { unitPrice * Double(quantity) }
}
