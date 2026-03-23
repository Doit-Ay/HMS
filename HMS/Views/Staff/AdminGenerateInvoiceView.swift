import SwiftUI
import FirebaseFirestore

// MARK: - Admin Generate Invoice View
struct AdminGenerateInvoiceView: View {
    var onSaved: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session = UserSession.shared

    @State private var patients: [HMSUser] = []
    @State private var selectedPatientId: String = ""
    private var selectedPatient: HMSUser? { patients.first { $0.id == selectedPatientId } }
    @State private var items: [EditableInvoiceItem] = [
        EditableInvoiceItem(name: "Consultation", amount: "500")
    ]
    @State private var isSaving = false
    @State private var isLoadingPatients = true
    @State private var errorMessage: String? = nil

    private let taxRate: Double = 0.05

    private var subTotal: Double {
        items.reduce(0) { $0 + (Double($1.amount) ?? 0) }
    }
    private var tax: Double { subTotal * taxRate }
    private var total: Double { subTotal + tax }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Patient Selection
                Section(header: Text("Patient")) {
                    if isLoadingPatients {
                        HStack {
                            ProgressView().tint(AppTheme.primary)
                            Text("Loading patients…")
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    } else {
                        Picker("Select Patient", selection: $selectedPatientId) {
                            Text("Choose a patient…").tag("")
                            ForEach(patients, id: \.id) { patient in
                                Text(patient.fullName).tag(patient.id)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }

                // MARK: Charge Items
                Section(header: Text("Charges")) {
                    ForEach($items) { $item in
                        HStack(spacing: 10) {
                            TextField("Item name", text: $item.name)
                                .font(.system(size: 15))
                            Spacer()
                            Text("₹")
                                .foregroundColor(AppTheme.textSecondary)
                            TextField("0", text: $item.amount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .font(.system(size: 15))
                        }
                    }
                    .onDelete { indexSet in
                        items.remove(atOffsets: indexSet)
                    }

                    Button {
                        items.append(EditableInvoiceItem(name: "", amount: ""))
                    } label: {
                        Label("Add Item", systemImage: "plus.circle.fill")
                            .foregroundColor(AppTheme.primary)
                    }
                }

                // MARK: Summary
                Section(header: Text("Summary")) {
                    HStack {
                        Text("Subtotal")
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        Text(String(format: "₹%.2f", subTotal))
                    }
                    HStack {
                        Text("Tax (5%)")
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        Text(String(format: "₹%.2f", tax))
                    }
                    HStack {
                        Text("Total")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Spacer()
                        Text(String(format: "₹%.2f", total))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.primary)
                    }
                }

                // MARK: Error
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.system(size: 13))
                    }
                }

                // MARK: Save Button
                Section {
                    Button(action: saveInvoice) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "doc.badge.plus")
                                Text("Generate & Save Invoice")
                                    .fontWeight(.bold)
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
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.primary)
                }
            }
            .task { await loadPatients() }
        }
    }

    private var canSave: Bool {
        !selectedPatientId.isEmpty &&
        !items.isEmpty &&
        items.allSatisfy { !$0.name.isEmpty && (Double($0.amount) ?? 0) > 0 }
    }

    // MARK: - Load Patients (reuses existing AuthManager method)
    private func loadPatients() async {
        do {
            let list = try await AuthManager.shared.fetchPatients()
            await MainActor.run {
                self.patients = list
                self.isLoadingPatients = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Could not load patients."
                self.isLoadingPatients = false
            }
        }
    }

    // MARK: - Save Invoice to Firestore (inline, no ViewModel)
    private func saveInvoice() {
        guard let patient = selectedPatient,
              let adminId = session.currentUser?.id,
              !selectedPatientId.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        let invoiceId = UUID().uuidString
        let invoiceItems: [[String: Any]] = items.map { item in
            ["id": UUID().uuidString, "name": item.name, "amount": Double(item.amount) ?? 0]
        }
        let subTotalVal = items.reduce(0.0) { $0 + (Double($1.amount) ?? 0) }
        let taxVal      = subTotalVal * taxRate
        let totalVal    = subTotalVal + taxVal

        let data: [String: Any] = [
            "patientId":   patient.id,
            "patientName": patient.fullName,
            "items":       invoiceItems,
            "subTotal":    subTotalVal,
            "tax":         taxVal,
            "totalAmount": totalVal,
            "status":      "pending",
            "date":        Timestamp(date: Date()),
            "generatedBy": adminId
        ]

        Task {
            do {
                let db = Firestore.firestore()
                try await db.collection("invoices").document(invoiceId).setData(data)
                await MainActor.run {
                    isSaving = false
                    onSaved?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Editable Invoice Item (for Form binding)
struct EditableInvoiceItem: Identifiable {
    let id = UUID()
    var name: String
    var amount: String
}
