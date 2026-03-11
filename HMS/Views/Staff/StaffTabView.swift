import SwiftUI

// MARK: - Generic Staff Tab View Builder
// Used to create tab views for Doctor, Nurse, LabTech, Pharmacist
struct StaffTabView: View {
    let role: UserRole
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            if role == .doctor {
                DoctorHomeViewController()
                    .tabItem { Label("Dashboard", systemImage: "house.fill") }
                    .tag(0)
                
                DoctorAvailabilityView()
                    .tabItem { Label("Availability", systemImage: "calendar.badge.clock") }
                    .tag(1)
                
                NavigationStack { DoctorProfileView() }
                    .tabItem { Label("Profile", systemImage: "person.circle.fill") }
                    .tag(2)
            } else {
                StaffDashboardView(role: role)
                    .tabItem { Label("Dashboard", systemImage: roleIcon) }
                    .tag(0)

                NavigationStack { ProfileView() }
                    .tabItem { Label("Profile", systemImage: "person.circle.fill") }
                    .tag(1)
            }
        }
        .tint(AppTheme.primary)
    }

    private var roleIcon: String {
        switch role {
        case .doctor:        return "stethoscope.circle.fill"
        case .nurse:         return "cross.case.fill"
        case .labTechnician: return "flask.fill"
        case .pharmacist:    return "pills.fill"
        default:             return "person.fill"
        }
    }
}

// MARK: - Staff Dashboard View (Generic)
struct StaffDashboardView: View {
    let role: UserRole
    @ObservedObject var session = UserSession.shared
    @State private var animate  = false

    var roleColor: Color {
        switch role {
        case .doctor:        return AppTheme.primary
        case .nurse:         return AppTheme.primaryMid
        case .labTechnician: return AppTheme.primaryDark
        case .pharmacist:    return Color(hex: "#4ECDC4")
        default:             return AppTheme.primary
        }
    }

    var quickActions: [(String, String)] {
        switch role {
        case .doctor:
            return [
                ("calendar.badge.clock", "My Schedule"),
                ("person.2.fill",        "Patients"),
                ("doc.text.fill",        "Prescriptions"),
                ("waveform.path.ecg",    "Reports")
            ]
        case .nurse:
            return [
                ("bell.fill",             "Patient Alerts"),
                ("cross.case.fill",       "Ward Rounds"),
                ("syringe.fill",          "Medications"),
                ("list.clipboard.fill",   "Tasks")
            ]
        case .labTechnician:
            return [
                ("flask.fill",            "Lab Tests"),
                ("doc.text.fill",         "Reports"),
                ("tray.fill",             "Samples"),
                ("chart.bar.fill",        "Results")
            ]
        case .pharmacist:
            return [
                ("pills.fill",            "Inventory"),
                ("doc.fill",              "Prescriptions"),
                ("cart.fill",             "Dispense"),
                ("clock.fill",            "Due Today")
            ]
        default:
            return []
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HMSBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Hero Card
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(role.displayName)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                                Text("Welcome back")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(session.currentUser?.fullName ?? "")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                                if let dept = session.currentUser?.department {
                                    Text(dept)
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 66, height: 66)
                                Image(systemName: role.sfSymbol)
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(24)
                        .background(
                            LinearGradient(
                                colors: [roleColor, roleColor.opacity(0.65)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .offset(y: animate ? 0 : -15)
                        .opacity(animate ? 1 : 0)

                        // If doctor — show specialization badge
                        if role == .doctor, let spec = session.currentUser?.specialization {
                            HStack(spacing: 8) {
                                Image(systemName: "stethoscope")
                                    .foregroundColor(AppTheme.primary)
                                Text(spec)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.primary)
                                Spacer()
                                if let empID = session.currentUser?.employeeID {
                                    Text("ID: \(empID)")
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.85))
                            .cornerRadius(14)
                            .padding(.horizontal, 20)
                        }

                        // Quick Actions
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Quick Actions")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, 20)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                                ForEach(quickActions, id: \.0) { action in
                                    StaffQuickAction(icon: action.0, title: action.1, color: roleColor)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .offset(y: animate ? 0 : 20)
                        .opacity(animate ? 1 : 0)

                        // Today's Summary
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Today's Summary")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)

                            HStack(spacing: 14) {
                                TodaySummaryCard(icon: "clock.fill",          value: "—", label: "Pending",  color: roleColor)
                                TodaySummaryCard(icon: "checkmark.seal.fill", value: "—", label: "Completed", color: AppTheme.success)
                            }
                        }
                        .padding(.horizontal, 20)
                        .offset(y: animate ? 0 : 20)
                        .opacity(animate ? 1 : 0)

                        Spacer(minLength: 30)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(role.displayName)
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15)) {
                animate = true
            }
        }
    }
}

// MARK: - Staff Quick Action Tile
struct StaffQuickAction: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        Button {} label: {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(color.opacity(0.13))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.white.opacity(0.85))
            .cornerRadius(18)
            .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Today Summary Card
struct TodaySummaryCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.85))
        .cornerRadius(16)
        .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    StaffTabView(role: .doctor)
}
