import SwiftUI
import FirebaseFirestore

// MARK: - Admin Tab View
struct AdminTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            AdminDashboardView()
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2.fill") }
                .tag(0)

            StaffManagementView()
                .tabItem { Label("Staff", systemImage: "person.3.fill") }
                .tag(1)
                
            SystemActivityLogsView()
                .tabItem { Label("Logs", systemImage: "list.bullet.rectangle") }
                .tag(2)

            InventoryManagementView()
                .tabItem { Label("Inventory", systemImage: "cross.case.fill") }
                .tag(3)

            AdminInvoiceListView()
                .tabItem { Label("Billing", systemImage: "doc.text.fill") }
                .tag(4)
        }
        .tint(AppTheme.primary)
    }
}

// MARK: - Admin Dashboard View
struct AdminDashboardView: View {
    @ObservedObject var session = UserSession.shared
    @State private var animate    = false
    @State private var showProfileSheet = false
    @State private var navigateToFinancials = false

    private var adminName: String {
        session.currentUser?.fullName ?? "Admin"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

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

                        // Action Cards Area
                        VStack(spacing: 16) {
                            HStack {
                                Text("Quick Actions")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 24)

                            NavigationLink(destination: ManageSlotsView()) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(AppTheme.primary.opacity(0.15))
                                            .frame(width: 50, height: 50)
                                        Image(systemName: "calendar.badge.clock")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundColor(AppTheme.primary)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Manage Slots")
                                            .font(.system(size: 17, weight: .bold, design: .rounded))
                                            .foregroundColor(AppTheme.textPrimary)
                                        Text("Schedule and organize doctor availability")
                                            .font(.system(size: 13, design: .rounded))
                                            .foregroundColor(AppTheme.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                                }
                                .padding(16)
                                .background(AppTheme.cardSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }
                        .offset(y: animate ? 0 : 20)
                        .opacity(animate ? 1 : 0)

                        // Embedded Statistics
                        VStack(spacing: 16) {
                            HStack {
                                Text("Revenue Overview")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            
                            AppointmentStatsView(onRevenueTap: {
                                navigateToFinancials = true
                            })
                        }
                        .offset(y: animate ? 0 : 30)
                        .opacity(animate ? 1 : 0)

                        Spacer(minLength: 30)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToFinancials) {
                AdminRevenueDashboardView()
            }
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
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    HMSSearchBar(placeholder: "Search by name, role or department...", text: $searchText)
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
            .background(AppTheme.cardSurface)
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
