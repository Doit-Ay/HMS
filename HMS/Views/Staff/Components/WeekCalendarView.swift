import SwiftUI

struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    // Set of dates that have appointments (to show the dot indicator)
    var datesWithAppointments: Set<Date> = []
    
    @State private var visibleWeekStart: Date = Date()
    @State private var dotOpacity: Double = 0.0
    
    private let calendar = Calendar.current
    
    // Generate the month/year title for the currently visible week
    private var monthYearTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: visibleWeekStart)
    }
    
    // Generate 7 days for the currently visible week
    private var currentWeekDays: [Date] {
        var days: [Date] = []
        guard let startOfWeek = calendar.dateInterval(of: .weekOfMonth, for: visibleWeekStart)?.start else { return days }
        
        for i in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                days.append(day)
            }
        }
        return days
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header: Month Title & Nav Arrows
            HStack {
                Text(monthYearTitle)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                
                HStack(spacing: 20) {
                    Button(action: { shiftWeek(by: -7) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Button(action: { shiftWeek(by: 7) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            
            // Days Strip
            // Using a simple HStack wrapped in a gesture to act like Apple Calendar's snappy swipe
            HStack(spacing: 0) {
                ForEach(currentWeekDays, id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let isToday = calendar.isDateInToday(date)
                    let hasAppointments = datesWithAppointments.contains { calendar.isDate($0, inSameDayAs: date) }
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            selectedDate = date
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text(shortDayName(for: date))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(isSelected ? AppTheme.primary : AppTheme.textSecondary)
                            
                            ZStack {
                                if isSelected {
                                    Circle()
                                        .fill(AppTheme.primary)
                                        .frame(width: 36, height: 36)
                                        // "Spring bounce on teal circle"
                                        .transition(.scale)
                                } else if isToday {
                                    // "teal underline or bold ring"
                                    Circle()
                                        .stroke(AppTheme.primary, lineWidth: 2)
                                        .frame(width: 36, height: 36)
                                }
                                
                                Text(dayNumber(for: date))
                                    .font(.system(size: 16, weight: isSelected || isToday ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
                            }
                            
                            // Dot indicator
                            Circle()
                                .fill(AppTheme.primary)
                                .frame(width: 4, height: 4)
                                .opacity(hasAppointments && !isSelected ? dotOpacity : 0)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            // "Swipe between weeks: smooth horizontal slide"
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width > 50 {
                            // Swiped right -> previous week
                            shiftWeek(by: -7)
                        } else if value.translation.width < -50 {
                            // Swiped left -> next week
                            shiftWeek(by: 7)
                        }
                    }
            )
        }
        .onAppear {
            // "Dot indicators fade in after calendar renders"
            withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
                dotOpacity = 1.0
            }
            // Ensure visible week matches selected date on first load if needed
            visibleWeekStart = selectedDate
        }
    }
    
    private func shiftWeek(by days: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let newDate = calendar.date(byAdding: .day, value: days, to: visibleWeekStart) {
                visibleWeekStart = newDate
            }
        }
    }
    
    private func shortDayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private func dayNumber(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        WeekCalendarView(
            selectedDate: .constant(Date()),
            datesWithAppointments: [Date(), Calendar.current.date(byAdding: .day, value: 1, to: Date())!]
        )
    }
}
