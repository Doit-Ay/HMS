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
        }
        .tint(AppTheme.primary)
    }
}

// MARK: - Admin Dashboard View
struct AdminDashboardView: View {
    @ObservedObject var session = UserSession.shared
    @State private var animate    = false

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good Morning,"
        case 12..<17: return "Good Afternoon,"
        case 17..<21: return "Good Evening,"
        default:       return "Good Night,"
        }
    }

    private var adminName: String {
        session.currentUser?.fullName ?? "Admin"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HMSBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Hero Card (Patient-style)
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 4) {
                                    Text(greetingText)
                                    if greetingText.contains("Morning") {
                                        Text("☀️")
                                    } else if greetingText.contains("Afternoon") {
                                        Text("👋")
                                    } else {
                                        Text("🌙")
                                    }
                                }
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                                
                                Text(adminName)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text("Manage your hospital staff")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            Spacer()
                            NavigationLink(destination: ProfileView()) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 54, height: 54)
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(24)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.primary, AppTheme.primaryMid],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                        // Manage Slots Card
                        NavigationLink(destination: ManageSlotsView()) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.primary.opacity(0.12))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 22))
                                        .foregroundColor(AppTheme.primary)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Manage Slots")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("Update doctor availability & time slots")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                            }
                            .padding(18)
                            .background(Color.white.opacity(0.85))
                            .cornerRadius(18)
                            .shadow(color: AppTheme.primary.opacity(0.08), radius: 8, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)

                        Spacer(minLength: 30)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.large)
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

    var filteredStaff: [HMSUser] {
        if searchText.isEmpty { return staffList }
        return staffList.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText) ||
            $0.role.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HMSBackground()

                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.textSecondary)
                        TextField("Search staff...", text: $searchText)
                            .font(.system(size: 15, design: .rounded))
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(14)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    if isLoading {
                        Spacer()
                        ProgressView("Loading staff...")
                            .tint(AppTheme.primary)
                        Spacer()
                    } else if filteredStaff.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "person.3")
                                .font(.system(size: 48))
                                .foregroundColor(AppTheme.primaryMid.opacity(0.4))
                            Text(searchText.isEmpty ? "No staff added yet" : "No results found")
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredStaff) { staff in
                                 StaffRowView(
                                     staff: staff,
                                     onUpdate: { fetchStaff() },
                                     onDeactivate: { deactivate(staff) },
                                     onReactivate: { reactivate(staff) }
                                 )
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Staff Management")
            .navigationBarTitleDisplayMode(.large)
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
            .task { fetchStaff() }
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

    var body: some View {
        Button {
            showEdit = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: staff.role.sfSymbol)
                        .font(.system(size: 22))
                        .foregroundColor(AppTheme.primary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(staff.fullName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(staff.role.displayName)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    if let dept = staff.department {
                        Text(dept)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(AppTheme.primaryMid)
                    }
                }
                
                Spacer()

                if staff.isActive {
                    Text("Active")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.primary.opacity(0.1))
                        .cornerRadius(20)
                } else {
                    Text("Inactive")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(20)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary.opacity(0.4))
            }
            .padding(16)
            .background(Color.white.opacity(0.8))
            .cornerRadius(16)
            .shadow(color: AppTheme.primary.opacity(0.06), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
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
