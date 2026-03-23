import SwiftUI
import FirebaseFirestore

struct PatientHistoryView: View {
    @Environment(\.dismiss) var dismiss
    
    let patientGroup: PatientGroup
    
    @State private var appearAnimation = false
    @State private var selectedAppointment: Appointment?
    
    // For fetching real patient demographics
    @State private var patientProfile: PatientProfile?
    
    // Sort logic
    private var upcomingAppointments: [Appointment] {
        patientGroup.appointments
            .filter { $0.status.lowercased() == "scheduled" }
            .sorted { a1, a2 in
                if a1.date == a2.date { return a1.startTime < a2.startTime }
                return a1.date < a2.date
            }
    }
    
    private var pastAppointments: [Appointment] {
        patientGroup.appointments
            .filter { $0.status.lowercased() != "scheduled" }
            .sorted { a1, a2 in
                if a1.date == a2.date { return a1.startTime > a2.startTime }
                return a1.date > a2.date
            }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // MARK: - Hero Header
                ZStack {
                    // Gradient Background
                    LinearGradient(
                        colors: [AppTheme.dashboardCardGradientStart, AppTheme.dashboardCardGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Decorative circles removed format
                    
                    VStack(spacing: 14) {
                        Spacer().frame(height: 100)
                        
                        // Avatar with Ring & Badge
                        ZStack(alignment: .topTrailing) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.dashboardCardGradientStart, AppTheme.dashboardCardGradientEnd],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 94, height: 94)
                                
                                LivePatientAvatarInitial(
                                    patientId: patientGroup.patientId,
                                    fallbackName: patientGroup.patientName,
                                    font: .system(size: 36, weight: .bold, design: .rounded),
                                    weight: .bold,
                                    color: .white
                                )
                            }
                            .overlay(
                                Circle().stroke(AppTheme.cardSurface, lineWidth: 2.5)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                            
                            // Visit count badge
                            Text("\(patientGroup.visitCount)")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 26, height: 26)
                                .background(
                                    Circle()
                                        .fill(AppTheme.primaryDark)
                                        .overlay(Circle().stroke(AppTheme.cardSurface, lineWidth: 2))
                                )
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                .offset(x: 4, y: -4)
                        }
                        .scaleEffect(appearAnimation ? 1.0 : 0.85)
                        .animation(.spring(response: 0.5, dampingFraction: 0.65), value: appearAnimation)
                        
                        // Patient Name
                        LivePatientNameView(
                            patientId: patientGroup.patientId,
                            fallbackName: patientGroup.patientName,
                            font: .system(size: 24, weight: .bold, design: .rounded),
                            weight: .bold,
                            color: .white,
                            lineLimit: 1
                        )
                        
                        // Quick Stats
                        HStack(spacing: 10) {
                            QuickStatPill(icon: "drop.fill", title: patientProfile?.bloodGroup ?? "N/A", delay: 0.1)
                            QuickStatPill(icon: "calendar", title: patientProfile?.age != nil ? "\(patientProfile!.age!) yrs" : "N/A", delay: 0.2)
                            QuickStatPill(icon: "person.fill", title: patientProfile?.gender ?? "N/A", delay: 0.3)
                        }
                        .padding(.top, 2)
                        
                        Spacer().frame(height: 36)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // MARK: - Content Body (overlapping hero)
                VStack(alignment: .leading, spacing: 28) {
                    
                    // Upcoming Appointments
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Upcoming")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            if !upcomingAppointments.isEmpty {
                                Text("\(upcomingAppointments.count)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.primary.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        
                        if !upcomingAppointments.isEmpty {
                            CardBlock(borderColor: AppTheme.primary) {
                                VStack(spacing: 0) {
                                    ForEach(Array(upcomingAppointments.enumerated()), id: \.element.id) { index, appt in
                                        Button(action: { selectedAppointment = appt }) {
                                            AppointmentRow(appointment: appt, isUpcoming: true)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        if index < upcomingAppointments.count - 1 {
                                            Divider().padding(.leading, 16)
                                        }
                                    }
                                }
                            }
                        } else {
                            HStack(spacing: 14) {
                                Image(systemName: "calendar.badge.minus")
                                    .font(.system(size: 22))
                                    .foregroundColor(Color.gray.opacity(0.4))
                                Text("No upcoming appointments")
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                                Spacer()
                            }
                            .padding(16)
                            .background(AppTheme.cardSurface)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
                        }
                    }
                    
                    // Past Visits
                    if !pastAppointments.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Past Visits")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Text("\(pastAppointments.count)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            
                            CardBlock(borderColor: Color.gray.opacity(0.3)) {
                                VStack(spacing: 0) {
                                    ForEach(Array(pastAppointments.enumerated()), id: \.element.id) { index, appt in
                                        Button(action: { selectedAppointment = appt }) {
                                            AppointmentRow(appointment: appt, isUpcoming: false)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        if index < pastAppointments.count - 1 {
                                            Divider().padding(.leading, 16)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Medical Records
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Medical Records")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        
                        NavigationLink(destination: DoctorMedicalHistoryView(patientId: patientGroup.patientId, patientName: patientGroup.patientName)) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppTheme.primary.opacity(0.1))
                                        .frame(width: 46, height: 46)
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .font(.system(size: 18))
                                        .foregroundColor(AppTheme.primary)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("View Medical History")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("Uploaded records, prescriptions & reports")
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Color.gray.opacity(0.35))
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .padding(14)
                            .background(AppTheme.cardSurface)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        
                        NavigationLink(destination: DoctorLabReportsView(patientId: patientGroup.patientId, patientName: patientGroup.patientName)) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(red: 0.3, green: 0.6, blue: 0.7).opacity(0.1))
                                        .frame(width: 46, height: 46)
                                    Image(systemName: "flask.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color(red: 0.3, green: 0.6, blue: 0.7))
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Lab Reports")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("Completed lab test results & reports")
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Color.gray.opacity(0.35))
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .padding(14)
                            .background(AppTheme.cardSurface)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.background)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
                )
                .offset(y: -24)
                .offset(y: appearAnimation ? 0 : 40)
                .opacity(appearAnimation ? 1 : 0)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(AppTheme.background)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            if !appearAnimation {
                // Hero fades first
                withAnimation(.easeOut(duration: 0.3)) {
                    appearAnimation = true
                }
            }
            fetchProfile()
        }
        .sheet(item: $selectedAppointment) { appt in
            let block = AppointmentBlock(
                id: appt.id,
                patientId: appt.patientId,
                type: appt.department ?? "Consultation",
                startTime: Date(),
                endTime: Date(),
                patientName: appt.patientName,
                color: AppTheme.primaryLight,
                additionalStaffCount: 0
            )
            if #available(iOS 16.0, *) {
                AppointmentDetailSheet(appointment: block)
                    .presentationDetents([.fraction(0.65), .large])
                    .presentationDragIndicator(.hidden)
            } else {
                AppointmentDetailSheet(appointment: block)
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    // Fetch real demographic data
    private func fetchProfile() {
        Task {
            if let profile = try? await DoctorPatientRepository.shared.fetchPatientProfile(patientId: patientGroup.patientId) {
                await MainActor.run {
                    self.patientProfile = profile
                }
            }
        }
    }
    
    // MARK: - Internal Views
    
    // Frosted glass hero pill
    struct QuickStatPill: View {
        let icon: String
        let title: String
        let delay: Double
        @State private var show = false
        
        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.15))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .opacity(show ? 1 : 0)
            .offset(x: show ? 0 : -10)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                    show = true
                }
            }
        }
    }
    
    // Base white card wrapper
    struct CardBlock<Content: View>: View {
        let borderColor: Color
        let content: () -> Content
        
        var body: some View {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.cardSurface)
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
                
                // Color strip
                if borderColor != .clear {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(borderColor)
                        .frame(width: 4)
                        .padding(.vertical, 8)
                }
                
                content()
            }
        }
    }
    
    // List item inside a card
    struct AppointmentRow: View {
        let appointment: Appointment
        let isUpcoming: Bool
        
        private var statusColor: Color {
            switch appointment.status.lowercased() {
            case "completed": return AppTheme.success
            case "cancelled": return AppTheme.error
            case "in-progress", "in_progress": return AppTheme.warning
            default: return AppTheme.primary
            }
        }
        
        var body: some View {
            HStack(spacing: 14) {
                // Date block
                VStack(spacing: 2) {
                    let parts = appointment.date.split(separator: "-")
                    if parts.count == 3 {
                        Text(String(parts[2]))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(isUpcoming ? AppTheme.primary : AppTheme.textSecondary)
                        Text(monthName(String(parts[1])))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .frame(width: 44)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(appointment.department ?? "Consultation")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text(appointment.status.capitalized)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(statusColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(statusColor.opacity(0.12))
                            .cornerRadius(6)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text("\(appointment.startTime) - \(appointment.endTime)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(AppTheme.textSecondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary.opacity(0.3))
            }
            .padding(.vertical, 14)
            .padding(.trailing, 16)
            .padding(.leading, 20)
            .contentShape(Rectangle())
        }
        
        private func formatDate(_ dateString: String) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateString) {
                let outFormatter = DateFormatter()
                outFormatter.dateFormat = "MMM d, yyyy"
                return outFormatter.string(from: date)
            }
            return dateString
        }
        
        private func monthName(_ monthNum: String) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM"
            if let date = formatter.date(from: monthNum) {
                formatter.dateFormat = "MMM"
                return formatter.string(from: date).uppercased()
            }
            return monthNum
        }
    }
    
    // Detail item in the grid
    struct DetailChip: View {
        let title: String
        let value: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.gray.opacity(0.06))
            .cornerRadius(10)
        }
    }
    
    // Patient Info Chip for details row
    struct PatientInfoChip: View {
        let icon: String
        let label: String
        let value: String
        let color: Color
        
        var body: some View {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)
                }
                
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.cardSurface)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
    }
}
