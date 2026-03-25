//
//  InventoryModels.swift
//  HMS
//
//  Created by Nishtha on 25/03/26.
//

import Foundation
import FirebaseFirestore

// MARK: - Inventory Category
enum InventoryCategory: String, Codable, CaseIterable {
    case beds        = "beds"
    case medicines   = "medicines"
    case additionals = "additionals"

    var displayName: String {
        switch self {
        case .beds:        return "Beds"
        case .medicines:   return "Medicines"
        case .additionals: return "Additionals"
        }
    }

    var sfSymbol: String {
        switch self {
        case .beds:        return "bed.double.fill"
        case .medicines:   return "pills.fill"
        case .additionals: return "cross.case.fill"
        }
    }
}

// MARK: - Medicine Type (only applicable when category == .medicines)
enum MedicineType: String, Codable, CaseIterable {
    case tablet = "tablet"
    case liquid = "liquid"

    var displayName: String {
        switch self {
        case .tablet: return "Tablet"
        case .liquid: return "Liquid"
        }
    }

    var sfSymbol: String {
        switch self {
        case .tablet: return "pills.circle.fill"
        case .liquid: return "drop.fill"
        }
    }
}

// MARK: - Inventory Status
enum InvoiceStatus: String, Codable, CaseIterable {
    case pending   = "pending"
    case paid      = "paid"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .pending:   return "Pending"
        case .paid:      return "Paid"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - Firestore `inventory` Collection
struct InventoryItem: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var category: InventoryCategory
    var medicineType: MedicineType?     // only for .medicines
    var department: String?             // only for .medicines
    var quantity: Int
    var unitPrice: Double
    var unit: String                    // e.g. "tablet", "ml", "unit", "bag"
    var isActive: Bool
    var createdAt: Date?
    var updatedAt: Date?

    var firestoreId: String { id ?? UUID().uuidString }
}

// MARK: - Firestore `invoices` Collection
struct HMSInvoice: Codable, Identifiable {
    @DocumentID var id: String?
    var patientId: String
    var patientName: String
    var items: [HMSInvoiceItem]
    var subTotal: Double
    var tax: Double
    var totalAmount: Double
    var status: InvoiceStatus
    var date: Date
    var generatedBy: String
    var paidAt: Date?
    var razorpayPaymentId: String?

    var firestoreId: String { id ?? UUID().uuidString }
}

// MARK: - Invoice Line Item
struct HMSInvoiceItem: Codable, Identifiable {
    var id: String
    var inventoryItemId: String?
    var name: String
    var quantity: Int
    var unitPrice: Double
    var amount: Double                  // quantity * unitPrice
}

// MARK: - Prescribed Medicine (linked to inventory item)
struct PrescribedMedicine: Codable, Identifiable {
    var id: String
    var medicineId: String              // FK → inventory/{id}
    var medicineName: String
    var medicineType: MedicineType
    var timesPerDay: Int                // e.g. 1, 2, 3
    var durationDays: Int              // e.g. 5 days
    var notes: String?                 // e.g. "after meals"
}
