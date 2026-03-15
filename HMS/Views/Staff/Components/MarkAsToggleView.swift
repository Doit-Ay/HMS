import SwiftUI

struct MarkAsToggleView: View {
    @Binding var selection: DayAvailabilityState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mark As")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            
            HStack(spacing: 10) {
                AvailabilityOptionCard(
                    title: "Available",
                    subtitle: "Full day",
                    icon: "checkmark.circle.fill",
                    color: AppTheme.success,
                    isSelected: selection == .available,
                    action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selection = .available
                        }
                    }
                )
                
                AvailabilityOptionCard(
                    title: "Custom",
                    subtitle: "Set hours",
                    icon: "circle.lefthalf.filled",
                    color: Color.orange,
                    isSelected: selection == .halfDay,
                    action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selection = .halfDay
                        }
                    }
                )
                
                AvailabilityOptionCard(
                    title: "Off",
                    subtitle: "All day",
                    icon: "moon.circle.fill",
                    color: Color(hex: "#EF4444"),
                    isSelected: selection == .unavailable,
                    action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selection = .unavailable
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Premium Availability Option Card
struct AvailabilityOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                // Icon with background circle
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                            ? color.opacity(0.2)
                            : Color.gray.opacity(0.08)
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(isSelected ? color : AppTheme.textSecondary.opacity(0.5))
                        .symbolEffect(.bounce, value: isSelected)
                }
                
                // Title
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                
                // Subtitle
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? color : AppTheme.textSecondary.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    if isSelected {
                        // Glass effect when selected
                        Color.white.opacity(0.7)
                    } else {
                        Color.white.opacity(0.4)
                    }
                }
            )
            .background(isSelected ? .ultraThinMaterial : .ultraThinMaterial)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ? color.opacity(0.4) : Color.gray.opacity(0.12),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: isSelected ? color.opacity(0.15) : Color.black.opacity(0.03),
                radius: isSelected ? 10 : 4,
                x: 0,
                y: isSelected ? 5 : 2
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
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
