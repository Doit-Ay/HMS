import Foundation
import Combine

enum LogTimeFilter: String, CaseIterable {
    case allTime = "All Time"
    case today = "Today"
    case last7Days = "Last 7 Days"
    case last30Days = "Last 30 Days"
}

enum LogActionFilter: String, CaseIterable {
    case all = "All Actions"
    case auth = "Authentication"
    case modifications = "Modifications"
    case deactivations = "Deactivations"
}

@MainActor
class SystemActivityLogsViewModel: ObservableObject {
    @Published var logs: [SystemActivityLog] = []
    @Published var isLoading: Bool = false
    @Published var searchText: String = ""
    @Published var filterRole: String = "All"
    @Published var timeFilter: LogTimeFilter = .allTime
    @Published var actionFilter: LogActionFilter = .all
    @Published var errorMessage: String? = nil
    
    let availableRoles = ["All", "Admin", "Doctor", "Lab Technician"]
    
    var hasActiveAdvancedFilters: Bool {
        return timeFilter != .allTime || actionFilter != .all
    }
    
    var filteredLogs: [SystemActivityLog] {
        var result = logs
        
        // 1. Time Filter
        let now = Date()
        switch timeFilter {
        case .allTime: break
        case .today:
            result = result.filter { Calendar.current.isDateInToday($0.timestamp) }
        case .last7Days:
            if let boundary = Calendar.current.date(byAdding: .day, value: -7, to: now) {
                result = result.filter { $0.timestamp >= boundary }
            }
        case .last30Days:
            if let boundary = Calendar.current.date(byAdding: .day, value: -30, to: now) {
                result = result.filter { $0.timestamp >= boundary }
            }
        }
        
        // 2. Action Filter
        switch actionFilter {
        case .all: break
        case .auth:
            result = result.filter { 
                let act = $0.action.lowercased()
                return act.contains("login") || act.contains("logout")
            }
        case .modifications:
            result = result.filter { 
                let act = $0.action.lowercased()
                return act.contains("add") || act.contains("register") || act.contains("update") || act.contains("edit")
            }
        case .deactivations:
            result = result.filter { 
                let act = $0.action.lowercased()
                return act.contains("deactivate") || act.contains("delete") || act.contains("remove")
            }
        }
        
        // 3. Role Filter
        if filterRole != "All" {
            result = result.filter { $0.userRole.displayName == filterRole }
        }
        
        // 4. Text Search
        if !searchText.isEmpty {
            result = result.filter { log in
                log.action.localizedCaseInsensitiveContains(searchText) ||
                log.userName.localizedCaseInsensitiveContains(searchText) ||
                log.userRole.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    func fetchLogs() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let fetchedLogs = try await ActivityLogManager.shared.fetchLogs()
                self.logs = fetchedLogs
                self.isLoading = false
            } catch {
                self.errorMessage = "Failed to load activity logs: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
