import SwiftUI

struct TimeRangePickerView: View {
    @Binding var startTime: Date
    @Binding var endTime: Date
    
    var body: some View {
        HStack(spacing: 16) {
            // "From" Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Unavailable From")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(AppTheme.primary)
                        .font(.system(size: 18))
                    
                    DatePicker(
                        "",
                        selection: $startTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    // Ensures the white background of the picker blends beautifully or uses native wheel
                    .colorScheme(.light)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8) // DatePicker has internal padding, keep this small
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.textSecondary.opacity(0.2), lineWidth: 1))
            }
            .frame(maxWidth: .infinity)
            
            // "To" Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("To")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(AppTheme.primary)
                        .font(.system(size: 18))
                    
                    DatePicker(
                        "",
                        selection: $endTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .colorScheme(.light)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.textSecondary.opacity(0.2), lineWidth: 1))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        TimeRangePickerView(
            startTime: .constant(Date()),
            endTime: .constant(Date().addingTimeInterval(3600))
        )
        .padding()
    }
}
