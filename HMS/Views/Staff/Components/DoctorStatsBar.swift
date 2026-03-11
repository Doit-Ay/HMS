import SwiftUI

struct DoctorStatsBar: View {
    // These would typically be passed in, but hardcoded here for the UI prompt requirements
    let rating: String = "4.8"
    let totalPatients: String = "1,240"
    let appointments: String = "3,580"
    
    var body: some View {
        HStack(spacing: 12) {
            // Rating Stat
            StatPill(
                title: "Rating",
                value: rating,
                iconColor: AppTheme.primary,
                iconName: "star.fill"
            )
            
            // Patients Stat
            StatPill(
                title: "Total Patients",
                value: totalPatients,
                iconColor: .clear,
                iconName: nil
            )
            
            // Appointments Stat
            StatPill(
                title: "Appointments",
                value: appointments,
                iconColor: .clear,
                iconName: nil
            )
        }
    }
}

// Reusable individual pill for the stats bar
struct StatPill: View {
    let title: String
    let value: String
    let iconColor: Color
    let iconName: String?
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            HStack(spacing: 4) {
                if let icon = iconName {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(iconColor)
                }
                
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        DoctorStatsBar()
            .padding()
    }
}
