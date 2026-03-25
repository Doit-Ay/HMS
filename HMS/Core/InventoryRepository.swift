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
