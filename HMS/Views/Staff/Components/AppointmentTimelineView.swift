import SwiftUI
import Combine

struct AppointmentBlock: Identifiable {
    var id: String = UUID().uuidString
    let patientId: String
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
    
    // Config — increased hourHeight for more breathing room
    private let hourHeight: CGFloat = 100
    private let startHour = 8 // 8 AM
    private let endHour = 20 // 8 PM
    private let timeColumnWidth: CGFloat = 62
    private let cardLeadingPadding: CGFloat = 12
    private let cardTrailingPadding: CGFloat = 24
    
    // Animation state
    @State private var appearAnimation = false
    @State private var nowLinePulse = false
    
    /// Total height of the timeline grid
    private var totalGridHeight: CGFloat {
        CGFloat(endHour - startHour + 1) * hourHeight
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    
                    // 1. Time Axis Background Grid (with half-hour lines)
                    VStack(spacing: 0) {
                        ForEach(startHour...endHour, id: \.self) { hour in
                            VStack(spacing: 0) {
                                // Full hour row: label + line
                                HStack(alignment: .top, spacing: 12) {
                                    Text(timeString(for: hour))
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .frame(width: 50, alignment: .trailing)
                                        .offset(y: -8)
                                    
                                    VStack {
                                        Divider()
                                            .background(AppTheme.textSecondary.opacity(0.3))
                                        Spacer()
                                    }
                                }
                                .frame(height: hourHeight / 2)
                                
                                // Half-hour row: no label, lighter line
                                HStack(alignment: .top, spacing: 12) {
                                    // Empty space where label would be
                                    Color.clear
                                        .frame(width: 50)
                                        .offset(y: -8)
                                    
                                    VStack {
                                        Divider()
                                            .background(AppTheme.textSecondary.opacity(0.12))
                                        Spacer()
                                    }
                                }
                                .frame(height: hourHeight / 2)
                            }
                            .frame(height: hourHeight)
                            .id(hour)
                        }
                    }
                    
                    // 2. Appointment Blocks — stretching full width to edges
                    ForEach(appointments) { appt in
                        AppointmentCard(appt: appt, appearAnimation: appearAnimation)
                            .frame(height: cardHeight(for: appt))
                            .padding(.leading, timeColumnWidth + cardLeadingPadding)
                            .padding(.trailing, 8) // small right margin
                            .offset(y: yPosition(for: appt.startTime))
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
    
    // MARK: - Positioning Helpers
    
    /// Calculate the Y position (top edge) of a card based on its start time
    private func yPosition(for date: Date) -> CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        let relativeHour = hour - startHour
        let totalHours = CGFloat(relativeHour) + (CGFloat(minute) / 60.0)
        
        return totalHours * hourHeight
    }
    
    /// Calculate the height of a card based on its duration
    private func cardHeight(for appt: AppointmentBlock) -> CGFloat {
        let durationMinutes = appt.endTime.timeIntervalSince(appt.startTime) / 60.0
        let hours = CGFloat(durationMinutes) / 60.0
        return max(hours * hourHeight, 60) // Minimum 60pt height
    }
    
    /// Detect overlapping appointments and assign columns so they sit side by side
    private func computeColumns(appointments: [AppointmentBlock]) -> [String: (column: Int, totalColumns: Int)] {
        // Sort by start time
        let sorted = appointments.sorted { $0.startTime < $1.startTime }
        
        // Group overlapping appointments together
        var groups: [[AppointmentBlock]] = []
        
        for appt in sorted {
            var placed = false
            for i in groups.indices {
                // Check if this appointment overlaps with any in the group
                let groupOverlaps = groups[i].contains { existing in
                    appt.startTime < existing.endTime && appt.endTime > existing.startTime
                }
                if groupOverlaps {
                    groups[i].append(appt)
                    placed = true
                    break
                }
            }
            if !placed {
                groups.append([appt])
            }
        }
        
        // Assign column indices within each group
        var result: [String: (column: Int, totalColumns: Int)] = [:]
        
        for group in groups {
            let totalCols = group.count
            for (idx, appt) in group.enumerated() {
                result[appt.id] = (column: idx, totalColumns: totalCols)
            }
        }
        
        return result
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
        
        // Offset by -8 to perfectly align with the center of the text label/divider line
        return (totalHours * hourHeight) - 8
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


// Visual Card for an appointment — shows only Name + Time
struct AppointmentCard: View {
    let appt: AppointmentBlock
    let appearAnimation: Bool
    
    var body: some View {
        NavigationLink(destination: PatientDetailView(patientId: appt.patientId, patientName: appt.patientName)) {
            HStack(spacing: 12) {
                // Avatar circle
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 28, height: 28)
                    
                    LivePatientAvatarInitial(
                        patientId: appt.patientId,
                        fallbackName: appt.patientName,
                        font: .system(size: 13, design: .rounded),
                        weight: .bold,
                        color: AppTheme.textPrimary
                    )
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    // Patient Name
                    LivePatientNameView(
                        patientId: appt.patientId,
                        fallbackName: appt.patientName,
                        font: .system(size: 14, design: .rounded),
                        weight: .bold,
                        color: AppTheme.textPrimary,
                        lineLimit: 1
                    )
                    
                    // Time slot
                    Text("\(timeString(appt.startTime)) – \(timeString(appt.endTime))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(appt.color)
            .cornerRadius(12)
            .shadow(color: appt.color.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
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
            AppointmentBlock(patientId: "patient_1", type: "Consultation", startTime: today.addingTimeInterval(9 * 3600), endTime: today.addingTimeInterval(9.75 * 3600), patientName: "Oliver Smith", color: AppTheme.primaryLight, additionalStaffCount: 2),
            AppointmentBlock(patientId: "patient_2", type: "Heart ECG", startTime: today.addingTimeInterval(10.5 * 3600), endTime: today.addingTimeInterval(11.5 * 3600), patientName: "Ava Johnson", color: Color.orange.opacity(0.2), additionalStaffCount: 0)
        ], onAppointmentTap: { _ in })
    }
}
