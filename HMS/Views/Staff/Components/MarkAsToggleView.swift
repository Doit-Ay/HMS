import SwiftUI

struct MarkAsToggleView: View {
    @Binding var selection: DayAvailabilityState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mark As")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            
            HStack(spacing: 12) {
                // Available Pill
                TogglePill(
                    title: "Available",
                    icon: "checkmark.circle.fill",
                    isSelected: selection == .available,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selection = .available
                        }
                    }
                )
                
                // Half Day Pill
                TogglePill(
                    title: "Half Day",
                    icon: "cloud.sun.fill",
                    isSelected: selection == .halfDay,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selection = .halfDay
                        }
                    }
                )
                
                // Unavailable Pill
                TogglePill(
                    title: "Unavailable",
                    icon: "xmark.circle.fill",
                    isSelected: selection == .unavailable,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selection = .unavailable
                        }
                    }
                )
            }
        }
    }
}

// Reusable animated pill component
struct TogglePill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            // Animate background color transition
            .background(isSelected ? AppTheme.primary : Color.white)
            .cornerRadius(12)
            // Border when unselected
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppTheme.primary : AppTheme.textSecondary.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: isSelected ? AppTheme.primary.opacity(0.3) : Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
            // Small scale effect on selection
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        MarkAsToggleView(selection: .constant(.halfDay))
            .padding()
    }
}
