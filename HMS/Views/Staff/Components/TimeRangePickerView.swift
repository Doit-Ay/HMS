import SwiftUI

struct TimeRangePickerView: View {
    @Binding var startTime: Date
    @Binding var endTime: Date
    var allowedRange: ClosedRange<Date>? = nil
    
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
            // Time picker pills — matching the design
            HStack(spacing: 16) {
                // FROM pill
                TimePillPicker(label: "From", time: $startTime, allowedRange: allowedRange)
                
                // TO pill
                TimePillPicker(label: "To", time: $endTime, allowedRange: allowedRange)
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
    }
}

// MARK: - Pill-shaped Time Picker (matching design image)
struct TimePillPicker: View {
    let label: String
    let time: Binding<Date>
    var allowedRange: ClosedRange<Date>? = nil
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Label
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            
            // Pill container with DatePicker overlay
            ZStack {
                // Visual pill
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                    
                    Text(timeString)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.4))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(AppTheme.cardSurface)
                .cornerRadius(28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                
                // Invisible DatePicker overlay for interaction
                if let range = allowedRange {
                    DatePicker(
                        "",
                        selection: time,
                        in: range,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .colorScheme(.light)
                    .opacity(0.02) // Nearly invisible but tappable
                    .allowsHitTesting(true)
                } else {
                    DatePicker(
                        "",
                        selection: time,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .colorScheme(.light)
                    .opacity(0.02) // Nearly invisible but tappable
                    .allowsHitTesting(true)
                }
            }
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
