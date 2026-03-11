import SwiftUI

struct TimeRangePickerView: View {
    @Binding var startTime: Date
    @Binding var endTime: Date
    
    private var formattedDuration: String {
        let diff = endTime.timeIntervalSince(startTime)
        if diff <= 0 { return "Invalid range" }
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m unavailable" }
        if hours > 0 { return "\(hours)h unavailable" }
        return "\(minutes)m unavailable"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                Text("Set Unavailable Hours")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }
            
            // Time picker cards
            HStack(spacing: 12) {
                // FROM card
                TimePickerCard(
                    label: "From",
                    icon: "sunrise.fill",
                    iconColor: .orange,
                    time: $startTime
                )
                
                // Arrow connector
                VStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.4))
                }
                .padding(.top, 24)
                
                // TO card
                TimePickerCard(
                    label: "To",
                    icon: "sunset.fill",
                    iconColor: Color(hex: "#EF4444"),
                    time: $endTime
                )
            }
            
            // Duration indicator
            HStack(spacing: 6) {
                Image(systemName: "hourglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange.opacity(0.7))
                Text(formattedDuration)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange.opacity(0.8))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(10)
        }
        .padding(20)
        .background(
            ZStack {
                Color.white.opacity(0.6)
            }
        )
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.orange.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Individual Time Picker Card
struct TimePickerCard: View {
    let label: String
    let icon: String
    let iconColor: Color
    let time: Binding<Date>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Label with icon
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            
            // Time picker
            HStack(spacing: 8) {
                DatePicker(
                    "",
                    selection: time,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .colorScheme(.light)
                .scaleEffect(1.05)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.8))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(iconColor.opacity(0.15), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        TimeRangePickerView(
            startTime: .constant(Date()),
            endTime: .constant(Date().addingTimeInterval(3600 * 4))
        )
        .padding()
    }
}
