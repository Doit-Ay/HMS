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

    private let consultationFee: Int = 500

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
    private var bookedToday: Int {
        todaySlots.filter { $0.status == .booked }.count
    }
    
    private var todayRevenue: Int {
        bookedToday * consultationFee
    }

    // --- Month computed stats ---
    private var bookedMonth: Int {
        monthSlots.filter { $0.status == .booked }.count
    }
    
    private var monthRevenue: Int {
        bookedMonth * consultationFee
    }

    // Doctor Revenue Stats
    private var doctorRevenueStats: [(String, Int, Int)] {
        // Returns [(DoctorName, BookingCount, Revenue)]
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
            // Today's Overview Hero
            todayHeroCard

            // Month Picker
            monthPickerSection

            // Monthly Status Cards
            monthlyStatusCards

            // Revenue per Doctor Section
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

    // MARK: - Monthly Status Cards
    private var monthlyStatusCards: some View {
        HStack(spacing: 16) {
            MiniStatCard(
                icon: "chart.line.uptrend.xyaxis.circle.fill",
                label: "Monthly Revenue",
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
        VStack(alignment: .leading, spacing: 14) {
            Text("Revenue per Doctor")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, 20)

            if doctorRevenueStats.isEmpty {
                emptyStatsPlaceholder(message: "No bookings for this month")
            } else {
                VStack(spacing: 12) {
                    ForEach(doctorRevenueStats, id: \.0) { stat in
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
// Helper for displaying smaller stats
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
// Custom row displaying individual doctor's revenue
struct DoctorRevenueRow: View {
    let doctorName: String
    let bookingsCount: Int
    let revenue: Int

    var body: some View {
        HStack(spacing: 14) {
            // Initials avatar
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.1))
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

#Preview {
    AppointmentStatsView()
}
