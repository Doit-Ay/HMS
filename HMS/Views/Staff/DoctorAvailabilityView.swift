import SwiftUI

struct DoctorAvailabilityView: View {
    // Optional: when admin manages a specific doctor's availability
    var overrideDoctorId: String? = nil
    var doctorName: String? = nil
    var overrideDoctor: HMSUser? = nil
    
    @ObservedObject var session = UserSession.shared
    @State private var appearAnimation = false
    
    // Calendar State
    @State private var selectedDate: Date? = Date()
    @State private var availabilityMap: [Date: DayAvailabilityState] = [:]
    
    // Tracks Firestore doc IDs for each date so we can delete/update
    @State private var unavailabilityIDs: [Date: String] = [:]
    
    // Tracks stored unavailableSlots per date for re-selecting
    @State private var storedUnavailableSlots: [Date: [String]] = [:]
    
    // Visible month for fetching
    @State private var visibleMonth: Date = Date()
    
    // Bottom Panel State
    @State private var markAsSelection: DayAvailabilityState = .available
    @State private var originalSelection: DayAvailabilityState = .available
    
    // Slot picker state (replaces old startTime/endTime)
    @State private var availableSlots: [(start: String, end: String, isBooked: Bool)] = []
    @State private var selectedUnavailableSlots: Set<String> = []
    @State private var isFetchingSlots = false
    
    // Toast & Alert State
    @State private var showToast = false
    @State private var showConflictAlert = false
    @State private var errorMessage: String? = nil
    @State private var isSaving = false
    @State private var isLoading = false
    
    private var currentDoctorId: String? {
        overrideDoctorId ?? session.currentUser?.id
    }
    
    private var headerTitle: String {
        if let name = doctorName {
            return "Dr. \(name)"
        }
        return "My Availability"
    }
    
    private var visibleMonthString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"
        return f.string(from: visibleMonth)
    }
    
    /// Save button only visible when something actually changed
    private var hasChanges: Bool {
        guard selectedDate != nil else { return false }
        if markAsSelection != originalSelection { return true }
        // Also check if slot selection changed for halfDay
        if markAsSelection == .halfDay {
            let startOfDay = Calendar.current.startOfDay(for: selectedDate!)
            let stored = Set(storedUnavailableSlots[startOfDay] ?? [])
            return selectedUnavailableSlots != stored
        }
        return false
    }
    
    /// Resolve the target doctor (override for admin, or logged-in user)
    private var targetDoctor: HMSUser? {
        overrideDoctor ?? session.currentUser
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // 1. Header
                HStack {
                    // Left spacer for balance
                    Color.clear.frame(width: 44, height: 44)
                    
                    Spacer()
                    
                    Text(headerTitle)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Spacer()
                    
                    // Save button — only visible when a change is made
                    if hasChanges {
                        Button(action: handleSaveRequest) {
                            if isSaving {
                                ProgressView()
                                    .tint(AppTheme.primary)
                                    .frame(width: 60, height: 36)
                            } else {
                                Text("Save")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        ZStack {
                                            AppTheme.cardSurface
                                            AppTheme.primary.opacity(0.08)
                                        }
                                    )
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(AppTheme.primary.opacity(0.3), lineWidth: 1)
                                    )
                                    .shadow(color: AppTheme.primary.opacity(0.15), radius: 8, x: 0, y: 4)
                            }
                        }
                        .disabled(isSaving)
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .offset(y: appearAnimation ? 0 : -20)
                .opacity(appearAnimation ? 1 : 0)
                
                // Scrollable Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Loading indicator
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView("Loading availability...")
                                    .tint(AppTheme.primary)
                                Spacer()
                            }
                            .padding(.top, 20)
                        }
                        
                        // 2. Calendar
                        AvailabilityCalendarView(
                            selectedDate: $selectedDate,
                            availabilityMap: availabilityMap
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .offset(y: appearAnimation ? 0 : 20)
                        // Trigger bottom panel update when selected date changes
                        .onChange(of: selectedDate) { newDate in
                            if let date = newDate {
                                let startOfDay = Calendar.current.startOfDay(for: date)
                                let saved = availabilityMap[startOfDay] ?? .available
                                markAsSelection = saved
                                originalSelection = saved
                                
                                // Restore previously stored slot selections
                                selectedUnavailableSlots = Set(storedUnavailableSlots[startOfDay] ?? [])
                                
                                // Fetch slots for this date
                                fetchSlotsForDate(date)
                            }
                        }
                        
                        // Only show options if a valid date is selected
                        if selectedDate != nil {
                            // Bottom Options Container
                            VStack(alignment: .leading, spacing: 24) {
                                
                                // 3. Mark As Toggle
                                MarkAsToggleView(selection: $markAsSelection)
                                    .onChange(of: markAsSelection) { newValue in
                                        if newValue == .halfDay, let date = selectedDate {
                                            fetchSlotsForDate(date)
                                        }
                                    }
                                
                                // 4. Slot Picker (replaces old TimeRangePickerView)
                                if markAsSelection == .halfDay {
                                    SlotPickerGridView(
                                        slots: availableSlots,
                                        selectedSlotKeys: $selectedUnavailableSlots,
                                        isLoading: isFetchingSlots
                                    )
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                            .padding(.top, 8)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                        } else {
                            // Blank state when no date is picked
                            VStack(spacing: 12) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                                Text("Select a date to manage availability")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }
                    }
                }
            } // End of Main VStack
            .opacity(appearAnimation ? 1 : 0)
            
            // Error message (shown inline above toast area)
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
            loadUnavailability()
            // Fetch slots for initially selected date
            if let date = selectedDate {
                fetchSlotsForDate(date)
            }
        }
        .refreshable { loadUnavailability() }
        .alert("Success", isPresented: $showToast) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Availability updated")
        }
        // Conflict Alert Modal
        .alert(isPresented: $showConflictAlert) {
            Alert(
                title: Text("Conflict Detected"),
                message: Text("You have appointments on this day. Marking unavailable will notify patients."),
                primaryButton: .destructive(Text("Mark Anyway")) { executeSave() },
                secondaryButton: .cancel()
            )
        }
    }
    
    // MARK: - Fetch Slots for Selected Date
    
    private func fetchSlotsForDate(_ date: Date) {
        guard let doctor = targetDoctor, let defaults = doctor.defaultSlots, !defaults.isEmpty else {
            availableSlots = []
            return
        }
        guard let doctorId = currentDoctorId else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        isFetchingSlots = true
        
        Task {
            do {
                // Fetch booked slots for this date
                let bookedSlots = try await AuthManager.shared.fetchSlots(
                    doctorId: doctorId, date: dateString
                ).filter { $0.status == .booked }
                
                // Generate 30-min chunks from the doctor's defaultSlots
                let chunks = AuthManager.shared.generate30MinSlots(
                    from: defaults,
                    unavailability: nil, // Don't filter — we want to show ALL slots
                    bookedSlots: bookedSlots
                )
                
                await MainActor.run {
                    withAnimation {
                        availableSlots = chunks
                    }
                    isFetchingSlots = false
                }
            } catch {
                await MainActor.run {
                    availableSlots = []
                    isFetchingSlots = false
                }
            }
        }
    }
    
    // MARK: - Load Unavailability from Firestore

    private func loadUnavailability() {
        guard let doctorId = currentDoctorId else { return }
        isLoading = true
        
        Task {
            do {
                let entries = try await AuthManager.shared.fetchUnavailability(
                    doctorId: doctorId,
                    month: visibleMonthString
                )
                
                let calendar = Calendar.current
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                var newMap: [Date: DayAvailabilityState] = [:]
                var newIDs: [Date: String] = [:]
                var newStoredSlots: [Date: [String]] = [:]
                
                for entry in entries {
                    guard let date = dateFormatter.date(from: entry.date) else { continue }
                    let startOfDay = calendar.startOfDay(for: date)
                    
                    switch entry.type {
                    case "unavailable":
                        newMap[startOfDay] = .unavailable
                    case "halfDay":
                        newMap[startOfDay] = .halfDay
                        // Restore slot selections
                        if let slots = entry.unavailableSlots, !slots.isEmpty {
                            newStoredSlots[startOfDay] = slots
                        }
                    default:
                        break
                    }
                    newIDs[startOfDay] = entry.id
                }
                
                withAnimation {
                    availabilityMap = newMap
                    unavailabilityIDs = newIDs
                    storedUnavailableSlots = newStoredSlots
                }
                
                // Sync toggle for currently selected date
                if let selected = selectedDate {
                    let startOfDay = calendar.startOfDay(for: selected)
                    markAsSelection = availabilityMap[startOfDay] ?? .available
                    selectedUnavailableSlots = Set(storedUnavailableSlots[startOfDay] ?? [])
                }
            } catch {
                print("⚠️ Availability fetch error: \(error.localizedDescription)")
                // Don't show raw Firestore index errors to users
                withAnimation { errorMessage = "Unable to load availability. Please try again." }
            }
            isLoading = false
        }
    }
    
    // MARK: - Save Flow
    
    private func handleSaveRequest() {
        guard selectedDate != nil else {
            withAnimation { errorMessage = "Please select a date first" }
            return
        }
        errorMessage = nil
        executeSave()
    }
    
    private func executeSave() {
        guard let date = selectedDate, let doctorId = currentDoctorId else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Get doctor name for notification messages
        let docName = doctorName ?? session.currentUser?.fullName ?? "Your doctor"
        
        isSaving = true
        
        Task {
            do {
                switch markAsSelection {
                case .available:
                    // Remove any existing unavailability entry for this date
                    try await AuthManager.shared.deleteUnavailability(
                        doctorId: doctorId, date: dateString
                    )
                    withAnimation {
                        availabilityMap.removeValue(forKey: startOfDay)
                        unavailabilityIDs.removeValue(forKey: startOfDay)
                        storedUnavailableSlots.removeValue(forKey: startOfDay)
                    }
                    
                case .unavailable:
                    let entryId = unavailabilityIDs[startOfDay] ?? UUID().uuidString
                    let entry = DoctorUnavailability(
                        id: entryId,
                        doctorId: doctorId,
                        date: dateString,
                        type: "unavailable",
                        startTime: nil,
                        endTime: nil,
                        unavailableSlots: nil,
                        createdAt: Date()
                    )
                    try await AuthManager.shared.saveUnavailability(entry)
                    withAnimation {
                        availabilityMap[startOfDay] = .unavailable
                        unavailabilityIDs[startOfDay] = entryId
                        storedUnavailableSlots.removeValue(forKey: startOfDay)
                    }
                    
                    // Notify patients with conflicting appointments
                    await notifyConflictingPatients(
                        doctorId: doctorId,
                        doctorName: docName,
                        date: dateString,
                        type: "unavailable",
                        startTime: nil,
                        endTime: nil
                    )
                    
                case .halfDay:
                    let slotsArray = Array(selectedUnavailableSlots).sorted()
                    let entryId = unavailabilityIDs[startOfDay] ?? UUID().uuidString
                    let entry = DoctorUnavailability(
                        id: entryId,
                        doctorId: doctorId,
                        date: dateString,
                        type: "halfDay",
                        startTime: nil,
                        endTime: nil,
                        unavailableSlots: slotsArray,
                        createdAt: Date()
                    )
                    try await AuthManager.shared.saveUnavailability(entry)
                    withAnimation {
                        availabilityMap[startOfDay] = .halfDay
                        unavailabilityIDs[startOfDay] = entryId
                        storedUnavailableSlots[startOfDay] = slotsArray
                    }
                    
                    // Notify patients with conflicting appointments for each selected slot
                    for slotKey in slotsArray {
                        let parts = slotKey.split(separator: "-").map(String.init)
                        if parts.count == 2 {
                            await notifyConflictingPatients(
                                doctorId: doctorId,
                                doctorName: docName,
                                date: dateString,
                                type: "halfDay",
                                startTime: parts[0],
                                endTime: parts[1]
                            )
                        }
                    }
                }
                
                // Show success alert
                showToast = true
                // Sync original so Save button hides
                originalSelection = markAsSelection
            } catch {
                withAnimation { errorMessage = error.localizedDescription }
            }
            isSaving = false
        }
    }
    
    // MARK: - Notify Conflicting Patients
    
    /// Finds all scheduled appointments that conflict with the new unavailability
    /// and creates notification records for each affected patient.
    private func notifyConflictingPatients(
        doctorId: String,
        doctorName: String,
        date: String,
        type: String,
        startTime: String?,
        endTime: String?
    ) async {
        do {
            let conflicting = try await AuthManager.shared.fetchConflictingAppointments(
                doctorId: doctorId,
                date: date,
                unavailabilityType: type,
                unavailStartTime: startTime,
                unavailEndTime: endTime
            )
            
            // Format date for display
            let displayDate: String = {
                let inFmt = DateFormatter(); inFmt.dateFormat = "yyyy-MM-dd"
                guard let d = inFmt.date(from: date) else { return date }
                let outFmt = DateFormatter(); outFmt.dateFormat = "MMM d, yyyy"
                return outFmt.string(from: d)
            }()
            
            for appointment in conflicting {
                let notification = AppNotification(
                    id: UUID().uuidString,
                    recipientId: appointment.patientId,
                    title: "Appointment Reschedule Required",
                    message: "Dr. \(doctorName) is no longer available on \(displayDate) at \(appointment.startTime). Please reschedule your appointment.",
                    type: "reschedule_request",
                    appointmentId: appointment.id,
                    doctorId: doctorId,
                    isRead: false,
                    createdAt: Date()
                )
                try await AuthManager.shared.saveNotification(notification)
            }
            
            if !conflicting.isEmpty {
                print("📬 Sent \(conflicting.count) reschedule notification(s) to affected patients")
            }
        } catch {
            print("⚠️ Failed to notify conflicting patients: \(error.localizedDescription)")
        }
    }

}

#Preview {
    DoctorAvailabilityView()
}
