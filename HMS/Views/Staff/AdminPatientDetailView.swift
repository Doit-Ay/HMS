import SwiftUI
import FirebaseFirestore

struct AdminPatientDetailView: View {
    let patientUser: HMSUser
    
    @State private var profile: PatientProfile?
    @State private var appointments: [Appointment] = []
    @State private var isLoading = true
    @State private var isLoadingAppointments = true
    @State private var animate = false

    private func safeValue(_ val: String?, fallback: String = "—") -> String {
        let v = (val ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if v.isEmpty || v == "Not Set" { return fallback }
        return v
    }

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
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            if isLoading {
                ProgressView("Loading Profile...")
                    .tint(AppTheme.primary)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Patient Header — Name, Email, Phone only
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.primary.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                Text(String(patientUser.fullName.prefix(1)))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.primary)
                            }
                            
                            VStack(spacing: 6) {
                                Text(patientUser.fullName)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.primary)
                                    Text(patientUser.email)
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                }

                                let phone = safeValue(profile?.phoneNumber)
                                if phone != "—" {
                                    HStack(spacing: 6) {
                                        Image(systemName: "phone.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.primary)
                                        Text(phone)
                                            .font(.system(size: 14, design: .rounded))
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 24)
                        .offset(y: animate ? 0 : 20)
                        .opacity(animate ? 1 : 0)
                        
                        // Upcoming Appointments
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.primary)
                                Text("Upcoming Appointments")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            .padding(.horizontal, 24)

                            if isLoadingAppointments {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .tint(AppTheme.primary)
                                        .padding(.vertical, 20)
                                    Spacer()
                                }
                            } else if upcomingAppointments.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: "calendar.badge.plus")
                                            .font(.system(size: 28))
                                            .foregroundColor(AppTheme.textSecondary.opacity(0.4))
                                        Text("No upcoming appointments")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                    .padding(.vertical, 20)
                                    Spacer()
                                }
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(upcomingAppointments) { appt in
                                        AdminAppointmentRow(appointment: appt, isUpcoming: true)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .offset(y: animate ? 0 : 20)
                        .opacity(animate ? 1 : 0)

                        // Past Appointments
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.textSecondary)
                                Text("Past Appointments")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            .padding(.horizontal, 24)

                            if isLoadingAppointments {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .tint(AppTheme.primary)
                                        .padding(.vertical, 20)
                                    Spacer()
                                }
                            } else if pastAppointments.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: "calendar.badge.minus")
                                            .font(.system(size: 28))
                                            .foregroundColor(AppTheme.textSecondary.opacity(0.4))
                                        Text("No past appointments")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                    .padding(.vertical, 20)
                                    Spacer()
                                }
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(pastAppointments) { appt in
                                        AdminAppointmentRow(appointment: appt, isUpcoming: false)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .offset(y: animate ? 0 : 20)
                        .opacity(animate ? 1 : 0)
                        
                        Spacer(minLength: 30)
                    }
                }
            }
        }
        .navigationTitle("Patient Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchPatientData()
            await fetchAppointments()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animate = true
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    private func fetchPatientData() async {
        do {
            let fetchedProfile = try await DoctorPatientRepository.shared.fetchPatientProfile(patientId: patientUser.id)
            withAnimation {
                self.profile = fetchedProfile
                self.isLoading = false
            }
        } catch {
            #if DEBUG
            print("Failed to fetch patient profile: \(error.localizedDescription)")
            #endif
            withAnimation {
                self.isLoading = false
            }
        }
    }

    private func fetchAppointments() async {
        let db = Firestore.firestore()
        do {
            let snapshot = try await db.collection("appointments")
                .whereField("patientId", isEqualTo: patientUser.id)
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
                withAnimation { self.isLoadingAppointments = false }
            }
        } catch {
            #if DEBUG
            print("Error fetching patient appointments: \(error)")
            #endif
            await MainActor.run { withAnimation { self.isLoadingAppointments = false } }
        }
    }
}

// MARK: - Admin Appointment Row
struct AdminAppointmentRow: View {
    let appointment: Appointment
    let isUpcoming: Bool

    private var displayStatus: String {
        if !isUpcoming && appointment.status == "scheduled" { return "missed" }
        return appointment.status
    }

    private var statusColor: Color {
        switch displayStatus {
        case "scheduled": return AppTheme.primary
        case "completed": return .green
        case "cancelled": return .red
        case "missed":    return .orange
        default: return AppTheme.textSecondary
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let inFmt = DateFormatter(); inFmt.dateFormat = "yyyy-MM-dd"
        guard let date = inFmt.date(from: dateString) else { return dateString }
        let outFmt = DateFormatter(); outFmt.dateFormat = "MMM d, yyyy"
        return outFmt.string(from: date)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "stethoscope")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Dr. \(appointment.doctorName)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 6) {
                    Text(formatDate(appointment.date))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    Text("·")
                        .foregroundColor(AppTheme.textSecondary)
                    Text("\(appointment.startTime) – \(appointment.endTime)")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            Text(displayStatus.capitalized)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(14)
        .background(AppTheme.cardSurface)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}


// MARK: - Reusable UI Components
struct AdminInfoPill: View {
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
        .background(AppTheme.cardSurface)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

struct AdminActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(AppTheme.textSecondary.opacity(0.4))
        }
        .padding(18)
        .background(AppTheme.cardSurface)
        .cornerRadius(22)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}
