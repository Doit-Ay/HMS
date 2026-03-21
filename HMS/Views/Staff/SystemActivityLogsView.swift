import SwiftUI

struct SystemActivityLogsView: View {
    @StateObject private var viewModel = SystemActivityLogsViewModel()
    @State private var animate = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                HMSBackground()
                
                VStack(spacing: 0) {
                    // Search bar
                    HMSSearchBar(placeholder: "Search logs...", text: $viewModel.searchText) {
                        Menu {
                            Section("Time Period") {
                                Picker("Time Filter", selection: $viewModel.timeFilter) {
                                    ForEach(LogTimeFilter.allCases, id: \.self) { filter in
                                        Text(filter.rawValue).tag(filter)
                                    }
                                }
                            }
                            
                            Section("Action Type") {
                                Picker("Action Filter", selection: $viewModel.actionFilter) {
                                    ForEach(LogActionFilter.allCases, id: \.self) { filter in
                                        Text(filter.rawValue).tag(filter)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: viewModel.hasActiveAdvancedFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.system(size: 20))
                                .foregroundColor(viewModel.hasActiveAdvancedFilters ? AppTheme.primary : AppTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Filter Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.availableRoles, id: \.self) { role in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        viewModel.filterRole = role
                                    }
                                } label: {
                                    Text(role)
                                        .font(.system(size: 14, weight: viewModel.filterRole == role ? .semibold : .medium, design: .rounded))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(viewModel.filterRole == role ? AppTheme.primary : Color.white)
                                        .foregroundColor(viewModel.filterRole == role ? .white : AppTheme.textSecondary)
                                        .clipShape(Capsule())
                                        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    
                    if viewModel.isLoading && viewModel.logs.isEmpty {
                        Spacer()
                        ProgressView("Loading logs...")
                            .tint(AppTheme.primary)
                        Spacer()
                    } else if viewModel.filteredLogs.isEmpty {
                        Spacer()
                        VStack(spacing: 14) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 44))
                                .foregroundColor(AppTheme.primaryMid.opacity(0.3))
                            Text(viewModel.searchText.isEmpty ? "No activity logs found" : "No results for search")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(viewModel.filteredLogs.enumerated()), id: \.element.id) { index, log in
                                    ActivityLogCard(log: log)
                                        .offset(y: animate ? 0 : 20)
                                        .opacity(animate ? 1 : 0)
                                        .animation(
                                            .spring(response: 0.45, dampingFraction: 0.8)
                                            .delay(Double(min(index, 20)) * 0.04),
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
            .navigationTitle("Activity Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.fetchLogs()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AppTheme.primary)
                    }
                }
            }
            .onAppear {
                viewModel.fetchLogs()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        animate = true
                    }
                }
            }
            .alert("Error", isPresented: Binding<Bool>(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
        }
    }
}

// MARK: - Activity Log Card Component
struct ActivityLogCard: View {
    let log: SystemActivityLog
    
    // Icon mapping based on action keywords
    private var actionIcon: String {
        let text = log.action.lowercased()
        if text.contains("login") { return "arrow.right.circle.fill" }
        if text.contains("logout") { return "arrow.left.circle.fill" }
        if text.contains("add") || text.contains("register") { return "person.badge.plus" }
        if text.contains("deactivate") { return "person.badge.minus" }
        if text.contains("update") { return "person.crop.circle.badge.exclamationmark" }
        return "list.bullet.rectangle"
    }
    
    // Color mapping
    private var actionColor: Color {
        let text = log.action.lowercased()
        if text.contains("deactivate") { return .red }
        if text.contains("add") || text.contains("register") { return .green }
        if text.contains("login") { return .blue }
        if text.contains("logout") { return .orange }
        return AppTheme.primary
    }
    
    private var roleColor: Color {
        switch log.userRole {
        case .admin: return .red
        case .doctor: return AppTheme.primary
        case .labTechnician: return Color(hex: "#8B5CF6")
        default: return AppTheme.textSecondary
        }
    }
    
    // Relative time formatting
    private var timeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: log.timestamp, relativeTo: Date())
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Icon Background
            ZStack {
                Circle()
                    .fill(actionColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Image(systemName: actionIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(actionColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(log.action)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                
                HStack(spacing: 4) {
                    Text(log.userName)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    
                    // Small dot separator
                    Circle()
                        .fill(AppTheme.textSecondary.opacity(0.4))
                        .frame(width: 3, height: 3)
                    
                    Text(log.userRole.displayName)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(roleColor)
                }
            }
            
            Spacer()
            
            Text(timeString)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(AppTheme.textSecondary.opacity(0.8))
                .padding(.trailing, 2)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
}
