import SwiftUI

// MARK: - Edit Staff View (Sheet)
struct EditStaffView: View {
    @Environment(\.dismiss) var dismiss
    let staff: HMSUser
    let onUpdate: () -> Void

    @State private var fullName: String
    @State private var phoneNumber: String
    @State private var employeeID: String
    @State private var department: String
    @State private var specialization: String
    @State private var isLoading      = false
    @State private var errorMessage   = ""
    @State private var showError      = false
    @State private var showSuccess    = false

    init(staff: HMSUser, onUpdate: @escaping () -> Void) {
        self.staff = staff
        self.onUpdate = onUpdate
        _fullName = State(initialValue: staff.fullName)
        _phoneNumber = State(initialValue: staff.phoneNumber ?? "")
        _employeeID = State(initialValue: staff.employeeID ?? "")
        _department = State(initialValue: staff.department ?? "")
        _specialization = State(initialValue: staff.specialization ?? "")
    }

    var formValid: Bool {
        !fullName.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HMSBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Premium Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.primary.opacity(0.12))
                                    .frame(width: 80, height: 80)
                                Image(systemName: staff.role.sfSymbol)
                                    .font(.system(size: 36))
                                    .foregroundColor(AppTheme.primary)
                                    .shadow(color: AppTheme.primary.opacity(0.2), radius: 4)
                            }
                            
                            VStack(spacing: 4) {
                                Text(staff.fullName)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 12))
                                    Text(staff.email)
                                        .font(.system(size: 14, design: .rounded))
                                }
                                .foregroundColor(AppTheme.textSecondary)
                                
                                Text(staff.role.displayName)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.primaryMid)
                                    .cornerRadius(20)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.top, 20)

                        // Form Card
                        VStack(spacing: 18) {
                            // Section: Identity
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Personal Details")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.primary)
                                
                                // Full Name
                                hmsLabelAndField("Full Name", icon: "person.fill", text: $fullName)
                                
                                // Phone Number
                                hmsLabelAndField("Phone Number", icon: "phone.fill", text: $phoneNumber)
                            }

                            Divider().opacity(0.15)
                            
                            // Section: Professional
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Professional Details")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.primary)
                                
                                // Employee ID
                                hmsLabelAndField("Employee ID", icon: "creditcard.fill", text: $employeeID)
                                
                                // Department
                                hmsLabelAndField("Department", icon: "building.2.fill", text: $department)

                                // Specialization (doctors only)
                                if staff.role == .doctor {
                                    hmsLabelAndField("Specialization", icon: "stethoscope", text: $specialization)
                                }
                            }

                            // Save Button
                            Button {
                                Task { await updateStaff() }
                            } label: {
                                if isLoading {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Save Changes")
                                    }
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(isLoading || !formValid)
                            .padding(.top, 10)
                        }
                        .padding(24)
                        .glassCard()
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textSecondary)
                            .font(.system(size: 22))
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("Done") {
                    onUpdate()
                    dismiss()
                }
            } message: {
                Text("Staff details updated successfully.")
            }
        }
    }

    // Custom Label + Field Combo
    private func hmsLabelAndField(_ label: String, icon: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .padding(.leading, 2)
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.primary).frame(width: 20)
                TextField(label, text: text)
                    .autocapitalization(.words)
            }
            .hmsTextFieldStyle()
        }
    }

    private func updateStaff() async {
        isLoading = true
        do {
            try await AuthManager.shared.updateStaffMember(
                uid: staff.id,
                fullName: fullName.trimmingCharacters(in: .whitespaces),
                role: staff.role,
                department: department.isEmpty ? nil : department,
                specialization: specialization.isEmpty ? nil : specialization,
                employeeID: employeeID.isEmpty ? nil : employeeID
            )
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
}
