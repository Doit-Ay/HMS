//
//  LabCartManager.swift
//  HMS
//
//  Created by admin73 on 18/03/26.
//

import Foundation
import SwiftUI
import Combine

class LabCartManager: ObservableObject {
    static let shared = LabCartManager()
    
    @Published var cartItems: [CartItem] = []
    @Published var showCart = false
    
    var totalItems: Int {
        cartItems.count
    }
    
    var totalPrice: Int {
        cartItems.reduce(0) { $0 + $1.price }
    }
    
    func addToCart(_ test: LabTest) {
        // Check if already in cart
        if !cartItems.contains(where: { $0.id == test.id }) {
            let item = CartItem(
                id: test.id ?? UUID().uuidString,
                name: test.name,
                price: test.price,
                category: test.category
            )
            cartItems.append(item)
        }
    }
    
    func addRequestedTestToCart(testName: String, price: Int, doctorName: String) {
        
        let itemId = "\(testName)_\(doctorName)".replacingOccurrences(of: " ", with: "_")
        
        if !cartItems.contains(where: { $0.id == itemId }) {
            let item = CartItem(
                id: itemId,
                name: testName,
                price: price,
                category: "Requested Test",
                requestedByDoctor: doctorName
            )
            cartItems.append(item)
        }
    }
    
    func removeFromCart(_ item: CartItem) {
        cartItems.removeAll { $0.id == item.id }
    }
    
    func clearCart() {
        cartItems.removeAll()
    }
}

struct CartItem: Identifiable {
    let id: String
    let name: String
    let price: Int
    let category: String
    var requestedByDoctor: String? = nil
}
