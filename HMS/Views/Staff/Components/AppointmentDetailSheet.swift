import SwiftUI

struct AppointmentDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    let appointment: AppointmentBlock
    
    var body: some View {
        VStack(spacing: 24) {
            // Grabber pill
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
            
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
                
                Text(appointment.patientName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }
            
            // Info Pills Row
            HStack(spacing: 16) {
                InfoPill(title: "Age", value: "32")
                InfoPill(title: "Blood", value: "O+")
                InfoPill(title: "Height", value: "180cm")
                InfoPill(title: "Weight", value: "75kg")
            }
            .padding(.horizontal, 24)
            
            // Details List
            VStack(spacing: 16) {
                DetailRow(icon: "clock", title: "Time", value: "\(timeString(appointment.startTime)) - \(timeString(appointment.endTime))")
                DetailRow(icon: "stethoscope", title: "Type", value: appointment.type)
                
                // Tags
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 24)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            TagView(text: "Hypertension")
                            TagView(text: "Asthma")
                        }
                    }
                    Spacer()
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
        .background(Color.white.ignoresSafeArea())
    }
    
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
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
    let appt = AppointmentBlock(type: "Consultation", startTime: Date(), endTime: Date().addingTimeInterval(3600), patientName: "Oliver Smith", color: AppTheme.primaryLight, additionalStaffCount: 2)
    AppointmentDetailSheet(appointment: appt)
}
