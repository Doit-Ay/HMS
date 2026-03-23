import SwiftUI
import FirebaseFirestore

// MARK: - Appointment Statistics View
// Pulls data from `doctor_slots` collection to show real slot stats.
struct AppointmentStatsView: View {
    @State private var todaySlots: [DoctorSlot] = []
    @State private var monthSlots: [DoctorSlot] = []
    @State private var isLoading = true
    @State private var selectedMonth = Date()
    @State private var animate = false
    @State private var errorMessage = ""
    @State private var showError = false

    // Formatters
    private var todayString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var monthString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"
        return f.string(from: selectedMonth)
    }

    private var displayMonthString: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: selectedMonth)
    }

    private var displayTodayString: String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: Date())
    }

    // --- Today computed stats ---
    private var todayCount: Int { todaySlots.count }

    private var availableToday: Int {
        todaySlots.filter { $0.status == .available }.count
    }
    private var unavailableToday: Int {
        todaySlots.filter { $0.status == .unavailable }.count
    }
    private var bookedToday: Int {
        todaySlots.filter { $0.status == .booked }.count
    }

    // --- Month computed stats ---
    private var monthCount: Int { monthSlots.count }

    private var availableMonth: Int {
        monthSlots.filter { $0.status == .available }.count
    }
    private var unavailableMonth: Int {
        monthSlots.filter { $0.status == .unavailable }.count
    }
    private var bookedMonth: Int {
        monthSlots.filter { $0.status == .booked }.count
    }

    // Department-wise for current month
    private var departmentStats: [(String, Int)] {
        var dict: [String: Int] = [:]
        for slot in monthSlots {
            let dept = slot.department ?? "Unknown"
            dict[dept, default: 0] += 1
        }
        return dict.sorted { $0.value > $1.value }
    }

    // Daily breakdown for current month (for the bar chart)
    private var dailyStats: [(String, Int)] {
        var dict: [String: Int] = [:]
        for slot in monthSlots {
            dict[slot.date, default: 0] += 1
        }
        return dict.sorted { $0.0 < $1.0 }
    }

    // Status breakdown for month (for donut chart)
    private var monthStatusBreakdown: [(String, Int, Color)] {
        return [
            ("Available", availableMonth, AppTheme.success),
            ("Unavailable", unavailableMonth, AppTheme.warning),
            ("Booked", bookedMonth, Color(hex: "#6366F1"))
        ]
    }

    var body: some View {
        VStack(spacing: 20) {
            // Today's Overview Hero
            todayHeroCard

            // Today Status Breakdown
            todayStatusCards

            // Month Picker
            monthPickerSection

            // Monthly Summary
            monthlySummaryCard

            // Daily Bar Chart
            dailyChartSection

            // Monthly Status Donut
            monthlyStatusSection
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            await loadData()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animate = true
            }
        }
    }

    // MARK: - Today Hero Card
    private var todayHeroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Doctors")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    Text("\(todayCount)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 64, height: 64)
                    Image(systemName: "stethoscope")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
            }
            Text(displayTodayString)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [AppTheme.dashboardCardGradientStart, AppTheme.dashboardCardGradientEnd],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .offset(y: animate ? 0 : -20)
        .opacity(animate ? 1 : 0)
    }

    // MARK: - Today Status Cards
    private var todayStatusCards: some View {
        HStack(spacing: 12) {
            MiniStatCard(
                icon: "checkmark.circle.fill",
                label: "Available",
                value: "\(availableToday)",
                color: AppTheme.success
            )
            MiniStatCard(
                icon: "xmark.circle.fill",
                label: "Unavailable",
                value: "\(unavailableToday)",
                color: AppTheme.warning
            )
            MiniStatCard(
                icon: "person.fill.checkmark",
                label: "Booked",
                value: "\(bookedToday)",
                color: Color(hex: "#6366F1")
            )
        }
        .padding(.horizontal, 20)
        .offset(y: animate ? 0 : 20)
        .opacity(animate ? 1 : 0)
    }

    // MARK: - Month Picker
    private var monthPickerSection: some View {
        HStack {
            Button {
                withAnimation {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth)!
                }
                Task { await loadMonthData() }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(AppTheme.primary)
            }

            Spacer()

            Text(displayMonthString)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Button {
                withAnimation {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth)!
                }
                Task { await loadMonthData() }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(AppTheme.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Monthly Summary Card
    private var monthlySummaryCard: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("\(monthCount)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primary)
                Text("Total Slots")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Rectangle()
                .fill(AppTheme.primaryMid.opacity(0.3))
                .frame(width: 1, height: 40)

            VStack(spacing: 4) {
                Text("\(departmentStats.count)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryMid)
                Text("Departments")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Rectangle()
                .fill(AppTheme.primaryMid.opacity(0.3))
                .frame(width: 1, height: 40)

            VStack(spacing: 4) {
                let avgPerDay = dailyStats.isEmpty ? 0 : monthCount / max(dailyStats.count, 1)
                Text("\(avgPerDay)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryDark)
                Text("Avg/Day")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AppTheme.cardSurface)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 20)
    }



    // MARK: - Daily Bar Chart
    private var dailyChartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily Trend")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, 20)

            if dailyStats.isEmpty {
                emptyStatsPlaceholder(message: "No daily data for this month")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 6) {
                        let maxVal = dailyStats.map(\.1).max() ?? 1
                        ForEach(dailyStats, id: \.0) { day in
                            DailyBarView(
                                date: day.0,
                                count: day.1,
                                maxCount: maxVal,
                                animate: animate
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .frame(height: 180)
                .background(AppTheme.cardSurface)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Monthly Status Donut
    private var monthlyStatusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Status Breakdown")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, 20)

            if monthCount == 0 {
                emptyStatsPlaceholder(message: "No status data for this month")
            } else {
                HStack(spacing: 20) {
                    // Donut Chart
                    ZStack {
                        ForEach(Array(monthStatusBreakdown.enumerated()), id: \.offset) { index, item in
                            let total = Double(monthCount)
                            let value = Double(item.1)
                            let startAngle = startAngle(for: index)
                            let endAngle = startAngle + Angle(degrees: (value / max(total, 1)) * 360)

                            DonutSlice(startAngle: startAngle, endAngle: endAngle, thickness: 20)
                                .fill(item.2)
                        }

                        VStack(spacing: 2) {
                            Text("\(monthCount)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("Total")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .frame(width: 110, height: 110)

                    // Legend
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(monthStatusBreakdown, id: \.0) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.2)
                                    .frame(width: 10, height: 10)
                                Text(item.0)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                                Spacer()
                                Text("\(item.1)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }
                    }
                }
                .padding(20)
                .background(AppTheme.cardSurface)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Helpers

    private func emptyStatsPlaceholder(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 36))
                .foregroundColor(AppTheme.primaryMid.opacity(0.4))
            Text(message)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(AppTheme.cardSurface)
        .cornerRadius(18)
        .padding(.horizontal, 20)
    }

    private func departmentColor(index: Int) -> Color {
        let colors: [Color] = [
            AppTheme.primary,
            Color(hex: "#6366F1"),
            AppTheme.warning,
            AppTheme.primaryMid,
            AppTheme.primaryDark,
            Color(hex: "#EC4899")
        ]
        return colors[index % colors.count]
    }

    private func startAngle(for index: Int) -> Angle {
        let total = Double(monthCount)
        var angle = -90.0
        for i in 0..<index {
            let val = Double(monthStatusBreakdown[i].1)
            angle += (val / max(total, 1)) * 360
        }
        return Angle(degrees: angle)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        do {
            async let today = AuthManager.shared.fetchAllSlots(forDate: todayString)
            async let month = AuthManager.shared.fetchAllSlots(forMonth: monthString)
            todaySlots = try await today
            monthSlots = try await month
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }

    private func loadMonthData() async {
        do {
            monthSlots = try await AuthManager.shared.fetchAllSlots(forMonth: monthString)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Mini Stat Card
struct MiniStatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: color.opacity(0.1), radius: 6, x: 0, y: 3)
    }
}



// MARK: - Daily Bar View
struct DailyBarView: View {
    let date: String
    let count: Int
    let maxCount: Int
    let animate: Bool

    private var dayLabel: String {
        String(date.suffix(2))
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)

            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryMid],
                        startPoint: .bottom, endPoint: .top
                    )
                )
                .frame(
                    width: 22,
                    height: animate ? max(CGFloat(count) / CGFloat(max(maxCount, 1)) * 110, 4) : 4
                )
                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: animate)

            Text(dayLabel)
                .font(.system(size: 9, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}

// MARK: - Donut Slice Shape
struct DonutSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var thickness: CGFloat = 20

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius - thickness

        var path = Path()
        path.addArc(center: center, radius: outerRadius,
                    startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius,
                    startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}

#Preview {
    AppointmentStatsView()
}
