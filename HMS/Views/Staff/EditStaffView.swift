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
    @State private var consultationFee: String
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
        _consultationFee = State(initialValue: staff.consultationFee != nil ? String(Int(staff.consultationFee!)) : "")

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

    private var initials: String {
        let parts = staff.fullName.components(separatedBy: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        return String(staff.fullName.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // HERO SECTION (matching ProfileView)
                    ZStack(alignment: .bottom) {
                        LinearGradient(
                            colors: [AppTheme.primaryLight.opacity(0.8), AppTheme.background],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 160)
                        .ignoresSafeArea(edges: .top)

                        // Top close button
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: { dismiss() }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppTheme.textPrimary)
                                        .frame(width: 44, height: 44)
                                        .background(AppTheme.cardSurface)
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            Spacer()
                        }

                        // Avatar
                        VStack(spacing: 8) {
                            Circle()
                                .fill(AppTheme.cardSurface)
                                .frame(width: 110, height: 110)
                                .shadow(radius: 10)
                                .overlay(
                                    Text(initials)
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(AppTheme.primaryDark)
                                )
                                .offset(y: 40)
                        }
                    }

                    // Name & Role & Status
                    VStack(spacing: 4) {
                        Text(staff.role.displayName)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textSecondary)

                        Text(staff.fullName)
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundColor(AppTheme.textPrimary)

                        HStack(spacing: 6) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 11))
                            Text(staff.email)
                                .font(.system(size: 13, design: .rounded))
                        }
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.top, 2)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(staff.isActive ? Color.green : Color.gray)
                                .frame(width: 7, height: 7)
                            Text(staff.isActive ? "Active" : "Inactive")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(staff.isActive ? Color.green : AppTheme.textSecondary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.top, 50)

                    // INFO CARDS
                    VStack(spacing: 20) {

                        // PERSONAL DETAILS CARD
                        VStack(alignment: .leading, spacing: 14) {
                            sectionLabel("Personal Details", icon: "person.text.rectangle.fill")
                            editableField("Full Name", icon: "person.fill", text: $fullName)
                            editableField("Phone Number", icon: "phone.fill", text: $phoneNumber, keyboard: .phonePad)
                        }
                        .padding(20)
                        .background(AppTheme.cardSurface)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)

                        // PROFESSIONAL DETAILS CARD
                        VStack(alignment: .leading, spacing: 14) {
                            sectionLabel("Professional Details", icon: "briefcase.fill")
                            editableField("Employee ID", icon: "creditcard.fill", text: $employeeID)
                            editableField("Department", icon: "building.2.fill", text: $department)

                            if staff.role == .doctor {
                                editableField("Specialization", icon: "stethoscope", text: $specialization)
                                editableField("Consultation Fee (₹)", icon: "indianrupesign", text: $consultationFee, keyboard: .numberPad)
                            }
                        }
                        .padding(20)
                        .background(AppTheme.cardSurface)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)

                        // TIME SLOTS CARD (doctors only)
                        if staff.role == .doctor {
                            VStack(alignment: .leading, spacing: 14) {
                                sectionLabel("Availability", icon: "clock.fill")
                                timeSlotSection
                            }
                            .padding(20)
                            .background(AppTheme.cardSurface)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
                        }

                        // SAVE BUTTON
                        Button {
                            Task { await updateStaff() }
                        } label: {
                            HStack(spacing: 10) {
                                if isLoading {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                    Text("Save Changes")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                formValid
                                ? LinearGradient(colors: [AppTheme.primary, AppTheme.primaryMid], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                            .shadow(color: formValid ? AppTheme.primary.opacity(0.25) : .clear, radius: 10, x: 0, y: 5)
                        }
                        .disabled(isLoading || !formValid)
                        .padding(.top, 8)

                        // DEACTIVATE / REACTIVATE BUTTON
                        if let onDeactivate = onDeactivate, staff.isActive {
                            Button {
                                showDeactivateConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.fill.xmark")
                                        .font(.system(size: 16))
                                    Text("Deactivate Staff")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(Color.red.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.cardSurface)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
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

                        if let onReactivate = onReactivate, !staff.isActive {
                            Button {
                                showReactivateConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.fill.checkmark")
                                        .font(.system(size: 16))
                                    Text("Reactivate Staff")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(Color.green)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.cardSurface)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
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
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarHidden(true)
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

    // MARK: - Section Label
    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.primary)
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
        }
    }

    // MARK: - Editable Field
    private func editableField(_ label: String, icon: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .padding(.leading, 2)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.primary.opacity(0.7))
                    .frame(width: 20)

                TextField(label, text: text)
                    .font(.system(size: 15, design: .rounded))
                    .keyboardType(keyboard)
                    .autocapitalization(.words)
            }
            .padding(14)
            .background(AppTheme.background)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Time Slot Section
    private var timeSlotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                .padding(.vertical, 10)
                .background(AppTheme.primaryLight)
                .cornerRadius(12)
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
                phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
                defaultSlots: defaultSlotsArray,
                consultationFee: Double(consultationFee)
            )
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
}
