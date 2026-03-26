import SwiftUI

struct AppointmentDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    let appointment: AppointmentBlock
    
    // Dynamic patient data from Firestore
    @State private var patient: PatientProfile?
    @State private var isLoading = true
    @State private var showConsultationNotes = false
    @State private var showReferLabTest = false
    @State private var appointmentStatus: String = "scheduled"
    @State private var isLoadingStatus = true
    @State private var isUpdatingStatus = false
    @State private var firestoreAppointment: Appointment?
    @State private var hasExistingNotes = false
    
    /// Best available patient name — prefers live-fetched name, falls back to appointment record
    private var displayName: String {
        if let name = patient?.fullName, !name.isEmpty, name != "Unknown" {
            return name
        }
        return appointment.patientName.isEmpty ? "Patient" : appointment.patientName
    }
    
    // Computed helpers
    private var ageString: String {
        // First check the direct age field (saved as Int by PatientProfileView)
        if let age = patient?.age, age > 0 {
            return "\(age)"
        }
        // Fallback: try computing from dateOfBirth
        guard let dobString = patient?.dateOfBirth, !dobString.isEmpty, dobString != "Not Set" else {
            return "—"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let dobDate = formatter.date(from: dobString) {
            let years = Calendar.current.dateComponents([.year], from: dobDate, to: Date()).year ?? 0
            return "\(years)"
        }
        return "—"
    }
    
    private func safeValue(_ val: String?, fallback: String = "—") -> String {
        let v = (val ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if v.isEmpty || v == "Not Set" { return fallback }
        return v
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Grabber pill
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
            
            if isLoading {
                // Skeleton / loading state
                VStack(spacing: 16) {
                    Circle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 80, height: 80)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 160, height: 24)
                    HStack(spacing: 16) {
                        ForEach(0..<4) { _ in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 50)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 20)
                Spacer()
            } else {
                // Header: Avatar & Name
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(appointment.color.opacity(0.4))
                            .frame(width: 80, height: 80)
                        Text(String(displayName.prefix(1)))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    
                    Text(displayName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    // Status badge
                    Text(appointmentStatus.capitalized)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(appointmentStatus == "completed" ? .green : .orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            (appointmentStatus == "completed" ? Color.green : Color.orange)
                                .opacity(0.1)
                        )
                        .cornerRadius(8)
                }
                
                // Info Pills Row — DYNAMIC from patients table
                HStack(spacing: 16) {
                    InfoPill(title: "Age", value: ageString)
                    InfoPill(title: "Blood", value: safeValue(patient?.bloodGroup))
                    InfoPill(title: "Height", value: safeValue(patient?.height))
                    InfoPill(title: "Weight", value: safeValue(patient?.weight))
                }
                .padding(.horizontal, 24)
                
                // Details List
                VStack(spacing: 16) {
                    DetailRow(icon: "clock", title: "Time", value: "\(timeString(appointment.startTime)) - \(timeString(appointment.endTime))")
                    DetailRow(icon: "stethoscope", title: "Type", value: appointment.type)
                    
                    // Tags — DYNAMIC from patients table
                    let allTags = (patient?.medicalHistory ?? []) + (patient?.allergies ?? [])
                    if !allTags.isEmpty {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundColor(AppTheme.textSecondary)
                                .frame(width: 24)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(allTags, id: \.self) { tag in
                                        TagView(text: tag)
                                    }
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Action Buttons — context-sensitive (hidden while loading status)
                VStack(spacing: 12) {
                  if isLoadingStatus {
                        // Show a subtle loading indicator while fetching appointment status
                        ProgressView()
                            .tint(AppTheme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                  } else {
                    if appointmentStatus == "scheduled" {
                        if Date() >= appointment.startTime {
                            // Before consultation: show "Start Consultation" which marks it as completed
                            Button(action: markConsultationDone) {
                                HStack {
                                    if isUpdatingStatus {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Mark Consultation Done")
                                    }
                                }
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.primary)
                                .cornerRadius(16)
                                .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(isUpdatingStatus)
                        } else {
                            // Future appointment
                            HStack {
                                Image(systemName: "clock.fill")
                                Text("Consultation Pending")
                            }
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(16)
                        }
                    }
                    
                    if appointmentStatus == "completed" {
                        // After consultation: show "Edit" if notes exist, otherwise "Write"
                        Button(action: {
                            guard firestoreAppointment != nil else { return }
                            showConsultationNotes = true
                        }) {
                            HStack {
                                Image(systemName: hasExistingNotes ? "pencil.line" : "pencil.and.list.clipboard")
                                Text(hasExistingNotes ? "Edit Prescription" : "Write Prescription")
                            }
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.primary)
                            .cornerRadius(16)
                            .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        
                        // New Refer Lab Test Button
                        Button(action: { showReferLabTest = true }) {
                            HStack {
                                Image(systemName: "flask.fill")
                                Text("Refer Lab Test")
                            }
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.primaryLight)
                            .cornerRadius(16)
                        }
                    }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showConsultationNotes, onDismiss: {
            Task { await checkExistingNotes() }
        }) {
            if let currentUser = UserSession.shared.currentUser,
               let appt = firestoreAppointment {
                ConsultationNotesView(
                    appointmentId: appt.id,
                    doctorId: currentUser.id,
                    doctorName: appt.doctorName,
                    patientId: appt.patientId,
                    patientName: displayName,
                    appointmentDate: appt.date,
                    startTime: appt.startTime,
                    endTime: appt.endTime
                )
            } else {
                VStack {
                    Text("Unable to load appointment data.")
                        .foregroundColor(AppTheme.textSecondary)
                    Button("Dismiss") { showConsultationNotes = false }
                        .padding(.top, 8)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showReferLabTest) {
            if let currentUser = UserSession.shared.currentUser,
               let appt = firestoreAppointment {
                ReferLabTestView(
                    doctorId: currentUser.id,
                    doctorName: appt.doctorName,
                    patientId: appt.patientId,
                    patientName: displayName
                )
            }
        }
        .background(AppTheme.sheetBackground.ignoresSafeArea())
        .task {
            await fetchPatientData()
            await fetchAppointmentStatus()
        }
    }
    
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    // Fetch real patient data from Firestore patients table
    private func fetchPatientData() async {
        do {
            let profile = try await DoctorPatientRepository.shared.fetchPatientProfile(patientId: appointment.patientId)
            withAnimation(.easeOut(duration: 0.3)) {
                self.patient = profile
                self.isLoading = false
            }
        } catch {
            print("⚠️ Could not fetch patient profile: \(error.localizedDescription)")
            // Still dismiss loading — show what we have from the appointment
            withAnimation {
                self.isLoading = false
            }
        }
    }
    
    // Fetch live appointment status from Firestore
    private func fetchAppointmentStatus() async {
        do {
            if let appt = try await AuthManager.shared.fetchAppointment(appointmentId: appointment.id) {
                self.firestoreAppointment = appt
                self.appointmentStatus = appt.status
                // Check for existing notes before showing buttons
                await checkExistingNotes()
                withAnimation { self.isLoadingStatus = false }
            } else {
                withAnimation { self.isLoadingStatus = false }
            }
        } catch {
            print("⚠️ Could not fetch appointment status: \(error.localizedDescription)")
            withAnimation { self.isLoadingStatus = false }
        }
    }
    
    // Mark consultation as done
    private func markConsultationDone() {
        Task {
            isUpdatingStatus = true
            do {
                try await AuthManager.shared.updateAppointmentStatus(appointmentId: appointment.id, status: "completed")
                withAnimation {
                    appointmentStatus = "completed"
                    firestoreAppointment?.status = "completed"
                }
            } catch {
                print("⚠️ Failed to update appointment status: \(error.localizedDescription)")
            }
            isUpdatingStatus = false
        }
    }
    
    // Check if consultation notes already exist for this appointment
    private func checkExistingNotes() async {
        do {
            if let _ = try await DoctorPatientRepository.shared.fetchConsultationNote(appointmentId: appointment.id) {
                await MainActor.run {
                    hasExistingNotes = true
                }
            }
        } catch {
            print("⚠️ Could not check existing notes: \(error.localizedDescription)")
        }
    }
}


struct InfoPill: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}

struct TagView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(Color.red.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
    }
}

#Preview {
    let appt = AppointmentBlock(patientId: "patient_1", type: "Consultation", startTime: Date(), endTime: Date().addingTimeInterval(3600), patientName: "Oliver Smith", color: AppTheme.primaryLight, additionalStaffCount: 2)
    AppointmentDetailSheet(appointment: appt)
}
