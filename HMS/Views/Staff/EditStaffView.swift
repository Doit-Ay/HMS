import SwiftUI

// MARK: - Edit Staff View (Sheet)
struct EditStaffView: View {
    @Environment(\.dismiss) var dismiss
    let staff: HMSUser
    var onDeactivate: (() -> Void)? = nil
    var onReactivate: (() -> Void)? = nil
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
    @State private var showDeactivateConfirm = false
    @State private var showReactivateConfirm = false

    // Time Slot Selection (doctors only)
    @State private var morningSelected    = false
    @State private var afternoonSelected  = false
    @State private var eveningSelected    = false
    @State private var customSlots: [(start: Date, end: Date)] = []
    @State private var showCustomPicker   = false

    init(staff: HMSUser, onDeactivate: (() -> Void)? = nil, onReactivate: (() -> Void)? = nil, onUpdate: @escaping () -> Void) {
        self.staff = staff
        self.onDeactivate = onDeactivate
        self.onReactivate = onReactivate
        self.onUpdate = onUpdate
        _fullName = State(initialValue: staff.fullName)
        _phoneNumber = State(initialValue: staff.phoneNumber ?? "")
        _employeeID = State(initialValue: staff.employeeID ?? "")
        _department = State(initialValue: staff.department ?? "")
        _specialization = State(initialValue: staff.specialization ?? "")

        // Parse existing defaultSlots
        var morning = false, afternoon = false, evening = false
        var customs: [(start: Date, end: Date)] = []
        if let slots = staff.defaultSlots {
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            for s in slots {
                switch s {
                case "morning":   morning = true
                case "afternoon": afternoon = true
                case "evening":   evening = true
                default:
                    let parts = s.split(separator: "-")
                    if parts.count == 2,
                       let start = f.date(from: String(parts[0])),
                       let end = f.date(from: String(parts[1])) {
                        customs.append((start: start, end: end))
                    }
                }
            }
        }
        _morningSelected = State(initialValue: morning)
        _afternoonSelected = State(initialValue: afternoon)
        _eveningSelected = State(initialValue: evening)
        _customSlots = State(initialValue: customs)
    }

    var formValid: Bool {
        !fullName.isEmpty
    }

    /// Build the defaultSlots array from selections
    private var defaultSlotsArray: [String]? {
        guard staff.role == .doctor else { return nil }
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

                            // Time Slot Section (doctors only)
                            if staff.role == .doctor {
                                Divider().opacity(0.15)
                                timeSlotSection
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

                            // Deactivate Button
                            if let onDeactivate = onDeactivate, staff.isActive {
                                Divider().opacity(0.15).padding(.vertical, 4)

                                Button {
                                    showDeactivateConfirm = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "person.fill.xmark")
                                        Text("Deactivate Staff")
                                    }
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.red.opacity(0.85), Color.red],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(14)
                                }
                                .buttonStyle(.plain)
                                .confirmationDialog(
                                    "Deactivate \(staff.fullName)?",
                                    isPresented: $showDeactivateConfirm,
                                    titleVisibility: .visible
                                ) {
                                    Button("Deactivate", role: .destructive) {
                                        onDeactivate()
                                        dismiss()
                                    }
                                    Button("Cancel", role: .cancel) {}
                                } message: {
                                    Text("This will deactivate \(staff.fullName). They won't be able to log in until reactivated.")
                                }
                            }

                            // Reactivate Button
                            if let onReactivate = onReactivate, !staff.isActive {
                                Divider().opacity(0.15).padding(.vertical, 4)

                                Button {
                                    showReactivateConfirm = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "person.fill.checkmark")
                                        Text("Reactivate Staff")
                                    }
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        LinearGradient(
                                            colors: [AppTheme.success.opacity(0.85), AppTheme.success],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(14)
                                }
                                .buttonStyle(.plain)
                                .confirmationDialog(
                                    "Reactivate \(staff.fullName)?",
                                    isPresented: $showReactivateConfirm,
                                    titleVisibility: .visible
                                ) {
                                    Button("Reactivate", role: .none) {
                                        onReactivate()
                                        dismiss()
                                    }
                                    Button("Cancel", role: .cancel) {}
                                } message: {
                                    Text("This will restore login access and functionality for \(staff.fullName).")
                                }
                            }
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
