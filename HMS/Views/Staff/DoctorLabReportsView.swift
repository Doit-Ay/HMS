import SwiftUI

// MARK: - Doctor Lab Reports View
/// Displays completed lab reports for a specific patient.
/// Uses NavigationLink → CachedFileViewerView with caching, matching the patient side.
struct DoctorLabReportsView: View {
    @Environment(\.dismiss) var dismiss
    
    let patientId: String
    let patientName: String
    
    @State private var labRequests: [PatientLabRequest] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            contentView
        }
        .navigationTitle("Lab Reports")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchLabReports()
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            ProgressView("Fetching Lab Reports...")
        } else if let error = errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 30))
                    .foregroundColor(.red)
                Text(error)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("Retry") {
                    Task { await fetchLabReports() }
                }
                .padding(.top, 10)
            }
        } else if labRequests.isEmpty {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.08))
                        .frame(width: 90, height: 90)
                    Image(systemName: "flask")
                        .font(.system(size: 38))
                        .foregroundColor(AppTheme.primary.opacity(0.5))
                }
                Text("No Lab Reports")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Text("No completed lab reports found for \(patientName).")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    ForEach(labRequests) { request in
                        DoctorLabReportCard(request: request)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchLabReports() async {
        do {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            let reports = try await DoctorPatientRepository.shared.fetchCompletedLabReports(patientId: patientId)
            await MainActor.run {
                self.labRequests = reports
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Lab Report Card (Doctor Side — matches patient-side LabReportCard)
private struct DoctorLabReportCard: View {
    let request: PatientLabRequest
    
    private var isCompleted: Bool { request.allCompleted }
    
    /// Picks the first non-empty result URL from any test in this request.
    private var reportURL: String? {
        request.tests.compactMap { $0.resultURL }.first(where: { !$0.isEmpty })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header — Date + Status
            HStack {
                if let custom = request.customName {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(custom)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                        Text(request.dateRequested.formatted(date: .long, time: .omitted))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                } else {
                    Text(request.dateRequested.formatted(date: .long, time: .omitted))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                Spacer()
                
                Text(isCompleted ? "Completed" : "Pending")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isCompleted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundColor(isCompleted ? .green : .orange)
                    .cornerRadius(8)
            }
            
            Divider()
            
            // Tests
            ForEach(request.tests) { test in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(test.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary)
                            
                            if let date = test.completedDate {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.green)
                                    Text("Completed \(date.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
            
            // Single View Report button for the entire request (matches patient side)
            if isCompleted, let urlString = reportURL {
                NavigationLink(destination: CachedFileViewerView(
                    title: request.customName ?? "Lab Report",
                    urlString: urlString,
                    documentId: request.id,
                    collectionName: request.collectionName
                )) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 13))
                        Text("View Report")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.primary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}
