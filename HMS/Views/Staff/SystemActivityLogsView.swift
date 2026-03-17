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
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.textSecondary)
                        TextField("Search logs...", text: $viewModel.searchText)
                            .font(.system(size: 15, design: .rounded))
                        
                        if !viewModel.searchText.isEmpty {
                            Button {
                                viewModel.searchText = ""
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
        HStack(alignment: .top, spacing: 14) {
            // Icon Background
            ZStack {
                Circle()
                    .fill(actionColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Image(systemName: actionIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(actionColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(log.action)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Spacer()
                    
                    Text(timeString)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                if let details = log.details, !details.isEmpty {
                    Text(details)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                        .foregroundColor(roleColor)
                    
                    Text("\(log.userName) (\(log.userRole.displayName))")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(roleColor)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(roleColor.opacity(0.08))
                .cornerRadius(6)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}
