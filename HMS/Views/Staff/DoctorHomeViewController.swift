import SwiftUI

struct DoctorHomeViewController: View {
    @State private var appearAnimation = false
    @State private var selectedDate = Date()
    @State private var activePatientID: UUID?
    
    // Details Sheet State
    @State private var selectedAppointment: AppointmentBlock?
    @State private var showPrescriptionForm = false
    
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
    
    // Fake Data Generation based on selected date
    private let patientStripData = [
        PatientStripModel(name: "Oliver Smith", time: "09:00 AM", status: .done),
        PatientStripModel(name: "Ava Johnson", time: "10:30 AM", status: .inProgress),
        PatientStripModel(name: "Liam Williams", time: "02:00 PM", status: .upcoming),
        PatientStripModel(name: "Emma Davis", time: "04:15 PM", status: .upcoming)
    ]
    
    // Simulate changing schedule based on date
    private var timelineData: [AppointmentBlock] {
        let cal = Calendar.current
        let day = cal.component(.day, from: selectedDate)
        let startOfDay = cal.startOfDay(for: selectedDate)
        
        if day % 2 != 0 {
            return [
                AppointmentBlock(type: "Consultation", startTime: startOfDay.addingTimeInterval(9 * 3600), endTime: startOfDay.addingTimeInterval(9.75 * 3600), patientName: "Oliver Smith", color: AppTheme.primaryLight, additionalStaffCount: 0),
                AppointmentBlock(type: "Heart ECG", startTime: startOfDay.addingTimeInterval(10.5 * 3600), endTime: startOfDay.addingTimeInterval(11.5 * 3600), patientName: "Ava Johnson", color: Color.orange.opacity(0.15), additionalStaffCount: 2),
                AppointmentBlock(type: "Follow Up", startTime: startOfDay.addingTimeInterval(14 * 3600), endTime: startOfDay.addingTimeInterval(14.5 * 3600), patientName: "Liam Williams", color: Color.blue.opacity(0.1), additionalStaffCount: 0)
            ]
        } else {
             return [
                 AppointmentBlock(type: "Blood Test Review", startTime: startOfDay.addingTimeInterval(8.5 * 3600), endTime: startOfDay.addingTimeInterval(9 * 3600), patientName: "Noah Garcia", color: AppTheme.primaryLight, additionalStaffCount: 1),
                 AppointmentBlock(type: "General Checkup", startTime: startOfDay.addingTimeInterval(13 * 3600), endTime: startOfDay.addingTimeInterval(14.25 * 3600), patientName: "Mia Brown", color: Color.purple.opacity(0.1), additionalStaffCount: 0)
             ]
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Very light background
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Top Header Bar
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(greeting)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                        Text(doctorName)
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .offset(y: appearAnimation ? 0 : -30)
                .opacity(appearAnimation ? 1 : 0)
                
                // 2. Patient Strip (Scrollable)
                PatientCardStrip(patients: patientStripData, activePatientID: $activePatientID)
                    .padding(.top, 8)
                
                // 3. Weekly Calendar Strip
                WeekCalendarView(
                    selectedDate: $selectedDate,
                    datesWithAppointments: [Date(), Calendar.current.date(byAdding: .day, value: 1, to: Date())!, Calendar.current.date(byAdding: .day, value: -2, to: Date())!] // Fake some dots
                )
                .padding(.top, 8)
                .offset(y: appearAnimation ? 0 : 20)
                .opacity(appearAnimation ? 1 : 0)
                
                // 4. Vertical Timeline
                ZStack {
                    Color.white
                        .cornerRadius(32, corners: [.topLeft, .topRight])
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: -5)
                        .ignoresSafeArea()
                    
                    AppointmentTimelineView(
                        appointments: timelineData,
                        onAppointmentTap: { appt in
                            selectedAppointment = appt
                        }
                    )
                    // Trigger redraw when date changes to recalculate the view
                    .id(selectedDate)
                }
                .padding(.top, 16)
                .offset(y: appearAnimation ? 0 : 50)
                .opacity(appearAnimation ? 1 : 0)
            }
            
            // 5. Write Prescription FAB
            DoctorFABView {
                showPrescriptionForm = true
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
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
        .sheet(isPresented: $showPrescriptionForm) {
            if #available(iOS 16.0, *) {
                Text("Write Prescription Form (Coming Soon)")
                    .font(.headline)
                    .presentationDetents([.medium, .large])
            } else {
                Text("Write Prescription Form (Coming Soon)")
                    .font(.headline)
            }
        }
    }
}

// Helper for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
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
