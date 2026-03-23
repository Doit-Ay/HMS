import SwiftUI

struct DoctorHomeViewController: View {
    @State private var appearAnimation = false
    @State private var selectedDate = Date()
    
    // Details Sheet State
    @State private var selectedAppointment: AppointmentBlock?
    @State private var showProfile = false
    
    // Real appointments from Firestore
    @State private var todayAppointments: [Appointment] = []
    @State private var monthAppointments: [Appointment] = []
    @State private var isLoadingAppointments = false
    @State private var scrollToHour: Int? = nil
    
    // Greeting logic
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning," }
        if hour < 17 { return "Good Afternoon," }
        return "Good Evening,"
    }
    
    // Doctor Name
    private var doctorName: String {
        "Dr. \(UserSession.shared.currentUser?.fullName.split(separator: " ").first ?? "Saif")"
    }
    
    // Timeline Mapping
    private var timelineData: [AppointmentBlock] {
        return todayAppointments.compactMap { appt in
            guard let startDate = parseDateTime(date: appt.date, time: appt.startTime),
                  let endDate = parseDateTime(date: appt.date, time: appt.endTime) else {
                return nil
            }
            
            // Use different colors for variety based on hash
            let colors = [AppTheme.primaryLight, Color.orange.opacity(0.35), Color.blue.opacity(0.25), Color.purple.opacity(0.25)]
            let colorIdx = abs(appt.id.hashValue) % colors.count
            
            return AppointmentBlock(
                id: appt.id,
                patientId: appt.patientId,
                type: appt.department ?? "Consultation",
                startTime: startDate,
                endTime: endDate,
                patientName: appt.patientName,
                color: colors[colorIdx],
                additionalStaffCount: 0
            )
        }
    }
    
    private var datesWithAppointments: Set<Date> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return Set(monthAppointments.compactMap { formatter.date(from: $0.date) })
    }
    
    private func parseDateTime(date: String, time: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: "\(date) \(time)")
    }
    
    // Appointments Label
    private var appointmentsLabel: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today's Appointments"
        } else if Calendar.current.isDateInTomorrow(selectedDate) {
            return "Tomorrow's Appointments"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMMM"
            return "Appointments on \(formatter.string(from: selectedDate))"
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Very light background
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)

                        Text(doctorName)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    
                    Spacer()
                    
                    Button(action: { showProfile = true }) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundColor(AppTheme.primaryDark)
                            .background(Circle().fill(AppTheme.primaryLight))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .offset(y: appearAnimation ? 0 : -30)
                .opacity(appearAnimation ? 1 : 0)
                
                // 2. Today's Booked Appointments (from Firestore)
                if !todayAppointments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.primary)
                            Text(appointmentsLabel)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text("\(todayAppointments.count)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AppTheme.primary.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 24)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(todayAppointments) { appt in
                                    Button {
                                        if let blockInfo = timelineData.first(where: { $0.id == appt.id }) {
                                            selectedAppointment = blockInfo
                                        }
                                    } label: {
                                        BookedAppointmentCard(appointment: appt)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 8)
                }
                
                // 3. Weekly Calendar Strip
                WeekCalendarView(
                    selectedDate: $selectedDate,
                    datesWithAppointments: datesWithAppointments
                )
                .padding(.top, 8)
                .offset(y: appearAnimation ? 0 : 20)
                .opacity(appearAnimation ? 1 : 0)
                
                // 5. Vertical Timeline
                ZStack {
                    AppTheme.cardSurface
                        .cornerRadius(32, corners: [.topLeft, .topRight])
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: -5)
                        .ignoresSafeArea()
                    
                    AppointmentTimelineView(
                        appointments: timelineData,
                        selectedDate: selectedDate,
                        onAppointmentTap: { appt in
                            selectedAppointment = appt
                        },
                        scrollToHour: $scrollToHour
                    )
                    // Trigger redraw when date changes to recalculate the view
                    .id(selectedDate)
                }
                .padding(.top, 16)
                .offset(y: appearAnimation ? 0 : 50)
                .opacity(appearAnimation ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
            loadTodayAppointments()
        }
        .onChange(of: selectedDate) { _ in
            loadTodayAppointments()
        }

        .sheet(item: $selectedAppointment) { appt in
            if #available(iOS 16.0, *) {
                AppointmentDetailSheet(appointment: appt)
                    .presentationDetents([.fraction(0.65), .large])
                    .presentationDragIndicator(.hidden)
            } else {
                AppointmentDetailSheet(appointment: appt)
            }
        }
        .sheet(isPresented: $showProfile) {
            DoctorProfileView()
        }
    }
    
    // MARK: - Load Appointments from Firestore
    private func loadTodayAppointments() {
        guard let doctorId = UserSession.shared.currentUser?.id else { return }
        isLoadingAppointments = true
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: selectedDate)
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        let monthStr = monthFormatter.string(from: selectedDate)
        
        Task {
            do {
                async let todayFetch = AuthManager.shared.fetchDoctorAppointments(doctorId: doctorId, date: dateStr)
                async let monthFetch = AuthManager.shared.fetchDoctorAppointments(doctorId: doctorId, month: monthStr)
                
                let (today, month) = try await (todayFetch, monthFetch)
                
                withAnimation {
                    self.todayAppointments = today.filter { $0.status != "cancelled" }
                    self.monthAppointments = month.filter { $0.status != "cancelled" }
                }
            } catch {
                print("⚠️ Error loading appointments: \(error)")
            }
            isLoadingAppointments = false
        }
    }
}

// Helper for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

// MARK: - Booked Appointment Card (from Firestore)
struct BookedAppointmentCard: View {
    let appointment: Appointment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.primary.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(
                        LivePatientAvatarInitial(
                            patientId: appointment.patientId,
                            fallbackName: appointment.patientName,
                            font: .system(size: 14, design: .rounded),
                            weight: .bold,
                            color: AppTheme.primary
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    LivePatientNameView(
                        patientId: appointment.patientId,
                        fallbackName: appointment.patientName,
                        font: .system(size: 14, design: .rounded),
                        weight: .bold,
                        color: AppTheme.textPrimary,
                        lineLimit: 1
                    )
                    
                    if let dept = appointment.department {
                        Text(dept)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.primary)
                Text("\(appointment.startTime) – \(appointment.endTime)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }
            
            // Status badge
            Text(appointment.status.capitalized)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(appointment.status == "scheduled" ? .orange : AppTheme.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    (appointment.status == "scheduled" ? Color.orange : AppTheme.primary)
                        .opacity(0.1)
                )
                .cornerRadius(6)
        }
        .padding(14)
        .frame(width: 180)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#Preview {
    DoctorHomeViewController()
}
