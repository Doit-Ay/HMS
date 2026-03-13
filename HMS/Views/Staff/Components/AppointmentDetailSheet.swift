import SwiftUI

struct AppointmentDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    let appointment: AppointmentBlock
    
    // Dynamic patient data from Firestore
    @State private var patient: PatientProfile?
    @State private var isLoading = true
    
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
                        Text(String(appointment.patientName.prefix(1)))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    
                    Text(patient?.fullName ?? appointment.patientName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
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
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        Text("Start Consultation")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.primary)
                            .cornerRadius(16)
                            .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    Button(action: { dismiss() }) {
                        Text("Write Prescription")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.primaryLight)
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .task {
            await fetchPatientData()
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
