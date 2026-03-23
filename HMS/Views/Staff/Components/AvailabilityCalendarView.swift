import SwiftUI

enum DayAvailabilityState {
    case available
    case halfDay
    case unavailable
}

struct AvailabilityCalendarView: View {
    @Binding var selectedDate: Date?
    // Map of dates (start of day) to their availability state
    let availabilityMap: [Date: DayAvailabilityState]
    
    @State private var visibleMonth: Date = Date()
    private let calendar = Calendar.current
    private let daysOfWeek = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    
    private var monthYearTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: visibleMonth)
    }
    
    // Generate the days for the current grid
    private var daysInMonth: [Date?] {
        var days: [Date?] = []
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth) else { return days }
        
        let firstDayOfMonth = monthInterval.start
        
        // Determine offset for empty cells (Monday = 1 ... Sunday = 7 in ISO8601)
        var firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        // Convert Sunday=1...Saturday=7 to Monday=1...Sunday=7 logic
        firstWeekday = firstWeekday == 1 ? 7 : firstWeekday - 1
        
        // Add empty leading cells
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        // Add real days
        var currentDay = firstDayOfMonth
        while currentDay < monthInterval.end {
            days.append(currentDay)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = nextDay
        }
        
        return days
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header: Month Title & Nav Arrows
            HStack {
                Text(monthYearTitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                
                HStack(spacing: 24) {
                    Button(action: { shiftMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Button(action: { shiftMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            
            // Days of Week Header
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            
            // Calendar Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 12) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, dateOpt in
                    if let date = dateOpt {
                        DayCell(
                            date: date,
                            state: availabilityMap[calendar.startOfDay(for: date)] ?? .available,
                            isSelected: isSelected(date),
                            isPast: isPast(date)
                        )
                        .onTapGesture {
                            if !isPast(date) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    selectedDate = date
                                }
                            }
                        }
                    } else {
                        // Empty cell logic
                        Color.clear
                            .frame(height: 48)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .background(AppTheme.cardSurface)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
    }
    
    private func shiftMonth(by months: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let newDate = calendar.date(byAdding: .month, value: months, to: visibleMonth) {
                visibleMonth = newDate
            }
        }
    }
    
    private func isSelected(_ date: Date) -> Bool {
        guard let sel = selectedDate else { return false }
        return calendar.isDate(date, inSameDayAs: sel)
    }
    
    // Check if the day is physically in the past relative to today's date
    private func isPast(_ date: Date) -> Bool {
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDate = calendar.startOfDay(for: date)
        return startOfDate < startOfToday
    }
}

// Logic for an individual Day Cell styling
struct DayCell: View {
    let date: Date
    let state: DayAvailabilityState
    let isSelected: Bool
    let isPast: Bool
    
    private let calendar = Calendar.current
    private var isToday: Bool { calendar.isDateInToday(date) }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        ZStack {
            // Background Layer
            if isSelected {
                Circle()
                    .fill(AppTheme.primary)
                    .transition(.scale)
            } else if state == .unavailable {
                Circle()
                    // Dark charcoal as requested
                    .fill(Color(white: 0.2))
            } else if state == .halfDay {
                // Diagonal Hatch overlay using a masked pattern
                DiagonalHatchShape()
                    // Dark charcoal as requested
                    .stroke(Color(white: 0.2), lineWidth: 1.5)
                    .clipShape(Circle())
            } else if isToday {
                Circle()
                    .stroke(AppTheme.primary, lineWidth: 2)
            }
            
            // Text Layer
            Text(dayNumber)
                .font(.system(size: 16, weight: isSelected || state != .available || isToday ? .bold : .medium, design: .rounded))
                .foregroundColor(textColor)
        }
        .frame(height: 48)
        .opacity(isPast ? 0.3 : 1.0)
    }
    
    private var textColor: Color {
        if isSelected { return .white }
        if state == .unavailable { return .white }
        if isToday { return AppTheme.primaryDark }
        return AppTheme.textPrimary
    }
}

// Custom shape to draw a simple diagonal hash pattern
struct DiagonalHatchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 8 // Gap between lines
        
        let maxDim = max(rect.width, rect.height)
        
        // Draw diagonal lines from top-left to bottom-right
        for i in stride(from: -maxDim, through: maxDim * 2, by: step) {
            path.move(to: CGPoint(x: i, y: 0))
            path.addLine(to: CGPoint(x: i + maxDim, y: maxDim))
        }
        return path
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        AvailabilityCalendarView(
            selectedDate: .constant(Date()),
            availabilityMap: [
                Calendar.current.startOfDay(for: Date().addingTimeInterval(86400 * 2)): .unavailable,
                Calendar.current.startOfDay(for: Date().addingTimeInterval(86400 * 3)): .halfDay
            ]
        )
        .padding()
    }
}
