
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
                Text("Upcoming").tag(0)
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

    private var statusColor: Color {
        request.allCompleted ? AppTheme.success : .orange
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Patient avatar
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 48, height: 48)
                Text(String(request.patientName.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(statusColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(request.patientName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textSecondary)
                    Text("\(request.totalTestsCount) test\(request.totalTestsCount == 1 ? "" : "s")")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textSecondary)
                    Text(request.dateRequested.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            // Status badge
            Text(request.allCompleted ? "Completed" : "\(request.completedTestsCount)/\(request.totalTestsCount)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
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

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // ── Patient Info Card ──
                    patientInfoCard
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    // ── Test Cards ──
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "list.bullet.clipboard.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.primary)
                            Text("Lab Tests")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text("\(liveRequest.completedTestsCount)/\(liveRequest.totalTestsCount) done")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(liveRequest.allCompleted ? AppTheme.success : .orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background((liveRequest.allCompleted ? AppTheme.success : Color.orange).opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 24)

                        ForEach(Array(liveRequest.tests.enumerated()), id: \.element.id) { index, test in
                            TestItemCard(test: test, index: index + 1)
                                .padding(.horizontal, 24)
                        }
                    }

                    // ── Upload Error ──
                    if let error = uploadError {
                        Text(error)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 100) // space for floating button
                }
            }

            // ── Floating Action Button ──
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    floatingButton
                        .padding(.trailing, 28)
                        .padding(.bottom, 28)
                }
            }

            // Upload progress overlay
            if isUploading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Uploading report...")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .navigationTitle("Request Details")
        .navigationBarTitleDisplayMode(.inline)

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

        .alert("Report Uploaded", isPresented: $uploadSuccess) {
            Button("OK") { }
        } message: {
            Text("The lab report has been uploaded successfully.")
        }
    }

    // MARK: - Patient Info Card
    private var patientInfoCard: some View {
        HStack(spacing: 14) {
            // Patient avatar
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.12))
                    .frame(width: 56, height: 56)
                Text(String(request.patientName.prefix(1)).uppercased())
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primary)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(request.patientName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                    Text(request.dateRequested.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }

                // Show doctor name only if any test was requested by a doctor
                if let doctorName = firstDoctorName {
                    HStack(spacing: 4) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.primary)
                        Text("Requested by Dr. \(doctorName)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.primary)
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
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

    // MARK: - Floating Action Button
    @ViewBuilder
    private var floatingButton: some View {
        if hasCompletedReport || uploadSuccess {
            // Document button — view the uploaded report
            Button {
                if let url = firstReportURL {
                    reportViewerURL = url
                    showReportViewer = true
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.success)
                        .frame(width: 60, height: 60)
                        .shadow(color: AppTheme.success.opacity(0.4), radius: 12, x: 0, y: 6)
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        } else if !liveRequest.allCompleted {
            // Plus button — upload a report
            Button {
                showSourceSheet = true
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.primary)
                        .frame(width: 60, height: 60)
                        .shadow(color: AppTheme.primary.opacity(0.4), radius: 12, x: 0, y: 6)
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .disabled(isUploading)
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

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(test.isCompleted ? AppTheme.success.opacity(0.12) : Color.orange.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: test.isCompleted ? "checkmark.circle.fill" : "clock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(test.isCompleted ? AppTheme.success : .orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(test.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                if test.isCompleted, let date = test.completedDate {
                    Text("Completed \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(AppTheme.success)
                } else {
                    Text("₹\(test.price)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            // Status badge
            Text(test.isCompleted ? "Done" : "Pending")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(test.isCompleted ? AppTheme.success : .orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background((test.isCompleted ? AppTheme.success : Color.orange).opacity(0.1))
                .cornerRadius(8)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
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
