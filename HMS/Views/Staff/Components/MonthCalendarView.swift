import SwiftUI

struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    @State private var displayedMonth: Date = Date()
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    
    // Generate the month/year title
    private var monthYearTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }
    
    // Generate all the calendar cells for the displayed month
    private var calendarCells: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }
        
        // Sunday = 1, so we offset accordingly (ISO: Sun=1, Mon=2)
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        // Convert so Sunday=0
        let offset = (firstWeekday - 1) % 7
        
        var cells: [Date?] = Array(repeating: nil, count: offset)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                cells.append(date)
            }
        }
        
        // Pad out the last week
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        
        return cells
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Month Header with Nav Arrows
            HStack {
                Text(monthYearTitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                HStack(spacing: 16) {
                    Button(action: { shiftMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(8)
                            .background(AppTheme.cardSurface)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 2)
                    }
                    Button(action: { shiftMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(8)
                            .background(AppTheme.cardSurface)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 2)
                    }
                }
            }
            .padding(.horizontal, 24)
            
            // Calendar Grid UI
            VStack(spacing: 12) {
                // Day Headers
                HStack(spacing: 0) {
                    ForEach(daysOfWeek, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                
                // Days Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 10) {
                    ForEach(0..<calendarCells.count, id: \.self) { index in
                        let date = calendarCells[index]
                        let isSelected = date != nil && calendar.isDate(date!, inSameDayAs: selectedDate)
                        let isToday = date != nil && calendar.isDateInToday(date!)
                        
                        Button(action: {
                            if let d = date {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDate = d
                                }
                            }
                        }) {
                            ZStack {
                                if isSelected {
                                    Circle()
                                        .fill(AppTheme.primary)
                                        .frame(width: 38, height: 38)
                                        .shadow(color: AppTheme.primary.opacity(0.3), radius: 6, x: 0, y: 3)
                                } else if isToday {
                                    Circle()
                                        .stroke(AppTheme.primary, lineWidth: 2)
                                        .frame(width: 38, height: 38)
                                }
                                
                                if let d = date {
                                    Text(dayNumber(from: d))
                                        .font(.system(size: 15, weight: isSelected || isToday ? .bold : .medium, design: .rounded))
                                        .foregroundColor(
                                            isSelected ? .white :
                                            isToday ? AppTheme.primary : AppTheme.textPrimary
                                        )
                                }
                            }
                            .frame(height: 40)
                        }
                        .disabled(date == nil)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func shiftMonth(by value: Int) {
        withAnimation {
            if let newDate = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
                displayedMonth = newDate
            }
        }
    }
    
    private func dayNumber(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        MonthCalendarView(selectedDate: .constant(Date()))
    }
}
