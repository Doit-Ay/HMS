import SwiftUI

// MARK: - Doctor Lab Reports View
/// Displays completed lab reports for a specific patient.
/// Fetches from `patient_lab_requests` where status == "completed" and resultURL exists.
struct DoctorLabReportsView: View {
    @Environment(\.dismiss) var dismiss
    
    let patientId: String
    let patientName: String
    
    @State private var labRequests: [PatientLabRequest] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    // Sheet state for viewing reports
    @State private var selectedReportURL: URL? = nil
    @State private var selectedReportIsImage = false
    @State private var selectedReportTitle = ""
    @State private var selectedReportExtension = ""
    @State private var showReportSheet = false
    
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
        .sheet(isPresented: $showReportSheet) {
            reportSheetContent
        }
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
                        DoctorLabReportCard(
                            request: request,
                            onViewReport: { url, title, isImage, fileExtension in
                                selectedReportURL = url
                                selectedReportTitle = title
                                selectedReportIsImage = isImage
                                selectedReportExtension = fileExtension
                                showReportSheet = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }
    
    // MARK: - Report Sheet
    
    @ViewBuilder
    private var reportSheetContent: some View {
        if let url = selectedReportURL {
            if selectedReportIsImage {
                InteractiveImageViewer(
                    url: url,
                    title: selectedReportTitle,
                    extensionString: selectedReportExtension
                )
            } else {
                PDFViewerSheet(
                    pdfURL: url,
                    title: selectedReportTitle
                )
            }
        } else {
            Text("Invalid Report URL")
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

// MARK: - Lab Report Card (Doctor Side)
private struct DoctorLabReportCard: View {
    let request: PatientLabRequest
    let onViewReport: (URL, String, Bool, String) -> Void
    
    private let imageExtensions = ["jpg", "jpeg", "png", "heic", "gif"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header — Date + Status
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.primary)
                    Text(request.dateRequested.formatted(date: .long, time: .omitted))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                Spacer()
                
                Text("Completed")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(8)
            }
            
            Divider()
            
            // Tests with reports
            ForEach(request.tests) { test in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(test.name)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
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
                        
                        // View Report button
                        if let urlString = test.resultURL,
                           !urlString.isEmpty,
                           let url = URL(string: urlString) {
                            Button {
                                let ext = url.pathExtension.lowercased()
                                let isImage = imageExtensions.contains(ext)
                                let fileName = test.resultFileName ?? test.name
                                onViewReport(url, fileName, isImage, ext)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 12))
                                    Text("View Report")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(
                                        colors: [AppTheme.primary, AppTheme.primaryMid],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                            }
                        } else {
                            Text("Pending")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    
                    if test != request.tests.last {
                        Divider()
                            .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}
