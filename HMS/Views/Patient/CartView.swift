//
//  CartView.swift
//  HMS
//
//  Created by admin73 on 18/03/26.
//

import SwiftUI
import FirebaseFirestore

struct CartView: View {
    @ObservedObject var cartManager = LabCartManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var isCheckingOut = false
    @State private var showSuccessAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack {
                    if cartManager.cartItems.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "cart")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.textSecondary)
                            
                            Text("Your cart is empty")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text("Add lab tests from the All Tests or Requested section")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(cartManager.cartItems) { item in
                                    CartItemRow(item: item)
                                }
                            }
                            .padding(20)
                        }
                        
                        // Checkout Section
                        VStack(spacing: 16) {
                            Divider()
                            
                            HStack {
                                Text("Total:")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Spacer()
                                
                                Text("₹\(cartManager.totalPrice)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(AppTheme.primary)
                            }
                            .padding(.horizontal, 20)
                            
                            Button(action: checkout) {
                                HStack {
                                    if isCheckingOut {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Checkout (\(cartManager.totalItems) items)")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.primary)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .padding(.horizontal, 20)
                            }
                            .disabled(isCheckingOut)
                            .padding(.bottom, 20)
                        }
                        .background(AppTheme.cardSurface)
                    }
                }
            }
            .navigationTitle("Your Cart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                if !cartManager.cartItems.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All") {
                            cartManager.clearCart()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK") {
                    cartManager.clearCart()
                    dismiss()
                }
            } message: {
                Text("Your lab test request has been submitted successfully.")
            }
        }
    }
    
    private func checkout() {
        guard let patient = UserSession.shared.currentUser else { return }
        
        isCheckingOut = true
        
        let db = Firestore.firestore()
        
        let requestData: [String: Any] = [
            "patientId": patient.id,
            "patientName": patient.fullName,
            "tests": cartManager.cartItems.map { item in
                [
                    "name": item.name,
                    "price": item.price,
                    "requestedByDoctor": item.requestedByDoctor ?? ""
                ]
            },
            "totalAmount": cartManager.totalPrice,
            "dateRequested": Timestamp(date: Date()),
            "status": "pending"
        ]
        
        db.collection("patient_lab_requests").addDocument(data: requestData) { error in
            isCheckingOut = false
            
            if let error = error {
                print("Error creating lab request: \(error)")
            } else {
                showSuccessAlert = true
            }
        }
    }
}

struct CartItemRow: View {
    let item: CartItem
    @ObservedObject var cartManager = LabCartManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.primary.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "flask.fill")
                    .foregroundColor(AppTheme.primary)
                    .font(.system(size: 20))
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                
                if let doctor = item.requestedByDoctor, !doctor.isEmpty {
                    Text("Requested by Dr. \(doctor)")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.primary)
                }
                
                Text("₹\(item.price)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.primary)
            }
            
            Spacer()
            
            // Remove button
            Button {
                cartManager.removeFromCart(item)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.7))
                    .font(.system(size: 16))
            }
        }
        .padding(12)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 5)
    }
}
