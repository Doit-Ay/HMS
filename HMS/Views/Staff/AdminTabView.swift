import SwiftUI
import FirebaseFirestore

// MARK: - Admin Tab View
struct AdminTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            AdminDashboardView()
                .tabItem { Label("Dashboard", systemImage: "shield.checkered") }
                .tag(0)

            StaffManagementView()
                .tabItem { Label("Staff", systemImage: "person.3.fill") }
                .tag(1)

            AppointmentStatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(2)
                
            SystemActivityLogsView()
                .tabItem { Label("Logs", systemImage: "list.bullet.rectangle") }
                .tag(3)
        }
        .tint(AppTheme.primary)
    }
}

// MARK: - Admin Dashboard View
struct AdminDashboardView: View {
    @ObservedObject var session = UserSession.shared
    @State private var animate    = false
    @State private var showProfileSheet = false

    private var adminName: String {
        session.currentUser?.fullName ?? "Admin"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                HMSBackground()

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.primaryLight.opacity(0.8), AppTheme.primaryLight.opacity(0.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: -100, y: -200)
                    .blur(radius: 60)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Patient-style Header
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(Date().formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.primary)
                                    .textCase(.uppercase)

                                HStack(spacing: 6) {
                                    Text("Hi,")
                                        .font(.system(size: 28, weight: .regular, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)

                                    Text(adminName.components(separatedBy: " ").first ?? "Admin")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                            }

                            Spacer()

                            // Profile Button — opens as bottom sheet
                            Button {
                                showProfileSheet = true
                            } label: {
                                ZStack {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(AppTheme.primaryDark)
                                        .background(Circle().fill(AppTheme.primaryLight))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .offset(y: animate ? 0 : -30)
                        .opacity(animate ? 1 : 0)

                        // Hero Banner with Manage Slots button inside
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Hospital\nManagement")
                                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineSpacing(4)

                                    Text("Manage your staff, appointments and hospital operations.")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.9))
                                        .padding(.trailing, 40)
                                }
                                Spacer()
                            }
                            .padding(24)

                            NavigationLink(destination: ManageSlotsView()) {
                                HStack {
                                    Text("Manage Slots")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))

                                    Spacer()

                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 24))
                                }
                                .foregroundColor(AppTheme.primary)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(16)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 24)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(
                            ZStack {
                                LinearGradient(
                                    colors: [AppTheme.primary, AppTheme.primaryMid],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                Image(systemName: "shield.checkered")
                                    .font(.system(size: 180))
                                    .foregroundColor(.white.opacity(0.1))
                                    .offset(x: 100, y: 20)
                                    .rotationEffect(.degrees(-15))
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .shadow(color: AppTheme.primary.opacity(0.25), radius: 20, x: 0, y: 10)
                        .padding(.horizontal, 20)
                        .offset(y: animate ? 0 : 30)
                        .opacity(animate ? 1 : 0)

                        Spacer(minLength: 30)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showProfileSheet) {
                ProfileView()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animate = true
            }
        }
    }
}

// MARK: - Admin Stat Card
struct AdminStatCard: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.85))
        .cornerRadius(18)
        .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Staff Management View
struct StaffManagementView: View {
    @State private var staffList: [HMSUser] = []
    @State private var isLoading = true
    @State private var showAddStaff = false
    @State private var searchText   = ""
    @State private var errorMessage = ""
    @State private var showError    = false
    @State private var animate = false

    var filteredStaff: [HMSUser] {
        if searchText.isEmpty { return staffList }
        return staffList.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText) ||
            $0.role.displayName.localizedCaseInsensitiveContains(searchText) ||
            ($0.department ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HMSBackground()

                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.textSecondary)
                        TextField("Search by name, role or department...", text: $searchText)
                            .font(.system(size: 15, design: .rounded))

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                    // Staff count header
                    if !isLoading && !staffList.isEmpty {
                        HStack {
                            Text(searchText.isEmpty ? "All Staff" : "Results")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("(\(filteredStaff.count))")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }

                    if isLoading {
                        Spacer()
                        ProgressView("Loading staff...")
                            .tint(AppTheme.primary)
                        Spacer()
                    } else if filteredStaff.isEmpty {
                        Spacer()
                        VStack(spacing: 14) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 44))
                                .foregroundColor(AppTheme.primaryMid.opacity(0.3))
                            Text(searchText.isEmpty ? "No staff added yet" : "No results found")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                            if searchText.isEmpty {
                                Text("Tap + to add your first staff member")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                            }
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 10) {
                                ForEach(Array(filteredStaff.enumerated()), id: \.element.id) { index, staff in
                                    StaffRowView(
                                        staff: staff,
                                        onUpdate: { fetchStaff() },
                                        onDeactivate: { deactivate(staff) },
                                        onReactivate: { reactivate(staff) }
                                    )
                                    .offset(y: animate ? 0 : 20)
                                    .opacity(animate ? 1 : 0)
                                    .animation(
                                        .spring(response: 0.45, dampingFraction: 0.8)
                                        .delay(Double(index) * 0.04),
                                        value: animate
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationTitle("Staff Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddStaff = true
                    } label: {
                        Image(systemName: "person.badge.plus.fill")
                            .foregroundColor(AppTheme.primary)
                            .font(.system(size: 20))
                    }
                }
            }
            .sheet(isPresented: $showAddStaff) {
                AddStaffView { fetchStaff() }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task {
                fetchStaff()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        animate = true
                    }
                }
            }
        }
    }

    private func fetchStaff() {
        isLoading = true
        Task {
            do {
                let list = try await AuthManager.shared.fetchStaffMembers()
                withAnimation(.spring()) {
                    staffList = list
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }

    private func deactivate(_ staff: HMSUser) {
        Task {
            do {
                try await AuthManager.shared.deactivateStaff(uid: staff.id)
                fetchStaff()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func reactivate(_ staff: HMSUser) {
        Task {
            do {
                try await AuthManager.shared.reactivateStaff(uid: staff.id)
                fetchStaff()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Staff Row View
struct StaffRowView: View {
    let staff: HMSUser
    let onUpdate: () -> Void
    let onDeactivate: () -> Void
    let onReactivate: () -> Void
    @State private var showEdit = false

    private var initials: String {
        let parts = staff.fullName.components(separatedBy: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        return String(staff.fullName.prefix(2)).uppercased()
    }

    private var roleColor: Color {
        switch staff.role {
        case .doctor: return AppTheme.primary
        case .labTechnician: return Color(hex: "#8B5CF6")
        default: return AppTheme.textSecondary
        }
    }

    var body: some View {
        Button {
            showEdit = true
        } label: {
            HStack(spacing: 14) {
                // Initials avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [roleColor.opacity(0.2), roleColor.opacity(0.1)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    Text(initials)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(roleColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(staff.fullName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    HStack(spacing: 6) {
                        // Role badge
                        Text(staff.role.displayName)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(roleColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(roleColor.opacity(0.1))
                            .cornerRadius(8)

                        if let dept = staff.department, dept != "Not Set" {
                            Text(dept)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                
                Spacer()

                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(staff.isActive ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(staff.isActive ? "Active" : "Inactive")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(staff.isActive ? Color.green : AppTheme.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary.opacity(0.4))
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEdit) {
            EditStaffView(
                staff: staff,
                onDeactivate: { onDeactivate() },
                onReactivate: { onReactivate() },
                onUpdate: { onUpdate() }
            )
        }
    }
}
