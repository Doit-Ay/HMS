import SwiftUI

// MARK: - Add Staff View (Sheet)
struct AddStaffView: View {
    @Environment(\.dismiss) var dismiss
    let onSuccess: () -> Void

    @State private var fullName       = ""
    @State private var email          = ""
    @State private var employeeID     = ""
    @State private var department     = ""
    @State private var specialization = ""
    @State private var selectedRole: UserRole = .doctor
    @State private var isLoading      = false
    @State private var errorMessage   = ""
    @State private var showError      = false
    @State private var showSuccess    = false

    let staffRoles: [UserRole] = [.doctor, .nurse, .labTechnician, .pharmacist]

    var formValid: Bool {
        !fullName.isEmpty && !email.isEmpty && email.contains("@")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HMSBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // Role Picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Select Role")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                                .padding(.horizontal, 4)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(staffRoles, id: \.self) { role in
                                        RoleChip(role: role, isSelected: selectedRole == role) {
                                            selectedRole = role
                                        }
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                        .padding(.horizontal, 20)

                        // Info Banner — explain the email flow
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.badge.shield.half.filled.fill")
                                .font(.system(size: 22))
                                .foregroundColor(AppTheme.primary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Passwordless Setup")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("Staff will receive a password setup email and must set their own password before logging in.")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(14)
                        .background(AppTheme.primaryLight)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppTheme.primary.opacity(0.25), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)

                        // Form Card
                        VStack(spacing: 14) {
                            // Full Name
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill")
                                    .foregroundColor(AppTheme.primary).frame(width: 20)
                                TextField("Full Name", text: $fullName)
                                    .autocapitalization(.words)
                            }
                            .hmsTextFieldStyle()

                            // Email
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(AppTheme.primary).frame(width: 20)
                                TextField("Staff Email Address", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            .hmsTextFieldStyle()

                            // Employee ID
                            HStack(spacing: 12) {
                                Image(systemName: "creditcard.fill")
                                    .foregroundColor(AppTheme.primary).frame(width: 20)
                                TextField("Employee ID (optional)", text: $employeeID)
                                    .autocapitalization(.allCharacters)
                            }
                            .hmsTextFieldStyle()

                            // Department
                            HStack(spacing: 12) {
                                Image(systemName: "building.2.fill")
                                    .foregroundColor(AppTheme.primary).frame(width: 20)
                                TextField("Department (optional)", text: $department)
                                    .autocapitalization(.words)
                            }
                            .hmsTextFieldStyle()

                            // Specialization (doctors only)
                            if selectedRole == .doctor {
                                HStack(spacing: 12) {
                                    Image(systemName: "stethoscope")
                                        .foregroundColor(AppTheme.primary).frame(width: 20)
                                    TextField("Specialization", text: $specialization)
                                        .autocapitalization(.words)
                                }
                                .hmsTextFieldStyle()
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            // Add Button
                            Button {
                                Task { await addStaff() }
                            } label: {
                                HStack(spacing: 8) {
                                    if isLoading {
                                        ProgressView().tint(.white).scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "person.badge.plus.fill")
                                        Text("Add \(selectedRole.displayName) & Send Email")
                                    }
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(isLoading || !formValid)
                        }
                        .padding(20)
                        .glassCard()
                        .padding(.horizontal, 20)
                        .animation(.easeInOut(duration: 0.2), value: selectedRole)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Add Staff Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textSecondary).font(.system(size: 22))
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            // Success confirmation
            .alert("Staff Added 🎉", isPresented: $showSuccess) {
                Button("Done") {
                    onSuccess()
                    dismiss()
                }
            } message: {
                Text("Account created for \(fullName).\n\nA password setup email has been sent to \(email). They must set their password before logging in.")
            }
        }
    }

    private func addStaff() async {
        isLoading = true
        do {
            try await AuthManager.shared.addStaffMember(
                email: email.trimmingCharacters(in: .whitespaces),
                fullName: fullName.trimmingCharacters(in: .whitespaces),
                role: selectedRole,
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

// MARK: - Role Chip
struct RoleChip: View {
    let role: UserRole
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: role.sfSymbol)
                    .font(.system(size: 13))
                Text(role.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : AppTheme.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected
                ? LinearGradient(colors: [AppTheme.primary, AppTheme.primaryMid], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [AppTheme.primaryLight, AppTheme.primaryLight], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppTheme.primary.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddStaffView {}
}
