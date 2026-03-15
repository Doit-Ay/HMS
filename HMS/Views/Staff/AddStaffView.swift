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
    @State private var animate        = false

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
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // HEADER
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.primary, AppTheme.primaryMid],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 70, height: 70)
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundColor(.white)
                            }

                            Text("Add New Staff")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)

                            Text("Fill in the details to register a new staff member")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)
                        .offset(y: animate ? 0 : -20)
                        .opacity(animate ? 1 : 0)

                        // ROLE SELECTION SECTION
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("Role", icon: "person.2.fill")

                            HStack(spacing: 12) {
                                ForEach(staffRoles, id: \.self) { role in
                                    RoleChip(role: role, isSelected: selectedRole == role) {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            selectedRole = role
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .offset(y: animate ? 0 : 20)
                        .opacity(animate ? 1 : 0)

                        // INFO BANNER
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.badge.shield.half.filled.fill")
                                .font(.system(size: 20))
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
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.primary.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        .offset(y: animate ? 0 : 20)
                        .opacity(animate ? 1 : 0)

                        // PERSONAL DETAILS SECTION
                        VStack(alignment: .leading, spacing: 14) {
                            sectionLabel("Personal Details", icon: "person.text.rectangle.fill")

                            formField(icon: "person.fill", placeholder: "Full Name *", text: $fullName, capitalization: .words)
                            formField(icon: "creditcard.fill", placeholder: "Employee ID (optional)", text: $employeeID, capitalization: .allCharacters)

                            if selectedRole == .doctor {
                                formField(icon: "stethoscope", placeholder: "Specialization", text: $specialization, capitalization: .words)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            formField(icon: "building.2.fill", placeholder: "Department (optional)", text: $department, capitalization: .words)
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 20)
                        .animation(.easeInOut(duration: 0.2), value: selectedRole)
                        .offset(y: animate ? 0 : 25)
                        .opacity(animate ? 1 : 0)

                        // CONTACT DETAILS SECTION
                        VStack(alignment: .leading, spacing: 14) {
                            sectionLabel("Contact", icon: "envelope.fill")

                            formField(icon: "envelope.fill", placeholder: "Email Address *", text: $email, keyboardType: .emailAddress, capitalization: .none)
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 20)
                        .offset(y: animate ? 0 : 30)
                        .opacity(animate ? 1 : 0)

                        // TIME SLOTS SECTION (doctors only)
                        if selectedRole == .doctor {
                            VStack(alignment: .leading, spacing: 14) {
                                sectionLabel("Availability", icon: "clock.fill")

                                timeSlotSection
                            }
                            .padding(20)
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .offset(y: animate ? 0 : 35)
                            .opacity(animate ? 1 : 0)
                        }

                        // ADD BUTTON
                        Button {
                            Task { await addStaff() }
                        } label: {
                            HStack(spacing: 10) {
                                if isLoading {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "person.badge.plus.fill")
                                        .font(.system(size: 18))
                                    Text("Add \(selectedRole.displayName) & Send Email")
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
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                        .offset(y: animate ? 0 : 40)
                        .opacity(animate ? 1 : 0)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
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
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    animate = true
                }
            }
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

    // MARK: - Form Field
    private func formField(icon: String, placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default, capitalization: UITextAutocapitalizationType = .words) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.primary.opacity(0.7))
                .frame(width: 20)

            TextField(placeholder, text: text)
                .font(.system(size: 15, design: .rounded))
                .keyboardType(keyboardType)
                .autocapitalization(capitalization)
                .disableAutocorrection(keyboardType == .emailAddress)
        }
        .padding(14)
        .background(AppTheme.background)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
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
                : LinearGradient(colors: [AppTheme.background, AppTheme.background], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.clear : AppTheme.primary.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: isSelected ? AppTheme.primary.opacity(0.2) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
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
            HStack(spacing: 8) {
                Image(systemName: role.sfSymbol)
                    .font(.system(size: 14))
                Text(role.displayName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : AppTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected
                ? LinearGradient(colors: [AppTheme.primary, AppTheme.primaryMid], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [Color.white, Color.white], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.clear : AppTheme.primary.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: isSelected ? AppTheme.primary.opacity(0.2) : Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    AddStaffView {}
}
