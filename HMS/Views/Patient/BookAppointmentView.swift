import SwiftUI
import FirebaseFirestore
import Combine

// MARK: - Real-Time Slot Listener
/// Listens to Firestore changes on doctor_slots and doctor_unavailability
/// so the patient booking screen updates instantly when a doctor changes availability.
class SlotListenerManager: ObservableObject {
    @Published var lastUpdate = Date()
    private var slotListener: ListenerRegistration?
    private var unavailListener: ListenerRegistration?
    private let db = Firestore.firestore()
    
    /// Called whenever slots or unavailability change
    var onSlotsChanged: (() -> Void)?
    
    func startListening(doctorId: String, date: String, month: String) {
        stopListening()
        
        // Listen to slot changes for this doctor + date
        slotListener = db.collection("doctor_slots")
            .whereField("doctorId", isEqualTo: doctorId)
            .whereField("date", isEqualTo: date)
            .addSnapshotListener { [weak self] _, _ in
                self?.onSlotsChanged?()
            }
        
        // Listen to unavailability changes for this doctor
        unavailListener = db.collection("doctor_unavailability")
            .whereField("doctorId", isEqualTo: doctorId)
            .addSnapshotListener { [weak self] _, _ in
                self?.onSlotsChanged?()
            }
    }
    
    func stopListening() {
        slotListener?.remove()
        unavailListener?.remove()
        slotListener = nil
        unavailListener = nil
    }
    
    deinit {
        stopListening()
    }
}

// MARK: - Book Appointment View (Patient Booking Flow — Step 2)
struct BookAppointmentView: View {
    let doctor: HMSUser
    @ObservedObject var session = UserSession.shared
    @StateObject private var slotListener = SlotListenerManager()
    @Environment(\.dismiss) var dismiss
    
    var consultationFee: Int {
        if let fee = doctor.consultationFee {
            return Int(fee)
        }
        return 499
    }
    
    /// When set, the view operates in "reschedule" mode — updating an existing appointment
    var rescheduleAppointmentId: String? = nil
    var rescheduleOldSlotId: String? = nil
    var rescheduleDate: String? = nil
    
    // Calendar State
    @State private var selectedDate: Date? = Date()
    @State private var availabilityMap: [Date: DayAvailabilityState] = [:]
    
    // Slot State
    @State private var timeSlots: [(start: String, end: String, isBooked: Bool)] = []
    @State private var selectedSlot: (start: String, end: String)? = nil
    
    // Unavailability data
    @State private var unavailabilityEntries: [DoctorUnavailability] = []
    
    // UI State
    @State private var isLoadingSlots = false
    @State private var isBooking = false
    @State private var showSuccess = false
    @State private var errorMessage: String? = nil
    @State private var animate = false
    @State private var showAppointmentsAfterBooking = false

    // Payment State
    @State private var showPaymentSheet = false
    @State private var pendingPaymentOptions: RazorpayOptions? = nil
    
    private var isRescheduleMode: Bool { rescheduleAppointmentId != nil }
    
    private let calendar = Calendar.current
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
    
    private var selectedDateString: String? {
        guard let date = selectedDate else { return nil }
        return dateFormatter.string(from: date)
    }
    
    private var visibleMonthString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: selectedDate ?? Date())
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    // Doctor info card
                    DoctorInfoHeader(doctor: doctor)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .offset(y: animate ? 0 : -15)
                        .opacity(animate ? 1 : 0)
                    
                    // Calendar
                    AvailabilityCalendarView(
                        selectedDate: $selectedDate,
                        availabilityMap: availabilityMap
                    )
                    .padding(.horizontal, 20)
                    .onChange(of: selectedDate) { _ in
                        loadSlotsForSelectedDate()
                        startSlotListener()
                    }
                    .offset(y: animate ? 0 : 15)
                    .opacity(animate ? 1 : 0)
                    
                    // Slot section
                    if let dateStr = selectedDateString {
                        VStack(alignment: .leading, spacing: 16) {
                            // Section header
                            HStack {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.primary)
                                Text("Available Slots")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                
                                // Date badge
                                Text(formattedDate(dateStr))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(AppTheme.primary.opacity(0.08))
                                    .cornerRadius(8)
                            }
                            
                            if isLoadingSlots {
                                HStack {
                                    Spacer()
                                    ProgressView("Loading slots...")
                                        .tint(AppTheme.primary)
                                    Spacer()
                                }
                                .padding(.vertical, 30)
                            } else if timeSlots.isEmpty {
                                // No slots / unavailable day
                                VStack(spacing: 12) {
                                    Image(systemName: "moon.zzz.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(AppTheme.textSecondary.opacity(0.3))
                                    Text("Doctor is not available on this day")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                            } else {
                                // Slot grid
                                SlotGridView(
                                    slots: timeSlots,
                                    selectedSlot: $selectedSlot
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, selectedSlot != nil ? 100 : 30)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.bottom, 20)
            }
            
            // Bottom booking bar
            if selectedSlot != nil {
                VStack(spacing: 6) {
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.red)
                    }
                    
                    Button(action: { isRescheduleMode ? rescheduleSelectedSlot() : bookSelectedSlot() }) {
                        HStack(spacing: 10) {
                            if isBooking {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            } else {
                                Image(systemName: isRescheduleMode ? "arrow.triangle.2.circlepath.circle.fill" : "checkmark.circle.fill")
                                    .font(.system(size: 18))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isBooking ? (isRescheduleMode ? "Rescheduling..." : "Booking...") : (isRescheduleMode ? "Confirm Reschedule" : "Confirm Booking"))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                if let slot = selectedSlot {
                                    Text("\(slot.start) – \(slot.end)")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .opacity(0.9)
                                }
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.primary, AppTheme.primaryMid],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .cornerRadius(18)
                        .shadow(color: AppTheme.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .disabled(isBooking)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .background(
                    LinearGradient(
                        colors: [AppTheme.background.opacity(0), AppTheme.background],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(isRescheduleMode ? "Reschedule Appointment" : "Book Appointment")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // If rescheduling, open on the appointment's original date
            if let dateStr = rescheduleDate {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                if let date = f.date(from: dateStr) {
                    selectedDate = date
                }
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animate = true
            }
            loadUnavailability()
            loadSlotsForSelectedDate()
            startSlotListener()
        }
        .onDisappear {
            slotListener.stopListening()
        }
        .refreshable { loadSlotsForSelectedDate() }
        // Hidden NavigationLink to push Appointments after booking
        .background(
            NavigationLink(
                destination: PatientAppointmentsView(cameFromBooking: true),
                isActive: $showAppointmentsAfterBooking
            ) { EmptyView() }
        )
        // When user taps back from Appointments, also pop this view
        .onChange(of: showAppointmentsAfterBooking) { isActive in
            if !isActive && showSuccess == false {
                // User came back from appointments screen, pop to home
                dismiss()
            }
        }
        .sheet(isPresented: $showSuccess) {
            BookingSuccessSheet(
                doctorName: doctor.fullName,
                date: selectedDateString ?? "",
                time: selectedSlot.map { "\($0.start) – \($0.end)" } ?? "",
                isReschedule: isRescheduleMode,
                onDismiss: {
                    showSuccess = false
                    if isRescheduleMode {
                        dismiss()
                    } else {
                        // Navigate to My Appointments
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showAppointmentsAfterBooking = true
                        }
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .toolbar(.hidden, for: .tabBar)
        // Razorpay payment sheet
        .razorpaySheet(
            isPresented: $showPaymentSheet,
            options: pendingPaymentOptions ?? RazorpayOptions(
                amountInPaise: consultationFee * 100, // Derived from consulting fee
                description: "Doctor Consultation",
                prefillName: UserSession.shared.currentUser?.fullName ?? "",
                prefillEmail: UserSession.shared.currentUser?.email ?? "",
                prefillContact: ""
            )
        ) { result in
            switch result {
            case .success:
                performBooking()
            case .failure(_, let desc):
                withAnimation {
                    errorMessage = desc.contains("cancel") || desc.lowercased().contains("cancel")
                        ? "Payment was cancelled."
                        : "Payment failed: \(desc)"
                }
                isBooking = false
            }
        }
    }
    
    // MARK: - Load Unavailability
    
    private func loadUnavailability() {
        Task {
            do {
                let entries = try await AuthManager.shared.fetchUnavailability(
                    doctorId: doctor.id,
                    month: visibleMonthString
                )
                unavailabilityEntries = entries
                
                // Build availability map for calendar
                var map: [Date: DayAvailabilityState] = [:]
                for entry in entries {
                    guard let date = dateFormatter.date(from: entry.date) else { continue }
                    let startOfDay = calendar.startOfDay(for: date)
                    switch entry.type {
                    case "unavailable": map[startOfDay] = .unavailable
                    case "halfDay": map[startOfDay] = .halfDay
                    default: break
                    }
                }
                withAnimation { availabilityMap = map }
            } catch {
                #if DEBUG
                print("⚠️ Error loading unavailability: \(error)")
                #endif
            }
        }
    }
    
    // MARK: - Real-Time Listener
    
    private func startSlotListener() {
        guard let dateStr = selectedDateString else { return }
        slotListener.onSlotsChanged = { [self] in
            // Invalidate cache so we get fresh data
            CacheManager.shared.invalidate(prefix: "slots_")
            CacheManager.shared.invalidate(prefix: "unavail_")
            loadUnavailability()
            loadSlotsForSelectedDate()
        }
        slotListener.startListening(
            doctorId: doctor.id,
            date: dateStr,
            month: visibleMonthString
        )
    }
    
    // MARK: - Load Slots for Selected Date
    
    private func loadSlotsForSelectedDate() {
        guard let dateStr = selectedDateString else { return }
        selectedSlot = nil
        isLoadingSlots = true
        
        Task {
            do {
                guard let defaults = doctor.defaultSlots, !defaults.isEmpty else {
                    timeSlots = []
                    isLoadingSlots = false
                    return
                }
                
                // Get unavailability for this date
                let unav = unavailabilityEntries.first(where: { $0.date == dateStr })
                
                // Get already booked slots
                let bookedSlots = try await AuthManager.shared.fetchSlots(
                    doctorId: doctor.id, date: dateStr
                )
                
                // Generate 30-min slots
                let slots = AuthManager.shared.generate30MinSlots(
                    from: defaults,
                    unavailability: unav,
                    bookedSlots: bookedSlots
                )
                
                // Filter out past slots if date is today
                let today = dateFormatter.string(from: Date())
                if dateStr == today {
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "HH:mm"
                    let nowString = timeFormatter.string(from: Date())
                    withAnimation { timeSlots = slots.filter { $0.start > nowString } }
                } else {
                    withAnimation { timeSlots = slots }
                }
            } catch {
                #if DEBUG
                print("⚠️ Error loading slots: \(error)")
                #endif
                withAnimation { timeSlots = [] }
            }
            isLoadingSlots = false
        }
    }
    
    // MARK: - Reschedule Appointment
    
    private func rescheduleSelectedSlot() {
        guard let slot = selectedSlot,
              let dateStr = selectedDateString,
              let patient = session.currentUser,
              let appointmentId = rescheduleAppointmentId else { return }
        
        isBooking = true
        errorMessage = nil
        
        let newSlotId = UUID().uuidString
        let db = Firestore.firestore()
        
        Task {
            do {
                // 1. Free up old slot
                if let oldSlotId = rescheduleOldSlotId, !oldSlotId.isEmpty {
                    try await db.collection("doctor_slots")
                        .document(oldSlotId)
                        .updateData(["status": "available"])
                }
                
                // 2. Update existing appointment with new date/time/slot
                try await db.collection("appointments")
                    .document(appointmentId)
                    .updateData([
                        "date": dateStr,
                        "startTime": slot.start,
                        "endTime": slot.end,
                        "slotId": newSlotId,
                        "status": "scheduled"
                    ])
                
                // 3. Create new booked slot
                let newSlot = DoctorSlot(
                    id: newSlotId,
                    doctorId: doctor.id,
                    doctorName: doctor.fullName,
                    department: doctor.department,
                    date: dateStr,
                    startTime: slot.start,
                    endTime: slot.end,
                    status: .booked,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                let slotData = try Firestore.Encoder().encode(newSlot)
                try await db.collection("doctor_slots").document(newSlotId).setData(slotData)
                
                await MainActor.run {
                    withAnimation { showSuccess = true }
                }
            } catch {
                await MainActor.run {
                    withAnimation { errorMessage = "Reschedule failed. Please try again." }
                }
                #if DEBUG
                print("⚠️ Reschedule error: \(error)")
                #endif
            }
            await MainActor.run { isBooking = false }
        }
    }
    
    // MARK: - Book Appointment

    /// Step 1: Validate inputs and open Razorpay payment sheet
    private func bookSelectedSlot() {
        guard selectedSlot != nil,
              selectedDateString != nil,
              let patient = session.currentUser else { return }

        isBooking = true
        errorMessage = nil

        // Build payment options
        let options = RazorpayOptions(
            amountInPaise: consultationFee * 100,
            description: "Dr. \(doctor.fullName) Consultation",
            prefillName: patient.fullName,
            prefillEmail: patient.email,
            prefillContact: patient.phoneNumber ?? ""
        )
        pendingPaymentOptions = options
        showPaymentSheet = true
    }

    /// Step 2: Called after successful payment — actually writes to Firestore
    private func performBooking() {
        guard let slot = selectedSlot,
              let dateStr = selectedDateString,
              let patient = session.currentUser else { return }

        let appointment = Appointment(
            id: UUID().uuidString,
            slotId: UUID().uuidString,
            doctorId: doctor.id,
            doctorName: doctor.fullName,
            patientId: patient.id,
            patientName: patient.fullName,
            department: doctor.department,
            date: dateStr,
            startTime: slot.start,
            endTime: slot.end,
            status: "scheduled",
            createdAt: Date()
        )

        Task {
            do {
                try await AuthManager.shared.bookAppointment(appointment)
                withAnimation { showSuccess = true }
            } catch {
                withAnimation { errorMessage = "Booking failed. Please try again." }
                #if DEBUG
                print("⚠️ Booking error: \(error)")
                #endif
            }
            isBooking = false
        }
    }
    
    private func formattedDate(_ dateStr: String) -> String {
        guard let date = dateFormatter.date(from: dateStr) else { return dateStr }
        let f = DateFormatter()
        f.dateFormat = "d MMM, EEE"
        return f.string(from: date)
    }
}

// MARK: - Doctor Info Header
struct DoctorInfoHeader: View {

    let doctor: HMSUser
    
    var consultationFee: Int {
        if let fee = doctor.consultationFee {
            return Int(fee)
        }
        return 499
    }

    var body: some View {

        HStack(spacing: 16) {

            // MARK: Doctor Image
            ZStack {

                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.primary.opacity(0.08))
                    .frame(width: 95, height: 105)

                if let url = doctor.profileImageURL,
                   let imageURL = URL(string: url) {

                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        doctorPlaceholderImage(for: doctor.gender)
                    }

                } else {
                    doctorPlaceholderImage(for: doctor.gender)
                }
            }
            .frame(width: 95, height: 105)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // MARK: Doctor Details
            VStack(alignment: .leading, spacing: 8) {

                // Rating
                HStack(spacing: 4) {

                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(doctor.reviewCount ?? 0 > 0 ? .orange : .gray)

                    Text(String(format: "%.1f", doctor.averageRating ?? 0.0))
                        .font(.system(size: 13, weight: .semibold))

                    Text("• \(doctor.reviewCount ?? 0) reviews")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }

                // Name
                Text("Dr. \(doctor.fullName)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                // Specialization
                if let spec = doctor.specialization {

                    Text(spec)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textSecondary)
                }

                // Experience + Fee Row
                HStack(spacing: 12) {

                    // Experience
                    HStack(spacing: 4) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 11))
                        Text("5 yrs exp")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(AppTheme.textSecondary)

                    // Consultation Fee
                    HStack(spacing: 4) {
                        Image(systemName: "indianrupeesign.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.primary)

                        Text("₹\(consultationFee)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.primary.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(AppTheme.cardSurface)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Slot Grid View
struct SlotGridView: View {
    let slots: [(start: String, end: String, isBooked: Bool)]
    @Binding var selectedSlot: (start: String, end: String)?
    
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                let isSelected = selectedSlot?.start == slot.start && selectedSlot?.end == slot.end
                
                Button(action: {
                    if !slot.isBooked {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSlot = (start: slot.start, end: slot.end)
                        }
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(slot.start)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        
                        Text("to \(slot.end)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .opacity(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Group {
                            if slot.isBooked {
                                Color.gray.opacity(0.08)
                            } else if isSelected {
                                LinearGradient(
                                    colors: [AppTheme.primary, AppTheme.primaryMid],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            } else {
                                AppTheme.cardSurface
                            }
                        }
                    )
                    .foregroundColor(
                        slot.isBooked ? AppTheme.textSecondary.opacity(0.4) :
                            isSelected ? .white : AppTheme.textPrimary
                    )
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                slot.isBooked ? Color.gray.opacity(0.1) :
                                    isSelected ? AppTheme.primary : AppTheme.textSecondary.opacity(0.12),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
                    .shadow(
                        color: isSelected ? AppTheme.primary.opacity(0.2) : Color.clear,
                        radius: 6, x: 0, y: 3
                    )
                    .scaleEffect(isSelected ? 1.04 : 1.0)
                }
                .disabled(slot.isBooked)
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Booking Success Sheet
struct BookingSuccessSheet: View {
    let doctorName: String
    let date: String
    let time: String
    var isReschedule: Bool = false
    let onDismiss: () -> Void
    
    @State private var animate = false
    
    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: date) else { return date }
        let display = DateFormatter()
        display.dateFormat = "EEEE, d MMMM yyyy"
        return display.string(from: d)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Success icon
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .scaleEffect(animate ? 1 : 0.5)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(AppTheme.primary)
                    .scaleEffect(animate ? 1 : 0)
            }
            
            Text(isReschedule ? "Appointment Rescheduled!" : "Appointment Booked!")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            
            // Details card
            VStack(spacing: 12) {
                DetailRow(icon: "stethoscope", title: "Doctor", value: "Dr. \(doctorName)")
                Divider()
                DetailRow(icon: "calendar", title: "Date", value: formattedDate)
                Divider()
                DetailRow(icon: "clock.fill", title: "Time", value: time)
            }
            .padding(20)
            .background(AppTheme.cardSurface)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 20)
            
            Spacer()
            
            Button(action: onDismiss) {
                Text(isReschedule ? "Done" : "View My Appointments")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.primary)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                animate = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        BookAppointmentView(
            doctor: HMSUser(id: "test", email: "doc@test.com", fullName: "John Smith", role: .doctor)
        )
    }
}
