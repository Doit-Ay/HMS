
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import WebKit

// MARK: - Lab Technician Home View
struct LabTechnicianHomeView: View {
    @ObservedObject private var repo = LabTechnicianRepository.shared
    @State private var appearAnimation = false
    @State private var selectedSegment  = 0
    @State private var selectedRequest: PatientLabRequest?
    @State private var showProfileSheet = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning," }
        if hour < 17 { return "Good Afternoon," }
        return "Good Evening,"
    }

    private var technicianName: String {
        UserSession.shared.currentUser?.fullName.split(separator: " ").first.map(String.init) ?? "Technician"
    }

    private var currentRequests: [PatientLabRequest] {
        selectedSegment == 0 ? repo.pendingRequests : repo.completedRequests
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    headerView
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .opacity(appearAnimation ? 1 : 0)

                    testRequestsSection
                        .padding(.top, 20)
                        .opacity(appearAnimation ? 1 : 0)
                }
            }
            .navigationDestination(item: $selectedRequest) { request in
                LabRequestDetailView(request: request)
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileView()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appearAnimation = true }
            repo.startListening()
        }
        .onDisappear {
            repo.removeListeners()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                Text(technicianName)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }
            Spacer()
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
    }

    // MARK: - Test Requests Section
    private var testRequestsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.primary)
                Text("Test Requests")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("\(currentRequests.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.primary.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 24)

            Picker("", selection: $selectedSegment) {
                Text("Pending").tag(0)
                Text("Completed").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)

            let isLoading = selectedSegment == 0 ? repo.isLoadingPending : repo.isLoadingCompleted

            if isLoading {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(AppTheme.primary)
                    Spacer()
                }
                .padding(.top, 60)
                Spacer()
            } else if currentRequests.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: selectedSegment == 0 ? "flask" : "checkmark.circle")
                        .font(.system(size: 50))
                        .foregroundColor(AppTheme.textSecondary)
                    Text(selectedSegment == 0 ? "No pending requests" : "No completed requests yet")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(currentRequests) { request in
                            LabRequestCard(request: request)
                                .onTapGesture {
                                    selectedRequest = request
                                }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Lab Request Card (per-request, shows patient + test count)
struct LabRequestCard: View {
    let request: PatientLabRequest
    @State private var isApproving = false

    private var isPending: Bool {
        request.status == "pending"
    }

    private var isInProgress: Bool {
        request.status == "in_progress"
    }

    private var statusColor: Color {
        if request.allCompleted { return AppTheme.success }
        if isInProgress { return AppTheme.primary }
        return .orange
    }

    private var statusText: String {
        if request.allCompleted { return "Completed" }
        if isInProgress { return "In Progress" }
        return "Requested"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top Section
            HStack(alignment: .top, spacing: 16) {
                // Patient avatar
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(statusColor.opacity(0.12))
                        .frame(width: 76, height: 76)
                    Text(String(request.patientName.prefix(1)).uppercased())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(statusColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(request.patientName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("\(request.dateRequested.formatted(.dateTime.weekday(.wide).month(.wide).day())) at \(request.dateRequested.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "flask")
                                .font(.system(size: 10))
                            Text("\(request.totalTestsCount) Test\(request.totalTestsCount == 1 ? "" : "s")")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .foregroundColor(AppTheme.textSecondary)
                        
                        Spacer()
                        
                        Text(statusText)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(statusColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(statusColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(16)
            
            Divider()
                .background(Color.gray.opacity(0.2))
            
            // Bottom Action
            if isPending {
                // Approve button for pending requests
                Button {
                    approveRequest()
                } label: {
                    HStack(spacing: 8) {
                        if isApproving {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(AppTheme.success)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                        }
                        Text("APPROVE")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .tracking(1.5)
                    }
                    .foregroundColor(AppTheme.success)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
                .disabled(isApproving)
            } else if isInProgress {
                // Approved badge for in-progress requests
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("APPROVED")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(1.5)
                }
                .foregroundColor(AppTheme.primary)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            } else {
                // View details for completed requests
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 14, weight: .bold))
                    Text("VIEW DETAILS")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(1.5)
                }
                .foregroundColor(AppTheme.primary)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private func approveRequest() {
        isApproving = true
        Task {
            do {
                try await LabTechnicianRepository.shared.approveRequest(requestId: request.id)
            } catch {
                print("Failed to approve request: \(error)")
            }
            await MainActor.run {
                isApproving = false
            }
        }
    }
}

// MARK: - Lab Request Detail View
struct LabRequestDetailView: View {
    let request: PatientLabRequest

    @ObservedObject private var repo = LabTechnicianRepository.shared
    @State private var showSourceSheet    = false
    @State private var showCamera         = false
    @State private var showPhotoLibrary   = false
    @State private var showDocumentPicker = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var uploadedImage: UIImage?
    @State private var uploadedFileURL: URL?
    @State private var isUploading = false
    @State private var uploadSuccess = false
    @State private var uploadError: String?
    @State private var showReportViewer = false
    @State private var reportViewerURL: URL?

    // Animation states
    @State private var heroAppear = false
    @State private var testsAppear = false
    @State private var uploadSectionAppear = false
    @State private var progressAnimated: CGFloat = 0

    @Environment(\.dismiss) private var dismiss

    /// Whether a report has been uploaded (either image or file)
    private var hasUploadedReport: Bool {
        uploadedImage != nil || uploadedFileURL != nil || uploadSuccess
    }

    /// Find the live version of this request from the repo (for real-time updates)
    private var liveRequest: PatientLabRequest {
        repo.pendingRequests.first(where: { $0.id == request.id })
        ?? repo.completedRequests.first(where: { $0.id == request.id })
        ?? request
    }

    /// Check if any test already has a result URL (completed via Firestore)
    private var hasCompletedReport: Bool {
        liveRequest.tests.contains(where: { $0.isCompleted })
    }

    /// Get the first available report URL
    private var firstReportURL: URL? {
        guard let urlString = liveRequest.tests.first(where: { $0.isCompleted })?.resultURL,
              let url = URL(string: urlString) else { return nil }
        return url
    }

    /// Completion fraction for the progress bar
    private var completionFraction: CGFloat {
        guard liveRequest.totalTestsCount > 0 else { return 0 }
        return CGFloat(liveRequest.completedTestsCount) / CGFloat(liveRequest.totalTestsCount)
    }

    /// Returns the first non-empty doctor name from the tests, or nil if self-requested
    private var firstDoctorName: String? {
        for test in request.tests {
            if let doctor = test.requestedByDoctor, !doctor.isEmpty {
                return doctor
            }
        }
        return nil
    }

    // MARK: - Status Helpers for Detail View
    private var detailStatusColor: Color {
        if liveRequest.allCompleted { return AppTheme.success }
        if liveRequest.status == "in_progress" { return AppTheme.primary }
        return .orange
    }

    private var detailStatusText: String {
        if liveRequest.allCompleted { return "Done" }
        if liveRequest.status == "in_progress" { return "In Progress" }
        return "Requested"
    }

    private var detailStatusIcon: String {
        if liveRequest.allCompleted { return "checkmark.seal.fill" }
        if liveRequest.status == "in_progress" { return "bolt.fill" }
        return "clock.badge"
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // ── Patient Hero Card ──
                    patientHeroCard
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .opacity(heroAppear ? 1 : 0)
                        .offset(y: heroAppear ? 0 : 20)

                    // ── Lab Tests Section ──
                    labTestsSection
                        .opacity(testsAppear ? 1 : 0)
                        .offset(y: testsAppear ? 0 : 15)

                    // ── Upload / View Report Section ──
                    uploadDocumentSection
                        .padding(.horizontal, 20)
                        .opacity(uploadSectionAppear ? 1 : 0)
                        .offset(y: uploadSectionAppear ? 0 : 15)

                    // ── Upload Error ──
                    if let error = uploadError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.error)
                            Text(error)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.error)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.error.opacity(0.08))
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 40)
                }
            }

            // Upload progress overlay
            if isUploading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 4)
                            .frame(width: 60, height: 60)
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                    Text("Uploading report...")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Please wait while we upload your document")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(32)
                .background(.ultraThinMaterial)
                .cornerRadius(24)
                .shadow(color: .black.opacity(0.2), radius: 20)
            }
        }
        .navigationTitle("Request Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                heroAppear = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15)) {
                testsAppear = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                uploadSectionAppear = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
                progressAnimated = completionFraction
            }
        }

        // Camera
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView { image in
                uploadedImage    = image
                uploadedFileURL  = nil
                showCamera       = false
                performImageUpload(image: image)
            }
            .ignoresSafeArea()
        }

        // Photo Library
        .photosPicker(
            isPresented:        $showPhotoLibrary,
            selection:          $pickerItems,
            maxSelectionCount:  1,
            matching:           .images
        )
        .onChange(of: pickerItems) { _, newItems in
            guard let item = newItems.first else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img  = UIImage(data: data) {
                    await MainActor.run {
                        uploadedImage   = img
                        uploadedFileURL = nil
                        performImageUpload(image: img)
                    }
                }
            }
        }

        // Documents
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { url in
                uploadedFileURL  = url
                uploadedImage    = nil
                showDocumentPicker = false
                performDocumentUpload(fileURL: url)
            }
        }

        // Report Viewer
        .sheet(isPresented: $showReportViewer) {
            if let url = reportViewerURL {
                NavigationStack {
                    ReportViewerView(url: url)
                        .navigationTitle("Lab Report")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showReportViewer = false
                                }
                            }
                        }
                }
            }
        }

        // Upload source sheet
        .sheet(isPresented: $showSourceSheet) {
            GlassUploadSheet(
                isPresented:    $showSourceSheet,
                onCamera:       { showCamera         = true },
                onPhotoLibrary: { showPhotoLibrary   = true },
                onDocuments:    { showDocumentPicker  = true }
            )
            .presentationDetents([.height(260)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
        }

        .alert("Report Uploaded", isPresented: $uploadSuccess) {
            Button("OK") { }
        } message: {
            Text("The lab report has been uploaded successfully.")
        }
    }

    // MARK: - Patient Hero Card
    private var patientHeroCard: some View {
        VStack(spacing: 0) {
            // Top section with avatar + info
            HStack(spacing: 16) {
                // Avatar with gradient ring
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [AppTheme.primary, AppTheme.primaryMid, AppTheme.primaryLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 72, height: 72)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.primaryLight, AppTheme.primary.opacity(0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 64, height: 64)

                    Text(String(request.patientName.prefix(1)).uppercased())
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.primary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(request.patientName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textSecondary)
                        Text(request.dateRequested.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    if let doctorName = firstDoctorName {
                        HStack(spacing: 5) {
                            Image(systemName: "stethoscope")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.primary)
                            Text("Dr. \(doctorName)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(AppTheme.primary)
                        }
                    }
                }

                Spacer()

                // Status badge
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(detailStatusColor.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: detailStatusIcon)
                            .font(.system(size: 18))
                            .foregroundColor(detailStatusColor)
                            .symbolEffect(.bounce, value: heroAppear)
                    }
                    Text(detailStatusText)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(detailStatusColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Divider
            Rectangle()
                .fill(AppTheme.primary.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 16)

            // Progress section
            HStack(spacing: 14) {
                // Progress bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Test Progress")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        Text("\(liveRequest.completedTestsCount) of \(liveRequest.totalTestsCount)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppTheme.primary.opacity(0.1))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.primary, AppTheme.primaryMid],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progressAnimated, height: 8)
                        }
                    }
                    .frame(height: 8)
                }

                // Tests count pill
                HStack(spacing: 4) {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 11))
                    Text("\(liveRequest.totalTestsCount)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundColor(AppTheme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.primaryLight.opacity(0.5))
                .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(Color.white)
        .cornerRadius(22)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(AppTheme.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Lab Tests Section
    private var labTestsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.primary.opacity(0.1))
                        .frame(width: 30, height: 30)
                    Image(systemName: "list.bullet.clipboard.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.primary)
                }

                Text("Requested Lab Tests")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Text(liveRequest.allCompleted ? "All Complete" : "\(liveRequest.completedTestsCount)/\(liveRequest.totalTestsCount) done")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(liveRequest.allCompleted ? AppTheme.success : .orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((liveRequest.allCompleted ? AppTheme.success : Color.orange).opacity(0.1))
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)

            // Test cards with staggered animation
            ForEach(Array(liveRequest.tests.enumerated()), id: \.element.id) { index, test in
                TestItemCard(test: test, index: index + 1, animateIn: testsAppear)
                    .padding(.horizontal, 20)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
    }

    // MARK: - Upload Document Section
    @ViewBuilder
    private var uploadDocumentSection: some View {
        if hasCompletedReport || uploadSuccess {
            // View Report card
            Button {
                if let url = firstReportURL {
                    reportViewerURL = url
                    showReportViewer = true
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.success.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.success)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Report Uploaded")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Tap to view the lab report")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.success)
                        .padding(10)
                        .background(AppTheme.success.opacity(0.1))
                        .clipShape(Circle())
                }
                .padding(18)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(AppTheme.success.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        } else if !liveRequest.allCompleted {
            // Upload Report card
            Button {
                showSourceSheet = true
            } label: {
                VStack(spacing: 16) {
                    // Dashed border area
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.primary.opacity(0.15), AppTheme.primaryLight],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 56, height: 56)
                            Image(systemName: "arrow.up.doc.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.primary)
                                .symbolEffect(.pulse, isActive: uploadSectionAppear)
                        }

                        Text("Upload Lab Report")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Take a photo, choose from gallery, or browse files")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                            .foregroundColor(AppTheme.primary.opacity(0.3))
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppTheme.primaryLight.opacity(0.2))
                    )

                    // Upload button
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                        Text("Choose File to Upload")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primaryMid],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(18)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .disabled(isUploading)
        }
    }

    // MARK: - Upload Actions

    /// Uploads an image report for all pending tests in the request.
    private func performImageUpload(image: UIImage) {
        isUploading = true
        uploadError = nil

        Task {
            do {
                try await LabTechnicianRepository.shared.uploadAndCompleteAll(
                    requestId: request.id,
                    image: image
                )
                await MainActor.run {
                    isUploading = false
                    uploadSuccess = true
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    uploadError = error.localizedDescription
                }
            }
        }
    }

    /// Uploads a document file for all pending tests in the request.
    private func performDocumentUpload(fileURL: URL) {
        isUploading = true
        uploadError = nil

        Task {
            do {
                try await LabTechnicianRepository.shared.uploadAndCompleteAll(
                    requestId: request.id,
                    fileURL: fileURL
                )
                await MainActor.run {
                    isUploading = false
                    uploadSuccess = true
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    uploadError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Test Item Card
struct TestItemCard: View {
    let test: RequestedTest
    let index: Int
    var animateIn: Bool = false

    @State private var cardAppeared = false

    private var statusColor: Color {
        test.isCompleted ? AppTheme.success : .orange
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [statusColor, statusColor.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)
                .padding(.vertical, 8)

            HStack(spacing: 14) {
                // Index circle
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.1))
                        .frame(width: 40, height: 40)

                    if test.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(statusColor)
                    } else {
                        Text("\(index)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(statusColor)
                    }
                }

                // Test info
                VStack(alignment: .leading, spacing: 4) {
                    Text(test.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    if test.isCompleted, let date = test.completedDate {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.success)
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.success)
                        }
                    } else {
                        HStack(spacing: 8) {
                            // Price badge
                            Text("₹\(test.price)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppTheme.primaryLight.opacity(0.6))
                                .cornerRadius(6)

                            if let doctor = test.requestedByDoctor, !doctor.isEmpty {
                                Text("Dr. \(doctor)")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Spacer()

                // Status badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(test.isCompleted ? "Done" : "Pending")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.08))
                .cornerRadius(10)
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .padding(.vertical, 14)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(cardAppeared ? 1 : 0.95)
        .opacity(cardAppeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.08)) {
                cardAppeared = true
            }
        }
    }
}

// MARK: - Report Viewer (handles images and PDFs via web view)
struct ReportViewerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground

        // Load the file from the URL
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                let mimeType = (response as? HTTPURLResponse)?.mimeType ?? ""

                await MainActor.run {
                    if mimeType.contains("image") || url.pathExtension.lowercased().hasSuffix("jpg") || url.pathExtension.lowercased().hasSuffix("jpeg") || url.pathExtension.lowercased().hasSuffix("png") {
                        // Show as image
                        let imageView = UIImageView(image: UIImage(data: data))
                        imageView.contentMode = .scaleAspectFit
                        imageView.translatesAutoresizingMaskIntoConstraints = false
                        container.addSubview(imageView)
                        NSLayoutConstraint.activate([
                            imageView.topAnchor.constraint(equalTo: container.topAnchor),
                            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
                        ])
                    } else {
                        // Show as PDF or web content
                        let webView = WKWebView()
                        webView.translatesAutoresizingMaskIntoConstraints = false
                        webView.load(URLRequest(url: url))
                        container.addSubview(webView)
                        NSLayoutConstraint.activate([
                            webView.topAnchor.constraint(equalTo: container.topAnchor),
                            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
                        ])
                    }
                }
            } catch {
                print("ReportViewerView: Error loading report: \(error)")
            }
        }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - iOS 26 Liquid Glass Upload Sheet
struct GlassUploadSheet: View {
    @Binding var isPresented: Bool
    var onCamera:       () -> Void
    var onPhotoLibrary: () -> Void
    var onDocuments:    () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 14) {
                Spacer()

                glassCapsule("Take Photo", systemImage: "camera") {
                    fire { onCamera() }
                }

                glassCapsule("Choose from Gallery", systemImage: "photo.on.rectangle") {
                    fire { onPhotoLibrary() }
                }

                glassCapsule("Browse Files", systemImage: "doc") {
                    fire { onDocuments() }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    private func glassCapsule(_ title: String,
                             systemImage: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 18, weight: .medium))
                Spacer()
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.5), lineWidth: 1.0)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func fire(action: @escaping () -> Void) {
        isPresented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            action()
        }
    }
}

// MARK: - Camera Picker
struct CameraPickerView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate   = context.coordinator
        return picker
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { onCapture(img) }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Document Picker
struct DocumentPickerView: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .image, .jpeg, .png, .data]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onPick(url) }
        }
    }
}

// MARK: - Preview
#Preview {
    LabTechnicianHomeView()
}
