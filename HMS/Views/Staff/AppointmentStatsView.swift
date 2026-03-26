import SwiftUI
import FirebaseFirestore

// MARK: - Appointment Statistics View
// Pulls data from `doctor_slots` collection to show revenue and per-doctor stats.
struct AppointmentStatsView: View {
    @State private var todaySlots: [DoctorSlot] = []
    @State private var monthSlots: [DoctorSlot] = []
    @State private var isLoading = true
    @State private var selectedMonth = Date()
    @State private var animate = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showTimelinePicker = false
    @State private var showAllDoctors = false

    // Custom range state
    @State private var isCustomRange = false
    @State private var customRangeLabel = ""
    @State private var customFromDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
    @State private var customToDate = Date()

    /// Optional callback triggered when the user taps the Today's Revenue card.
    var onRevenueTap: (() -> Void)? = nil

    private let consultationFee: Int = 500

    // Formatters
    private var todayString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
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
    private var bookedToday: Int {
        todaySlots.filter { $0.status == .booked }.count
    }
    
    private var todayRevenue: Int {
        bookedToday * consultationFee
    }

    // --- Month / Range computed stats ---
    private var bookedMonth: Int {
        monthSlots.filter { $0.status == .booked }.count
    }
    
    private var monthRevenue: Int {
        bookedMonth * consultationFee
    }

    // Doctor Revenue Stats
    private var doctorRevenueStats: [(String, Int, Int)] {
        var dict: [String: Int] = [:]
        for slot in monthSlots where slot.status == .booked {
            let doc = slot.doctorName
            dict[doc, default: 0] += 1
        }
        return dict.map { ($0.key, $0.value, $0.value * consultationFee) }
            .sorted { $0.2 > $1.2 }
    }

    var body: some View {
        VStack(spacing: 20) {
            todayHeroCard
            monthPickerSection
            monthlyStatusCards
            revenuePerDoctorSection
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
        Button {
            onRevenueTap?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Revenue")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                        Text("₹\(todayRevenue)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 64, height: 64)
                        Image(systemName: "indianrupeesign.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                }
                HStack {
                    Text(displayTodayString)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    HStack(spacing: 4) {
                        Text("View Details")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
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
        }
        .buttonStyle(.plain)
        .offset(y: animate ? 0 : -20)
        .opacity(animate ? 1 : 0)
    }

    // MARK: - Month Picker
    private var monthPickerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                // Left arrow
                Button {
                    isCustomRange = false
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

                // Month label — tappable to open timeline picker
                Button {
                    showTimelinePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Text(displayMonthString)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Right arrow
                Button {
                    isCustomRange = false
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

            // Active custom range badge
            if isCustomRange {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text(customRangeLabel)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isCustomRange = false
                        }
                        Task { await loadMonthData() }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.primary.opacity(0.6))
                    }
                }
                .foregroundColor(AppTheme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.primary.opacity(0.08))
                .cornerRadius(16)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.spring(response: 0.3), value: isCustomRange)
        .sheet(isPresented: $showTimelinePicker) {
            CustomTimelineSheet(
                fromDate: $customFromDate,
                toDate: $customToDate,
                onApply: { label in
                    customRangeLabel = label
                    isCustomRange = true
                    showTimelinePicker = false
                    Task { await loadCustomRangeData() }
                },
                onCancel: {
                    showTimelinePicker = false
                }
            )
        }
    }

    // MARK: - Monthly Status Cards
    private var monthlyStatusCards: some View {
        HStack(spacing: 16) {
            MiniStatCard(
                icon: "chart.line.uptrend.xyaxis.circle.fill",
                label: isCustomRange ? "Period Revenue" : "Monthly Revenue",
                value: "₹\(monthRevenue)",
                color: AppTheme.success
            )
            MiniStatCard(
                icon: "person.fill.checkmark",
                label: "Total Bookings",
                value: "\(bookedMonth)",
                color: Color(hex: "#6366F1")
            )
        }
        .padding(.horizontal, 20)
        .offset(y: animate ? 0 : 20)
        .opacity(animate ? 1 : 0)
    }

    // MARK: - Revenue per Doctor Section
    private var revenuePerDoctorSection: some View {
        let stats = doctorRevenueStats
        let visibleStats = Array(stats.prefix(3))

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Revenue per Doctor")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                if stats.count > 3 {
                    NavigationLink {
                        AllDoctorRevenueView(doctorStats: stats)
                    } label: {
                        Text("See all")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.primary)
                    }
                }
            }
            .padding(.horizontal, 20)

            if stats.isEmpty {
                emptyStatsPlaceholder(message: isCustomRange ? "No bookings in this period" : "No bookings for this month")
            } else {
                VStack(spacing: 10) {
                    ForEach(visibleStats, id: \.0) { stat in
                        DoctorRevenueRow(
                            doctorName: stat.0,
                            bookingsCount: stat.1,
                            revenue: stat.2
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .offset(y: animate ? 0 : 30)
        .opacity(animate ? 1 : 0)
    }

    // MARK: - Helpers

    private func getMonthRange() -> (String, String) {
        let calendar = Calendar.current
        
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        return (formatter.string(from: start), formatter.string(from: end))
    }

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

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        do {
            async let today = AuthManager.shared.fetchAllSlots(forDate: todayString)
            async let month: [DoctorSlot] = {
                let (from, to) = getMonthRange()
                let db = Firestore.firestore()
                
                let snapshot = try await db.collection("doctor_slots")
                    .whereField("date", isGreaterThanOrEqualTo: from)
                    .whereField("date", isLessThanOrEqualTo: to)
                    .getDocuments()

                return snapshot.documents.compactMap {
                    try? Firestore.Decoder().decode(DoctorSlot.self, from: $0.data())
                }
            }()
            todaySlots = try await today
            monthSlots = try await month
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }

    private func loadMonthData() async {
    let (from, to) = getMonthRange()
    
    do {
        let db = Firestore.firestore()
        let snapshot = try await db.collection("doctor_slots")
            .whereField("date", isGreaterThanOrEqualTo: from)
                .whereField("date", isLessThanOrEqualTo: to)
                .getDocuments()

            let slots = snapshot.documents.compactMap {
                try? Firestore.Decoder().decode(DoctorSlot.self, from: $0.data())
            }

            await MainActor.run {
                monthSlots = slots
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func loadCustomRangeData() async {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let from = fmt.string(from: customFromDate)
        let to = fmt.string(from: customToDate)
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("doctor_slots")
                .whereField("date", isGreaterThanOrEqualTo: from)
                .whereField("date", isLessThanOrEqualTo: to)
                .getDocuments()
            let slots = snapshot.documents.compactMap {
                try? Firestore.Decoder().decode(DoctorSlot.self, from: $0.data())
            }
            await MainActor.run { monthSlots = slots }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Custom Timeline Sheet
struct CustomTimelineSheet: View {
    @Binding var fromDate: Date
    @Binding var toDate: Date
    let onApply: (String) -> Void
    let onCancel: () -> Void

    @State private var selectedPreset: String? = nil
    @State private var showCustomRange = false

    private let presets: [(label: String, icon: String, months: Int)] = [
        ("Last 3 Months",  "3.circle.fill",       3),
        ("Last 6 Months",  "6.circle.fill",       6),
        ("Last 1 Year",    "arrow.counterclockwise.circle.fill", 12),
        ("Year to Date",   "calendar.circle.fill", 0),
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Presets
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Select")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, 4)

                        ForEach(presets, id: \.label) { preset in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    if selectedPreset == preset.label {
                                        selectedPreset = nil
                                    } else {
                                        selectedPreset = preset.label
                                        showCustomRange = false
                                        applyPreset(preset)
                                    }
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(selectedPreset == preset.label ? AppTheme.primary : AppTheme.primary.opacity(0.1))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: preset.icon)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(selectedPreset == preset.label ? .white : AppTheme.primary)
                                    }
                                    Text(preset.label)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                }
                                .padding(14)
                                .background(
                                    selectedPreset == preset.label
                                        ? AppTheme.primary.opacity(0.08)
                                        : AppTheme.cardSurface
                                )
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selectedPreset == preset.label ? AppTheme.primary.opacity(0.3) : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Divider
                    HStack {
                        Rectangle().fill(AppTheme.separator).frame(height: 1)
                        Text("OR")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                        Rectangle().fill(AppTheme.separator).frame(height: 1)
                    }
                    .padding(.vertical, 4)

                    // Custom Range
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showCustomRange.toggle()
                                if showCustomRange { selectedPreset = nil }
                            }
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(showCustomRange ? AppTheme.primary : AppTheme.primary.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "calendar.badge.plus")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(showCustomRange ? .white : AppTheme.primary)
                                }
                                Text("Custom Range")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Image(systemName: showCustomRange ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .padding(14)
                            .background(
                                showCustomRange
                                    ? AppTheme.primary.opacity(0.08)
                                    : AppTheme.cardSurface
                            )
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)

                        if showCustomRange {
                            VStack(spacing: 14) {
                                DatePicker("From", selection: $fromDate, displayedComponents: .date)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .tint(AppTheme.primary)

                                DatePicker("To", selection: $toDate, displayedComponents: .date)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .tint(AppTheme.primary)
                            }
                            .padding(16)
                            .background(AppTheme.cardSurface)
                            .cornerRadius(14)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                }
                .padding(20)
            }
            .navigationTitle("Custom Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color(uiColor: .label))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if showCustomRange {
                            let fmt = DateFormatter()
                            fmt.dateFormat = "MMM yyyy"
                            let label = "\(fmt.string(from: fromDate)) – \(fmt.string(from: toDate))"
                            onApply(label)
                        } else if let preset = selectedPreset {
                            onApply(preset)
                        }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor((selectedPreset != nil || showCustomRange) ? AppTheme.primary : Color(uiColor: .quaternaryLabel))
                    }
                    .disabled(selectedPreset == nil && !showCustomRange)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func applyPreset(_ preset: (label: String, icon: String, months: Int)) {
        let now = Date()
        if preset.months == 0 {
            // Year to Date
            let year = Calendar.current.component(.year, from: now)
            fromDate = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))!
            toDate = now
        } else {
            let calendar = Calendar.current

            // Start of current month
            let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

            // Go back N months
            fromDate = calendar.date(byAdding: .month, value: -preset.months, to: currentMonthStart)!

            // End = end of current month (NOT today)
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonthStart)!
            toDate = calendar.date(byAdding: .day, value: -1, to: nextMonth)!
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
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: color.opacity(0.1), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Doctor Revenue Row
struct DoctorRevenueRow: View {
    let doctorName: String
    let bookingsCount: Int
    let revenue: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.primary.opacity(0.15), AppTheme.primary.opacity(0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Text(doctorName.prefix(1).uppercased())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Dr. \(doctorName)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                Text("\(bookingsCount) \(bookingsCount == 1 ? "Booking" : "Bookings")")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Text("₹\(revenue)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.primaryDark)
        }
        .padding(16)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

// MARK: - All Doctor Revenue View
struct AllDoctorRevenueView: View {
    let doctorStats: [(String, Int, Int)] // (name, bookings, revenue)
    @State private var searchText = ""

    private var filteredStats: [(String, Int, Int)] {
        if searchText.isEmpty { return doctorStats }
        return doctorStats.filter {
            $0.0.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            if filteredStats.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.primaryMid.opacity(0.4))
                    Text("No doctors found")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredStats, id: \.0) { stat in
                            DoctorRevenueRow(
                                doctorName: stat.0,
                                bookingsCount: stat.1,
                                revenue: stat.2
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle("All Doctors")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search doctors")
    }
}

#Preview {
    AppointmentStatsView()
}
