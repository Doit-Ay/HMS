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

    // Time Slot Selection (doctors only)
    @State private var morningSelected    = false
    @State private var afternoonSelected  = false
    @State private var eveningSelected    = false
    @State private var customSlots: [(start: Date, end: Date)] = []
    @State private var showCustomPicker   = false

    let staffRoles: [UserRole] = [.doctor, .labTechnician]

    var formValid: Bool {
        !fullName.isEmpty && !email.isEmpty && email.contains("@")
    }

    /// Build the defaultSlots array from selections
    private var defaultSlotsArray: [String]? {
        guard selectedRole == .doctor else { return nil }
        var slots: [String] = []
        if morningSelected   { slots.append("morning") }
        if afternoonSelected { slots.append("afternoon") }
        if eveningSelected   { slots.append("evening") }
        for custom in customSlots {
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            slots.append("\(f.string(from: custom.start))-\(f.string(from: custom.end))")
        }
        return slots.isEmpty ? nil : slots
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

                            // Time Slot Selection (doctors only)
                            if selectedRole == .doctor {
                                timeSlotSection
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

    // MARK: - Time Slot Section
    private var timeSlotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Default Time Slots")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.primary)

            Text("Select when this doctor is available by default")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)

            // 3 preset chips
            HStack(spacing: 10) {
                SlotPresetChip(
                    label: "Morning",
                    time: "9 AM – 1 PM",
                    icon: "sunrise.fill",
                    isSelected: morningSelected
                ) { morningSelected.toggle() }

                SlotPresetChip(
                    label: "Afternoon",
                    time: "1 PM – 5 PM",
                    icon: "sun.max.fill",
                    isSelected: afternoonSelected
                ) { afternoonSelected.toggle() }

                SlotPresetChip(
                    label: "Evening",
                    time: "5 PM – 10 PM",
                    icon: "moon.fill",
                    isSelected: eveningSelected
                ) { eveningSelected.toggle() }
            }

            // Custom slots
            ForEach(customSlots.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(AppTheme.primaryMid)
                        .font(.system(size: 14))

                    let f = DateFormatter()
                    let _ = f.dateFormat = "h:mm a"
                    Text("\(f.string(from: customSlots[index].start)) – \(f.string(from: customSlots[index].end))")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Spacer()

                    Button {
                        customSlots.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.error.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.primaryLight)
                .cornerRadius(10)
            }

            // Add Custom button
            Button {
                showCustomPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("Add Custom Slot")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundColor(AppTheme.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.primaryLight)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.primary.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showCustomPicker) {
                CustomSlotPickerSheet { start, end in
                    customSlots.append((start: start, end: end))
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.6))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.primary.opacity(0.15), lineWidth: 1)
        )
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
                employeeID: employeeID.isEmpty ? nil : employeeID,
                defaultSlots: defaultSlotsArray
            )
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
}

// MARK: - Slot Preset Chip
struct SlotPresetChip: View {
    let label: String
    let time: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .white : AppTheme.primary)

                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : AppTheme.textPrimary)

                Text(time)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(isSelected ? .white.opacity(0.85) : AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected
                ? LinearGradient(colors: [AppTheme.primary, AppTheme.primaryMid], startPoint: .topLeading, endPoint: .bottomTrailing)
                : LinearGradient(colors: [Color.white.opacity(0.8), Color.white.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.clear : AppTheme.primary.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: isSelected ? AppTheme.primary.opacity(0.2) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Slot Picker Sheet
struct CustomSlotPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    let onAdd: (Date, Date) -> Void

    @State private var startTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
    @State private var endTime   = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!

    private var isValid: Bool { endTime > startTime }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                        .font(.system(size: 15, design: .rounded))
                        .tint(AppTheme.primary)
                        .onChange(of: startTime) { newVal in
                            if endTime <= newVal {
                                endTime = Calendar.current.date(byAdding: .hour, value: 1, to: newVal)!
                            }
                        }

                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                        .font(.system(size: 15, design: .rounded))
                        .tint(AppTheme.primary)

                    if !isValid {
                        Text("End time must be after start time")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(AppTheme.error)
                    }
                }
                .padding(20)
                .glassCard()
                .padding(.horizontal, 20)

                Button {
                    onAdd(startTime, endTime)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Custom Slot")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isValid)
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Custom Time Slot")
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
        }
        .presentationDetents([.medium])
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
