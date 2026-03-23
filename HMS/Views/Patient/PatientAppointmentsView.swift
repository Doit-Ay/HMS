import SwiftUI
import FirebaseFirestore

// MARK: - Patient Appointments View
struct PatientAppointmentsView: View {
    var cameFromBooking: Bool = false
    @ObservedObject var session = UserSession.shared
    @State private var appointments: [Appointment] = []
    @State private var isLoading = true
    @State private var selectedTab = 0 // 0 = Upcoming, 1 = Past
    @State private var appointmentToCancel: Appointment? = nil
    @State private var showCancelAlert = false
    @State private var isCancelling = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false
    // Reschedule navigation state
    @State private var rescheduleDoctor: HMSUser? = nil
    @State private var rescheduleAppointment: Appointment? = nil
    @State private var isFetchingDoctor = false
    
    // Rating state
    @State private var appointmentToRate: Appointment? = nil
    
    @Environment(\.dismiss) private var dismiss

    private var upcomingAppointments: [Appointment] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let nowStr = formatter.string(from: Date())
        return appointments
            .filter { $0.status == "scheduled" && "\($0.date) \($0.endTime)" >= nowStr }
            .sorted { if $0.date != $1.date { return $0.date < $1.date }; return $0.startTime < $1.startTime }
    }

    private var pastAppointments: [Appointment] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let nowStr = formatter.string(from: Date())
        return appointments
            .filter { $0.status != "scheduled" || "\($0.date) \($0.endTime)" < nowStr }
            .sorted { if $0.date != $1.date { return $0.date > $1.date }; return $0.startTime > $1.startTime }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()
            
            // Hidden NavigationLink — triggered programmatically when doctor is fetched
            if let doctor = rescheduleDoctor, let appt = rescheduleAppointment {
                NavigationLink(
                    destination: BookAppointmentView(
                        doctor: doctor,
                        rescheduleAppointmentId: appt.id,
                        rescheduleOldSlotId: appt.slotId,
                        rescheduleDate: appt.date
                    ),
                    isActive: Binding(
                        get: { rescheduleDoctor != nil },
                        set: { if !$0 { rescheduleDoctor = nil; rescheduleAppointment = nil } }
                    )
                ) { EmptyView() }
                .hidden()
            }

            VStack(spacing: 0) {
                // Segmented Picker
                Picker("", selection: $selectedTab) {
                    Text("Upcoming").tag(0)
                    Text("Past").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(AppTheme.primary)
                    Spacer()
                } else {
                    let list = selectedTab == 0 ? upcomingAppointments : pastAppointments

                    if list.isEmpty {
                        Spacer()
                        VStack(spacing: 14) {
                            Image(systemName: selectedTab == 0 ? "calendar.badge.clock" : "calendar.badge.minus")
                                .font(.system(size: 44))
                                .foregroundColor(AppTheme.textSecondary.opacity(0.35))
                            Text(selectedTab == 0 ? "No upcoming appointments" : "No past appointments")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 16) {
                                ForEach(list) { appointment in
                                    AppointmentDetailCard(
                                        appointment: appointment,
                                        isUpcoming: selectedTab == 0,
                                        onCancel: {
                                            appointmentToCancel = appointment
                                            showCancelAlert = true
                                        },
                                        onReschedule: {
                                            Task { await fetchDoctorForReschedule(appointment) }
                                        },
                                        onRate: {
                                            appointmentToRate = appointment
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }

            // Toast
            if showToast {
                HStack(spacing: 8) {
                    Image(systemName: toastIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(.white)
                    Text(toastMessage)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(toastIsError ? Color.red.opacity(0.9) : Color.green.opacity(0.9))
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
                .padding(.bottom, 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("My Appointments")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(cameFromBooking)
        .toolbar {
            if cameFromBooking {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        // Pop all the way back to home
                        // Dismiss this view + the BookAppointmentView below it
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            // The BookAppointmentView will also dismiss, returning to home
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Home")
                                .font(.system(size: 17))
                        }
                        .foregroundColor(AppTheme.primary)
                    }
                }
            }
        }
        .alert("Cancel Appointment?", isPresented: $showCancelAlert, presenting: appointmentToCancel) { appt in
            Button("Keep It", role: .cancel) {}
            Button("Cancel Appointment", role: .destructive) {
                Task { await cancelAppointment(appt) }
            }
        } message: { appt in
            Text("Are you sure you want to cancel your appointment with \(appt.doctorName) on \(formatDate(appt.date)) at \(appt.startTime)?")
        }
        .sheet(item: $appointmentToRate) { appt in
            DoctorRatingSheet(appointment: appt) { rating, review in
                Task { await submitRating(appt, rating: rating, review: review) }
            }
        }
        .task { await fetchAppointments() }
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Fetch
    private func fetchAppointments() async {
        guard let userId = session.currentUser?.id else {
            await MainActor.run { isLoading = false }
            return
        }
        let db = Firestore.firestore()
        do {
            let snapshot = try await db.collection("appointments")
                .whereField("patientId", isEqualTo: userId)
                .getDocuments()

            let fetched = snapshot.documents.compactMap { doc -> Appointment? in
                let d = doc.data()
                return Appointment(
                    id: doc.documentID,
                    slotId: d["slotId"] as? String ?? "",
                    doctorId: d["doctorId"] as? String ?? "",
                    doctorName: d["doctorName"] as? String ?? "",
                    patientId: d["patientId"] as? String ?? "",
                    patientName: d["patientName"] as? String ?? "",
                    department: d["department"] as? String,
                    date: d["date"] as? String ?? "",
                    startTime: d["startTime"] as? String ?? "",
                    endTime: d["endTime"] as? String ?? "",
                    status: d["status"] as? String ?? ""
                )
            }
            await MainActor.run {
                self.appointments = fetched
                withAnimation { self.isLoading = false }
            }
        } catch {
            print("Error fetching appointments: \(error)")
            await MainActor.run { withAnimation { self.isLoading = false } }
        }
    }

    // MARK: - Cancel
    private func cancelAppointment(_ appointment: Appointment) async {
        let db = Firestore.firestore()
        do {
            // Update appointment status to cancelled
            try await db.collection("appointments")
                .document(appointment.id)
                .updateData(["status": "cancelled"])

            // Free up the slot back to "available"
            if !appointment.slotId.isEmpty {
                try await db.collection("doctor_slots")
                    .document(appointment.slotId)
                    .updateData(["status": "available"])
            }

            await MainActor.run {
                if let idx = appointments.firstIndex(where: { $0.id == appointment.id }) {
                    appointments[idx].status = "cancelled"
                }
                triggerToast("Appointment cancelled successfully", isError: false)
            }
        } catch {
            print("Cancel error: \(error)")
            await MainActor.run {
                triggerToast("Failed to cancel. Please try again.", isError: true)
            }
        }
    }

    // MARK: - Submit Rating
    private func submitRating(_ appointment: Appointment, rating: Int, review: String) async {
        do {
            try await AuthManager.shared.submitDoctorReview(
                appointmentId: appointment.id,
                doctorId: appointment.doctorId,
                rating: rating,
                review: review
            )
            await MainActor.run {
                if let idx = appointments.firstIndex(where: { $0.id == appointment.id }) {
                    appointments[idx].ratingGiven = rating
                    appointments[idx].reviewText = review.isEmpty ? nil : review
                }
                triggerToast("Rating submitted successfully!", isError: false)
                appointmentToRate = nil
            }
        } catch {
            print("Submit rating error: \(error)")
            await MainActor.run {
                triggerToast("Failed to submit rating. Please try again.", isError: true)
            }
        }
    }

    private func triggerToast(_ message: String, isError: Bool) {
        toastMessage = message
        toastIsError = isError
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showToast = false }
        }
    }

    // MARK: - Fetch Doctor for Reschedule
    private func fetchDoctorForReschedule(_ appointment: Appointment) async {
        guard !isFetchingDoctor else { return }
        await MainActor.run { isFetchingDoctor = true }
        do {
            let doctor = try await AuthManager.shared.fetchDoctor(id: appointment.doctorId)
            await MainActor.run {
                rescheduleAppointment = appointment
                rescheduleDoctor = doctor
                isFetchingDoctor = false
            }
        } catch {
            print("Error fetching doctor for reschedule: \(error)")
            await MainActor.run {
                isFetchingDoctor = false
                triggerToast("Could not load doctor info. Please try again.", isError: true)
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let inFmt = DateFormatter(); inFmt.dateFormat = "yyyy-MM-dd"
        guard let date = inFmt.date(from: dateString) else { return dateString }
        let outFmt = DateFormatter(); outFmt.dateFormat = "MMM d, yyyy"
        return outFmt.string(from: date)
    }
}

// MARK: - Appointment Detail Card
struct AppointmentDetailCard: View {
    let appointment: Appointment
    let isUpcoming: Bool
    let onCancel: () -> Void
    let onReschedule: () -> Void
    let onRate: () -> Void

    /// For past appointments that still have "scheduled" status, show "missed"
    private var displayStatus: String {
        if !isUpcoming && appointment.status == "scheduled" {
            return "missed"
        }
        return appointment.status
    }

    private var statusColor: Color {
        switch displayStatus {
        case "scheduled": return AppTheme.primary
        case "completed": return .green
        case "cancelled": return .red
        case "missed": return .orange
        default: return AppTheme.textSecondary
        }
    }

    private var statusIcon: String {
        switch displayStatus {
        case "scheduled": return "clock.fill"
        case "completed": return "checkmark.circle.fill"
        case "cancelled": return "xmark.circle.fill"
        case "missed": return "exclamationmark.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header row
            HStack(spacing: 14) {
                Circle()
                    .fill(AppTheme.primaryLight.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "stethoscope")
                            .foregroundColor(AppTheme.primaryDark)
                            .font(.system(size: 20))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(appointment.doctorName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(appointment.department ?? "General")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                // Status badge
                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 11))
                    Text(displayStatus.capitalized)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())
            }
            .padding(16)

            Divider()
                .padding(.horizontal, 16)

            // Date & time
            HStack(spacing: 20) {
                Label {
                    Text(formatDate(appointment.date))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundColor(AppTheme.primary)
                }

                Label {
                    Text("\(appointment.startTime) – \(appointment.endTime)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                } icon: {
                    Image(systemName: "clock.fill")
                        .foregroundColor(AppTheme.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Action buttons — only for scheduled upcoming appointments
            if isUpcoming && appointment.status == "scheduled" {
                Divider()
                    .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    // Reschedule
                    Button(action: onReschedule) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Reschedule")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(AppTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(AppTheme.primaryLight.opacity(0.25))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    // Cancel
                    Button(action: onCancel) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Cancel")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.red.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            } else if !isUpcoming && appointment.status == "completed" && appointment.ratingGiven == nil {
                Divider()
                    .padding(.horizontal, 16)

                Button(action: onRate) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Rate Doctor")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(AppTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(AppTheme.primaryLight.opacity(0.25))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            } else if let rating = appointment.ratingGiven {
                Divider()
                    .padding(.horizontal, 16)

                HStack(spacing: 4) {
                    Text("Your Rating:")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(star <= rating ? .orange : AppTheme.textSecondary.opacity(0.3))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .background(AppTheme.cardSurface)
        .cornerRadius(20)
        .shadow(color: AppTheme.textSecondary.opacity(0.08), radius: 12, x: 0, y: 5)
    }


    private func formatDate(_ dateString: String) -> String {
        let inFmt = DateFormatter(); inFmt.dateFormat = "yyyy-MM-dd"
        guard let date = inFmt.date(from: dateString) else { return dateString }
        let outFmt = DateFormatter(); outFmt.dateFormat = "MMM d, yyyy"
        return outFmt.string(from: date)
    }
}

#Preview {
    NavigationStack {
        PatientAppointmentsView()
    }
}

// MARK: - Doctor Rating Sheet
struct DoctorRatingSheet: View {
    @Environment(\.dismiss) var dismiss
    let appointment: Appointment
    let onSubmit: (Int, String) -> Void
    
    @State private var rating: Int = 0
    @State private var reviewText: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                
                // Doctor Info
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 50))
                        .foregroundColor(AppTheme.primary)
                        .padding(.top, 20)
                    
                    Text("How was your consultation with")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Text(appointment.doctorName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                // Rating Stars
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: "star.fill")
                            .font(.system(size: 40))
                            .foregroundColor(star <= rating ? .orange : AppTheme.textSecondary.opacity(0.3))
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    rating = star
                                }
                            }
                    }
                }
                .padding(.vertical, 10)
                
                // Review Text
                if rating > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Write a Review (Optional)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.leading, 4)
                        
                        TextField("Share your experience...", text: $reviewText, axis: .vertical)
                            .lineLimit(4...8)
                            .padding(14)
                            .background(AppTheme.background)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                Spacer()
                
                // Submit Button
                Button {
                    onSubmit(rating, reviewText)
                    dismiss()
                } label: {
                    Text("Submit Review")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(rating > 0 ? AppTheme.primary : AppTheme.textSecondary.opacity(0.5))
                        .cornerRadius(16)
                        .shadow(color: rating > 0 ? AppTheme.primary.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
                }
                .disabled(rating == 0)
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 24)
            .background(AppTheme.cardSurface.ignoresSafeArea())
            .navigationTitle("Rate Doctor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }
}
