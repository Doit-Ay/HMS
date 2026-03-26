//
//  InventoryRepository.swift
//  HMS
//
//  Created by Nishtha on 25/03/26.
//

import Foundation
import FirebaseFirestore

// MARK: - InventoryRepository
// Single source of truth for all Firestore I/O related to inventory, invoices, and prescribed medicines.
final class InventoryRepository {
    static let shared = InventoryRepository()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Inventory Items

    func fetchAllInventory() async throws -> [InventoryItem] {
        let snapshot = try await db.collection("inventory")
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: InventoryItem.self) }
    }

    func fetchInventory(category: InventoryCategory) async throws -> [InventoryItem] {
        let snapshot = try await db.collection("inventory")
            .whereField("category", isEqualTo: category.rawValue)
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: InventoryItem.self) }
    }

    /// Doctor-side: return medicines filtered to a specific department (or all medicines if nil)
    func fetchMedicines(forDepartment department: String?) async throws -> [InventoryItem] {
        var query: Query = db.collection("inventory")
            .whereField("category", isEqualTo: InventoryCategory.medicines.rawValue)
            .whereField("isActive", isEqualTo: true)
        if let dept = department, !dept.isEmpty {
            query = query.whereField("department", isEqualTo: dept)
        }
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: InventoryItem.self) }
    }

    func addInventoryItem(_ item: InventoryItem) async throws {
        let ref = db.collection("inventory").document()
        var data = try Firestore.Encoder().encode(item)
        data["createdAt"] = Timestamp(date: Date())
        data["updatedAt"] = Timestamp(date: Date())
        try await ref.setData(data)
    }

    func updateInventoryItem(_ item: InventoryItem) async throws {
        guard let id = item.id else { return }
        var data = try Firestore.Encoder().encode(item)
        data["updatedAt"] = Timestamp(date: Date())
        try await db.collection("inventory").document(id).setData(data, merge: true)
    }

    func deleteInventoryItem(id: String) async throws {
        try await db.collection("inventory").document(id).updateData(["isActive": false])
    }

    func deductStock(itemId: String, quantity: Int) async throws {
        let ref = db.collection("inventory").document(itemId)
        try await db.runTransaction { transaction, errorPointer in
            let doc: DocumentSnapshot
            do { doc = try transaction.getDocument(ref) } catch let e as NSError {
                errorPointer?.pointee = e; return nil
            }
            let current = doc.data()?["quantity"] as? Int ?? 0
            transaction.updateData(["quantity": max(0, current - quantity), "updatedAt": Timestamp(date: Date())], forDocument: ref)
            return nil
        }
    }

    // MARK: - Invoices

    func createInvoice(_ invoice: HMSInvoice) async throws -> String {
        let ref = db.collection("invoices").document()
        var data = try Firestore.Encoder().encode(invoice)
        data["date"] = Timestamp(date: Date())
        try await ref.setData(data)
        return ref.documentID
    }

    func fetchInvoices(patientId: String) async throws -> [HMSInvoice] {
        let snapshot = try await db.collection("invoices")
            .whereField("patientId", isEqualTo: patientId)
            .getDocuments()
        return snapshot.documents
            .compactMap { try? $0.data(as: HMSInvoice.self) }
            .sorted { $0.date > $1.date }
    }
    
    func fetchUnifiedPaidTransactions(patientId: String) async throws -> [HMSInvoice] {
        var all: [HMSInvoice] = []
        
        let invoices = try await fetchInvoices(patientId: patientId).filter { $0.status == .paid }
        all.append(contentsOf: invoices)
        
        do {
            let snap = try await db.collection("appointments")
                .whereField("patientId", isEqualTo: patientId)
                .getDocuments()
                
            let doctorsSnap = try await db.collection("doctors").getDocuments()
            var feeMap: [String: Double] = [:]
            for d in doctorsSnap.documents {
                feeMap[d.documentID] = d.data()["consultationFee"] as? Double ?? 499.0
            }
            
            for doc in snap.documents {
                let d = doc.data()
                let status = d["status"] as? String ?? ""
                if status != "scheduled" && status != "completed" { continue }
                
                guard
                    let doctorId = d["doctorId"] as? String,
                    let doctor = d["doctorName"] as? String,
                    let dateStr = d["date"] as? String,
                    let name = d["patientName"] as? String
                else { continue }
                
                let dtFormatter = DateFormatter()
                dtFormatter.dateFormat = "yyyy-MM-dd"
                let scheduledDate = dtFormatter.date(from: dateStr) ?? Date()
                
                let createdAtTS = d["createdAt"] as? Timestamp
                let paymentDate = createdAtTS?.dateValue() ?? scheduledDate
                
                let fee = feeMap[doctorId] ?? 499.0
                
                let item = HMSInvoiceItem(id: UUID().uuidString, name: "Consultation – \(doctor)", quantity: 1, unitPrice: fee, amount: fee)
                let pseudoInvoice = HMSInvoice(
                    id: doc.documentID,
                    patientId: patientId,
                    patientName: name,
                    items: [item],
                    subTotal: fee,
                    tax: 0,
                    totalAmount: fee,
                    status: .paid,
                    date: paymentDate,
                    generatedBy: "System",
                    paidAt: paymentDate,
                    razorpayPaymentId: "txn_\(doc.documentID.prefix(6))"
                )
                all.append(pseudoInvoice)
            }
        } catch { print("Appt fetch failed: \(error)") }
        
        do {
            let snap = try await db.collection("patient_lab_requests")
                .whereField("patientId", isEqualTo: patientId)
                .getDocuments()
                
            for doc in snap.documents {
                let d = doc.data()
                guard
                    let name = d["patientName"] as? String,
                    let amount = d["totalAmount"] as? Double,
                    let dateTS = d["dateRequested"] as? Timestamp,
                    amount > 0
                else { continue }
                
                let tests = (d["tests"] as? [[String: Any]] ?? [])
                var items: [HMSInvoiceItem] = []
                for (idx, testData) in tests.enumerated() {
                    let tName = testData["name"] as? String ?? "Lab Test"
                    let tPrice = testData["price"] as? Double ?? 0
                    if tPrice > 0 {
                        items.append(HMSInvoiceItem(id: "\(idx)", name: tName, quantity: 1, unitPrice: tPrice, amount: tPrice))
                    }
                }
                if items.isEmpty {
                    items.append(HMSInvoiceItem(id: UUID().uuidString, name: "Various Lab Tests", quantity: 1, unitPrice: amount, amount: amount))
                }
                
                let pseudoInvoice = HMSInvoice(
                    id: doc.documentID,
                    patientId: patientId,
                    patientName: name,
                    items: items,
                    subTotal: amount,
                    tax: 0,
                    totalAmount: amount,
                    status: .paid,
                    date: dateTS.dateValue(),
                    generatedBy: "System",
                    paidAt: dateTS.dateValue(),
                    razorpayPaymentId: "txn_\(doc.documentID.prefix(6))"
                )
                all.append(pseudoInvoice)
            }
        } catch { print("Lab fetch failed: \(error)") }
        
        return all.sorted { $0.date > $1.date }
    }

    func fetchAllInvoices() async throws -> [HMSInvoice] {
        let snapshot = try await db.collection("invoices")
            .getDocuments()
        return snapshot.documents
            .compactMap { try? $0.data(as: HMSInvoice.self) }
            .sorted { $0.date > $1.date }
    }

    func markInvoicePaid(id: String, razorpayPaymentId: String) async throws {
        try await db.collection("invoices").document(id).updateData([
            "status": InvoiceStatus.paid.rawValue,
            "paidAt": Timestamp(date: Date()),
            "razorpayPaymentId": razorpayPaymentId
        ])
    }

    // MARK: - Prescribed Medicines (sub-collection under consultation_notes)

    func savePrescribedMedicines(noteId: String, medicines: [PrescribedMedicine]) async throws {
        let colRef = db.collection("consultation_notes").document(noteId).collection("prescribed_medicines")
        // Delete existing entries first
        let existing = try await colRef.getDocuments()
        for doc in existing.documents {
            try await colRef.document(doc.documentID).delete()
        }
        // Write new entries
        for med in medicines {
            let data = try Firestore.Encoder().encode(med)
            try await colRef.document(med.id).setData(data)
        }
    }

    func fetchPrescribedMedicines(noteId: String) async throws -> [PrescribedMedicine] {
        let snapshot = try await db.collection("consultation_notes")
            .document(noteId)
            .collection("prescribed_medicines")
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: PrescribedMedicine.self) }
    }
}
