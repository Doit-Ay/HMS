import SwiftUI
import FirebaseFirestore

// MARK: - Manage Doctor Slots View (Search → Overlay)
struct ManageSlotsView: View {
    @State private var doctors: [HMSUser] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var selectedDoctor: HMSUser? = nil
    @State private var showSlotOverlay = false
    @State private var animate = false
    @AppStorage("recentSlotDoctors") private var recentDoctorIDs: String = ""

    private var recentIDs: [String] {
        recentDoctorIDs.split(separator: ",").map(String.init)
    }

    private var recentDoctors: [HMSUser] {
        let ids = recentIDs
        return ids.compactMap { id in doctors.first(where: { $0.id == id }) }
    }

    private var filteredDoctors: [HMSUser] {
        if searchText.isEmpty { return doctors }
        return doctors.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText) ||
            ($0.department ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            HMSBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // Search Bar
                    searchBarSection

                    // Recent Doctors
                    if searchText.isEmpty && !recentDoctors.isEmpty {
                        recentDoctorsSection
                    }

                    // Doctor List
                    doctorListSection
                }
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Manage Slots")
        .navigationBarTitleDisplayMode(.large)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showSlotOverlay) {
            if let doctor = selectedDoctor {
                NavigationStack {
                    DoctorAvailabilityView(
                        overrideDoctorId: doctor.id,
                        doctorName: doctor.fullName
                    )
                }
            }
        }
        .task {
            await loadDoctors()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animate = true
            }
        }
    }

    // MARK: - Search Bar
    private var searchBarSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(AppTheme.textSecondary)

            TextField("Search doctors by name or department...", text: $searchText)
                .font(.system(size: 15, design: .rounded))
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.85))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    // MARK: - Recent Doctors
    private var recentDoctorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.primaryMid)
                Text("Recent")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentDoctors) { doctor in
                        Button {
                            selectDoctor(doctor)
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [AppTheme.primary.opacity(0.15), AppTheme.primaryMid.opacity(0.10)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "stethoscope.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(AppTheme.primary)
                                }

                                Text(doctor.fullName.components(separatedBy: " ").first ?? doctor.fullName)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .lineLimit(1)

                                if let dept = doctor.department {
                                    Text(dept)
                                        .font(.system(size: 9, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: 72)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .offset(y: animate ? 0 : 15)
        .opacity(animate ? 1 : 0)
    }

    // MARK: - Doctor List
    private var doctorListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(searchText.isEmpty ? "All Doctors" : "Results")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, 20)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading doctors...")
                        .tint(AppTheme.primary)
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if filteredDoctors.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(AppTheme.primaryMid.opacity(0.4))
                    Text(searchText.isEmpty ? "No doctors found" : "No results for \"\(searchText)\"")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredDoctors) { doctor in
                        DoctorSearchRow(doctor: doctor) {
                            selectDoctor(doctor)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .offset(y: animate ? 0 : 20)
        .opacity(animate ? 1 : 0)
    }

    // MARK: - Actions

    private func loadDoctors() async {
        isLoading = true
        do {
            doctors = try await AuthManager.shared.fetchDoctors()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }

    private func selectDoctor(_ doctor: HMSUser) {
        selectedDoctor = doctor
        // Update recent list
        var ids = recentIDs.filter { $0 != doctor.id }
        ids.insert(doctor.id, at: 0)
        if ids.count > 5 { ids = Array(ids.prefix(5)) }
        recentDoctorIDs = ids.joined(separator: ",")
        showSlotOverlay = true
    }
}

// MARK: - Doctor Search Row
struct DoctorSearchRow: View {
    let doctor: HMSUser
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "stethoscope.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.primary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(doctor.fullName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    HStack(spacing: 6) {
                        if let dept = doctor.department {
                            Text(dept)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        if let spec = doctor.specialization {
                            Text("• \(spec)")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                        }
                    }
                }

                Spacer()

                // Slot count badge
                if let slots = doctor.defaultSlots, !slots.isEmpty {
                    Text("\(slots.count) slots")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.primaryLight)
                        .cornerRadius(20)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary.opacity(0.4))
            }
            .padding(14)
            .background(Color.white.opacity(0.85))
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Doctor Slot Overlay (Sheet)
struct DoctorSlotOverlay: View {
    let doctor: HMSUser
    @Environment(\.dismiss) var dismiss
    @State private var selectedDate = Date()
    @State private var slots: [DoctorSlot] = []
    @State private var isFetching = false
    @State private var showAddSlot = false
    @State private var errorMessage = ""
    @State private var showError = false

    private var dateString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: selectedDate)
    }

    private var displayDateString: String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: selectedDate)
    }

    /// Parse the doctor's default slots into display items
    private var defaultSlotLabels: [(label: String, time: String)] {
        guard let defaults = doctor.defaultSlots else { return [] }
        return defaults.map { slot in
            switch slot {
            case "morning":   return ("Morning", "9:00 AM – 1:00 PM")
            case "afternoon": return ("Afternoon", "1:00 PM – 5:00 PM")
            case "evening":   return ("Evening", "5:00 PM – 10:00 PM")
            default:          return ("Custom", slot)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HMSBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // Doctor Info Header
                        doctorHeader

                        // Default Slots Display
                        defaultSlotsSection

                        // Date Picker
                        datePickerRow

                        // Actions
                        actionsRow

                        // Slots for selected date
                        dateSlotsSection
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Slot Management")
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
            .sheet(isPresented: $showAddSlot) {
                AddSlotSheet(doctor: doctor, date: selectedDate, onSuccess: { fetchSlots() })
            }
            .onAppear { fetchSlots() }
        }
    }

    // MARK: - Doctor Header
    private var doctorHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primaryMid],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: "stethoscope.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(doctor.fullName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 6) {
                    if let dept = doctor.department {
                        Text(dept)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    if let spec = doctor.specialization {
                        Text("• \(spec)")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                    }
                }
            }

            Spacer()
        }
        .padding(18)
        .background(Color.white.opacity(0.85))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    // MARK: - Default Slots
    private var defaultSlotsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Default Availability")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, 20)

            if defaultSlotLabels.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.warning)
                        Text("No default slots assigned")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                        Text("Edit this doctor's profile to set default time slots")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.7))
                .cornerRadius(14)
                .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(defaultSlotLabels, id: \.time) { item in
                            VStack(spacing: 4) {
                                Image(systemName: item.label == "Morning" ? "sunrise.fill" : item.label == "Afternoon" ? "sun.max.fill" : item.label == "Evening" ? "moon.fill" : "clock.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.primary)
                                Text(item.label)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text(item.time)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(AppTheme.primaryLight)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AppTheme.primary.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Date Picker Row
    private var datePickerRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 18))
                .foregroundColor(AppTheme.primary)

            Text("Date")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .tint(AppTheme.primary)
                .labelsHidden()
                .onChange(of: selectedDate) { _ in
                    fetchSlots()
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.85))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        .padding(.horizontal, 20)
    }

    // MARK: - Actions Row
    private var actionsRow: some View {
        HStack {
            Button {
                showAddSlot = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Add Slot")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryMid],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: AppTheme.primary.opacity(0.3), radius: 6, x: 0, y: 3)
            }

            Spacer()

            if !slots.isEmpty {
                HStack(spacing: 6) {
                    let avail = slots.filter { $0.status == .available }.count
                    let unavail = slots.filter { $0.status == .unavailable }.count
                    let booked = slots.filter { $0.status == .booked }.count
                    if avail > 0 { BadgePill(count: avail, label: "Avail", color: AppTheme.success) }
                    if unavail > 0 { BadgePill(count: unavail, label: "Off", color: AppTheme.warning) }
                    if booked > 0 { BadgePill(count: booked, label: "Booked", color: Color(hex: "#6366F1")) }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Date Slots
    private var dateSlotsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Slots for \(displayDateString)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, 20)

            if isFetching {
                HStack {
                    Spacer()
                    ProgressView("Loading slots...")
                        .tint(AppTheme.primary)
                    Spacer()
                }
                .padding(.vertical, 30)
            } else if slots.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.primaryMid.opacity(0.4))
                    Text("No slots for this date")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    Text("Tap \"+ Add Slot\" to create a time slot")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(slots) { slot in
                        SlotRowView(slot: slot, onToggle: { newStatus in
                            toggleSlot(slot, to: newStatus)
                        }, onDelete: {
                            deleteSlot(slot)
                        })
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Actions

    private func fetchSlots() {
        isFetching = true
        Task {
            do {
                let fetched = try await AuthManager.shared.fetchSlots(
                    doctorId: doctor.id, date: dateString
                )
                withAnimation(.spring()) { slots = fetched }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isFetching = false
        }
    }

    private func toggleSlot(_ slot: DoctorSlot, to newStatus: SlotStatus) {
        Task {
            do {
                try await AuthManager.shared.toggleSlotStatus(slotId: slot.id, newStatus: newStatus)
                fetchSlots()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func deleteSlot(_ slot: DoctorSlot) {
        Task {
            do {
                try await AuthManager.shared.deleteSlot(slotId: slot.id)
                withAnimation(.spring()) { slots.removeAll { $0.id == slot.id } }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Slot Row View
struct SlotRowView: View {
    let slot: DoctorSlot
    let onToggle: (SlotStatus) -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirm = false

    private var statusColor: Color {
        switch slot.status {
        case .available:   return AppTheme.success
        case .unavailable: return AppTheme.warning
        case .booked:      return Color(hex: "#6366F1")
        }
    }

    private var durationLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        guard let start = formatter.date(from: slot.startTime),
              let end = formatter.date(from: slot.endTime) else { return "slot" }
        let diff = Int(end.timeIntervalSince(start)) / 60
        if diff >= 60 {
            let h = diff / 60, m = diff % 60
            return m > 0 ? "\(h)h \(m)m slot" : "\(h)h slot"
        }
        return "\(diff) min slot"
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(slot.startTime)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.textPrimary)
                Text(slot.endTime)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(width: 56)

            Rectangle()
                .fill(statusColor)
                .frame(width: 3, height: 36)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 2) {
                Text(slot.status.displayName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(statusColor)
                Text(durationLabel)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            if slot.status != .booked {
                HStack(spacing: 8) {
                    Button { onToggle(.available) } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(slot.status == .available ? AppTheme.success : AppTheme.success.opacity(0.25))
                    }
                    .buttonStyle(.plain)

                    Button { onToggle(.unavailable) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(slot.status == .unavailable ? AppTheme.warning : AppTheme.warning.opacity(0.25))
                    }
                    .buttonStyle(.plain)

                    Button { showDeleteConfirm = true } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppTheme.error.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.textSecondary.opacity(0.5))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.85))
        .cornerRadius(14)
        .shadow(color: statusColor.opacity(0.08), radius: 6, x: 0, y: 3)
        .confirmationDialog(
            "Delete this slot?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete \(slot.startTime) – \(slot.endTime)", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove this time slot.")
        }
    }
}

// MARK: - Badge Pill
struct BadgePill: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .cornerRadius(10)
    }
}

// MARK: - Add Slot Sheet (Custom Timing)
struct AddSlotSheet: View {
    @Environment(\.dismiss) var dismiss
    let doctor: HMSUser
    let date: Date
    let onSuccess: () -> Void

    @State private var startTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    @State private var endTime   = Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: Date())!
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var errorMessage = ""
    @State private var showError = false

    private var dateString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private var displayDateString: String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: date)
    }

    private var startTimeString: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: startTime)
    }

    private var endTimeString: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: endTime)
    }

    private var isValid: Bool { endTime > startTime }

    private var durationText: String {
        let diff = Int(endTime.timeIntervalSince(startTime)) / 60
        if diff <= 0 { return "Invalid" }
        if diff >= 60 {
            let h = diff / 60, m = diff % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(diff) min"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HMSBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Doctor + Date Info
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.primary.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "stethoscope.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(AppTheme.primary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doctor.fullName)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text(displayDateString)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            Spacer()
                            if let dept = doctor.department {
                                Text(dept)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.primaryMid)
                                    .cornerRadius(20)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(16)
                        .padding(.horizontal, 20)

                        // Time Pickers
                        VStack(spacing: 18) {
                            Text("Set Slot Time")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                                .font(.system(size: 15, design: .rounded))
                                .tint(AppTheme.primary)
                                .onChange(of: startTime) { newVal in
                                    if endTime <= newVal {
                                        endTime = Calendar.current.date(byAdding: .minute, value: 30, to: newVal)!
                                    }
                                }

                            DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                                .font(.system(size: 15, design: .rounded))
                                .tint(AppTheme.primary)

                            Divider().opacity(0.15)

                            // Duration Preview
                            HStack(spacing: 10) {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(isValid ? AppTheme.primary : AppTheme.error)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Duration")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                    Text(isValid ? "\(startTimeString) → \(endTimeString)  (\(durationText))" : "End time must be after start time")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(isValid ? AppTheme.textPrimary : AppTheme.error)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background((isValid ? AppTheme.primaryLight : AppTheme.error.opacity(0.08)))
                            .cornerRadius(14)

                            Button {
                                Task { await addSlot() }
                            } label: {
                                HStack(spacing: 8) {
                                    if isSaving {
                                        ProgressView().tint(.white).scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Slot")
                                    }
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(isSaving || !isValid)
                        }
                        .padding(20)
                        .glassCard()
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Add Slot")
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
            .alert("Slot Added ✅", isPresented: $showSuccess) {
                Button("Add Another") {
                    onSuccess()
                    startTime = endTime
                    endTime = Calendar.current.date(byAdding: .minute, value: 30, to: endTime)!
                }
                Button("Done") {
                    onSuccess()
                    dismiss()
                }
            } message: {
                Text("\(startTimeString) – \(endTimeString) has been added for Dr. \(doctor.fullName).")
            }
        }
    }

    private func addSlot() async {
        isSaving = true
        do {
            let slot = DoctorSlot(
                id: UUID().uuidString,
                doctorId: doctor.id,
                doctorName: doctor.fullName,
                department: doctor.department,
                date: dateString,
                startTime: startTimeString,
                endTime: endTimeString,
                status: .available,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await AuthManager.shared.addDoctorSlot(slot)
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}

// MARK: - Doctor Chip (kept for compatibility)
struct DoctorChip: View {
    let doctor: HMSUser
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                            ? LinearGradient(colors: [AppTheme.primary, AppTheme.primaryMid], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [AppTheme.primary.opacity(0.12), AppTheme.primary.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: "stethoscope.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .white : AppTheme.primary)
                }

                Text(doctor.fullName.components(separatedBy: " ").first ?? doctor.fullName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? AppTheme.primary : AppTheme.textSecondary)
                    .lineLimit(1)

                if let dept = doctor.department {
                    Text(dept)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .frame(width: 72)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? AppTheme.primaryLight : Color.white.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppTheme.primary.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
