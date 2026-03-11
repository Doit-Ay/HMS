import SwiftUI
import Combine

struct AppointmentBlock: Identifiable {
    let id = UUID()
    let type: String
    let startTime: Date
    let endTime: Date
    let patientName: String
    let color: Color
    let additionalStaffCount: Int
}

struct AppointmentTimelineView: View {
    let appointments: [AppointmentBlock]
    let onAppointmentTap: (AppointmentBlock) -> Void
    
    // Config
    private let hourHeight: CGFloat = 80
    private let startHour = 8 // 8 AM
    private let endHour = 18 // 6 PM
    
    // Animation state
    @State private var appearAnimation = false
    @State private var nowLinePulse = false
    
    // We use a ScrollViewReader to scroll to 'now' on appear
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    
                    // 1. Time Axis Background Grid
                    VStack(spacing: 0) {
                        ForEach(startHour...endHour, id: \.self) { hour in
                            HStack(alignment: .top, spacing: 12) {
                                // Time label
                                Text(timeString(for: hour))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .frame(width: 50, alignment: .trailing)
                                    .offset(y: -8) // center vertically with the line
                                
                                // Dashed line separator
                                VStack {
                                    Divider()
                                        .background(AppTheme.textSecondary.opacity(0.3))
                                    Spacer()
                                }
                            }
                            .frame(height: hourHeight)
                            .id(hour) // For scrolling
                        }
                    }
                    
                    // 2. Appointment Blocks
                    ForEach(appointments) { appt in
                        AppointmentCard(appt: appt, appearAnimation: appearAnimation)
                            .offset(y: yOffset(for: appt.startTime))
                            .frame(height: height(for: appt.startTime, to: appt.endTime))
                            .padding(.leading, 62 + 12) // TimeLabel width + spacing
                            .padding(.trailing, 24)
                            .onTapGesture {
                                onAppointmentTap(appt)
                            }
                    }
                    
                    // 3. Current Time ("Now") Line
                    CurrentTimeLine(
                        hourHeight: hourHeight,
                        startHour: startHour,
                        pulse: nowLinePulse
                    )
                }
                .padding(.vertical, 24)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    appearAnimation = true
                }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    nowLinePulse = true
                }
                
                // Scroll to current hour minus 1 for context
                let currentHour = Calendar.current.component(.hour, from: Date())
                let targetHour = max(startHour, min(currentHour - 1, endHour))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo(targetHour, anchor: .top)
                    }
                }
            }
        }
    }
    
    // Helpers for calculating physical view positioning based on time
    private func yOffset(for date: Date) -> CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        let relativeHour = hour - startHour
        let totalHours = CGFloat(relativeHour) + (CGFloat(minute) / 60.0)
        
        return totalHours * hourHeight
    }
    
    private func height(for start: Date, to end: Date) -> CGFloat {
        let durationMinutes = end.timeIntervalSince(start) / 60.0
        let hours = CGFloat(durationMinutes) / 60.0
        return max(hours * hourHeight - 2, 40) // Minimum height minus 2 for gap
    }
    
    private func timeString(for hour: Int) -> String {
        let isPM = hour >= 12
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(displayHour):00 \(isPM ? "PM" : "AM")"
    }
}

// Current Time Line Indicator
struct CurrentTimeLine: View {
    let hourHeight: CGFloat
    let startHour: Int
    let pulse: Bool
    
    @State private var now = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    private var yOffset: CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        let relativeHour = hour - startHour
        let totalHours = CGFloat(relativeHour) + (CGFloat(minute) / 60.0)
        
        return totalHours * hourHeight
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(AppTheme.primary)
                .frame(width: 8, height: 8)
                .offset(x: -4) // Center dot on the left axis
                .scaleEffect(pulse ? 1.2 : 1.0)
                .opacity(pulse ? 1.0 : 0.6)
            
            Rectangle()
                .fill(AppTheme.primary)
                .frame(height: 2)
                .opacity(pulse ? 1.0 : 0.6)
        }
        .padding(.leading, 62 + 12) // Match appointment padding
        .padding(.trailing, 24)
        .offset(y: yOffset)
        .onReceive(timer) { input in
            now = input
        }
    }
}


// Visual Card for an appointment
struct AppointmentCard: View {
    let appt: AppointmentBlock
    let appearAnimation: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(appt.type)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            
            Text("\(timeString(appt.startTime)) – \(timeString(appt.endTime))")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
            
            Spacer(minLength: 0)
            
            HStack(spacing: 8) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 20, height: 20)
                    Text(String(appt.patientName.prefix(1)))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                Text(appt.patientName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                if appt.additionalStaffCount > 0 {
                    Text("+\(appt.additionalStaffCount) nurses")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.primaryDark)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.8))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(appt.color)
        .cornerRadius(12)
        .shadow(color: appt.color.opacity(0.4), radius: 6, x: 0, y: 3)
        // Card hover in animation
        .offset(y: appearAnimation ? 0 : 30)
        .opacity(appearAnimation ? 1 : 0)
    }
    
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        let today = Calendar.current.startOfDay(for: Date())
        AppointmentTimelineView(appointments: [
            AppointmentBlock(type: "Consultation", startTime: today.addingTimeInterval(9 * 3600), endTime: today.addingTimeInterval(9.75 * 3600), patientName: "Oliver Smith", color: AppTheme.primaryLight, additionalStaffCount: 2),
            AppointmentBlock(type: "Heart ECG", startTime: today.addingTimeInterval(10.5 * 3600), endTime: today.addingTimeInterval(11.5 * 3600), patientName: "Ava Johnson", color: Color.orange.opacity(0.2), additionalStaffCount: 0)
        ], onAppointmentTap: { _ in })
    }
}
