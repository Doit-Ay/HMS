import SwiftUI

struct AvailabilityCard: View {
    @State private var selectedSlot = "08:30 PM"
    
    let timeSlots = [
        "04:30 PM", "05:00 PM", "06:30 PM",
        "07:00 PM", "07:45 PM", "08:30 PM"
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today,")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Availability")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                Spacer()
                
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 12))
                        Text("6 Stats")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(AppTheme.textSecondary)
                }
            }
            
            // Grid of pills
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                ForEach(timeSlots, id: \.self) { slot in
                    let isSelected = selectedSlot == slot
                    
                    Button(action: {
                        selectedSlot = slot
                    }) {
                        Text(slot)
                            .font(.system(size: 13, weight: isSelected ? .bold : .semibold, design: .rounded))
                            .foregroundColor(isSelected ? AppTheme.textOnPrimary : AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(isSelected ? AppTheme.textPrimary : AppTheme.background)
                            .cornerRadius(22)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Book Appointment CTA usually floats or sits below this, 
            // but the prompt says this is the availability card specifically.
        }
        .padding(24)
        .background(AppTheme.cardSurface)
        .cornerRadius(28)
        // Soft, 8pt blur, ~10% opacity black as per reqs
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}
