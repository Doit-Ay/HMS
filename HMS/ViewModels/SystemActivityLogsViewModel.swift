import Foundation
import Combine

@MainActor
class SystemActivityLogsViewModel: ObservableObject {
    @Published var logs: [SystemActivityLog] = []
    @Published var isLoading: Bool = false
    @Published var searchText: String = ""
    @Published var errorMessage: String? = nil
    
    var filteredLogs: [SystemActivityLog] {
        if searchText.isEmpty {
            return logs
        } else {
            return logs.filter { log in
                log.action.localizedCaseInsensitiveContains(searchText) ||
                log.userName.localizedCaseInsensitiveContains(searchText) ||
                (log.details?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                log.userRole.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
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
