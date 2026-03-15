import SwiftUI

struct DoctorAvailabilityView: View {
    // Optional: when admin manages a specific doctor's availability
    var overrideDoctorId: String? = nil
    var doctorName: String? = nil
    
    @ObservedObject var session = UserSession.shared
    @State private var appearAnimation = false
    
    // Calendar State
    @State private var selectedDate: Date? = Date()
    @State private var availabilityMap: [Date: DayAvailabilityState] = [:]
    
    // Tracks Firestore doc IDs for each date so we can delete/update
    @State private var unavailabilityIDs: [Date: String] = [:]
    
    // Visible month for fetching
    @State private var visibleMonth: Date = Date()
    
    // Bottom Panel State
    @State private var markAsSelection: DayAvailabilityState = .available
    @State private var originalSelection: DayAvailabilityState = .available
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600)
    
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
        return markAsSelection != originalSelection
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
                                            Color.white.opacity(0.35)
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
                            }
                        }
                        
                        // Only show options if a valid date is selected
                        if selectedDate != nil {
                            // Bottom Options Container
                            VStack(alignment: .leading, spacing: 24) {
                                
                                // 3. Mark As Toggle
                                MarkAsToggleView(selection: $markAsSelection)
                                
                                // 4. Time Picker (Slide down if half day)
                                if markAsSelection == .halfDay {
                                    TimeRangePickerView(
                                        startTime: $startTime,
                                        endTime: $endTime
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
            
            // 6. Success Toast
            if showToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                    Text("Availability updated")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.green)
                .clipShape(Capsule())
                .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
            loadUnavailability()
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
                
                for entry in entries {
                    guard let date = dateFormatter.date(from: entry.date) else { continue }
                    let startOfDay = calendar.startOfDay(for: date)
                    
                    switch entry.type {
                    case "unavailable":
                        newMap[startOfDay] = .unavailable
                    case "halfDay":
                        newMap[startOfDay] = .halfDay
                    default:
                        break
                    }
                    newIDs[startOfDay] = entry.id
                }
                
                withAnimation {
                    availabilityMap = newMap
                    unavailabilityIDs = newIDs
                }
                
                // Sync toggle for currently selected date
                if let selected = selectedDate {
                    let startOfDay = calendar.startOfDay(for: selected)
                    markAsSelection = availabilityMap[startOfDay] ?? .available
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
                        createdAt: Date()
                    )
                    try await AuthManager.shared.saveUnavailability(entry)
                    withAnimation {
                        availabilityMap[startOfDay] = .unavailable
                        unavailabilityIDs[startOfDay] = entryId
                    }
                    
                case .halfDay:
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "HH:mm"
                    let entryId = unavailabilityIDs[startOfDay] ?? UUID().uuidString
                    let entry = DoctorUnavailability(
                        id: entryId,
                        doctorId: doctorId,
                        date: dateString,
                        type: "halfDay",
                        startTime: timeFormatter.string(from: startTime),
                        endTime: timeFormatter.string(from: endTime),
                        createdAt: Date()
                    )
                    try await AuthManager.shared.saveUnavailability(entry)
                    withAnimation {
                        availabilityMap[startOfDay] = .halfDay
                        unavailabilityIDs[startOfDay] = entryId
                    }
                }
                
                // Show success toast
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showToast = true
                }
                // Sync original so Save button hides
                originalSelection = markAsSelection
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { showToast = false }
                }
            } catch {
                withAnimation { errorMessage = error.localizedDescription }
            }
            isSaving = false
        }
    }
}

#Preview {
    DoctorAvailabilityView()
}
