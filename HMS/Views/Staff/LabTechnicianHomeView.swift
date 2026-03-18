import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Lab Test Request Model
struct LabTestUIRequest: Identifiable, Hashable {
    let id = UUID()
    let patientName: String
    let testName: String
    let doctorName: String
    let department: String?
    let requestedDate: String
    let status: LabTestStatus

    enum LabTestStatus: String {
        case pending   = "Pending"
        case completed  = "Completed"

        var color: Color {
            switch self {
            case .pending:   return .orange
            case .completed:  return AppTheme.success
            }
        }
    }
}

// MARK: - Lab Technician Home View
struct LabTechnicianHomeView: View {
    @State private var appearAnimation = false
<<<<<<< HEAD
    @State private var selectedSegment  = 0
    @State private var selectedTest: LabTestRequest?
    @State private var showProfileSheet = false
=======
    @State private var selectedSegment  = 0  // 0 = Upcoming/Incomplete, 1 = Completed
    @State private var selectedTest: LabTestUIRequest?
>>>>>>> 32e1f4aecd701dacbb962f471c7a3753aa33cc99

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning," }
        if hour < 17 { return "Good Afternoon," }
        return "Good Evening,"
    }

    private var technicianName: String {
        UserSession.shared.currentUser?.fullName.split(separator: " ").first.map(String.init) ?? "Technician"
    }

<<<<<<< HEAD
    private var upcomingTests: [LabTestRequest] {
        [
            LabTestRequest(patientName: "Oliver Smith",  testName: "Complete Blood Count",  doctorName: "Dr. Saif",   department: "Hematology",   requestedDate: "Today, 11:00 AM", status: .pending),
            LabTestRequest(patientName: "Ava Johnson",   testName: "Lipid Panel",           doctorName: "Dr. Mehra",  department: "Biochemistry", requestedDate: "Today, 01:30 PM", status: .pending),
            LabTestRequest(patientName: "Liam Williams", testName: "Liver Function Test",   doctorName: "Dr. Kapoor", department: "Biochemistry", requestedDate: "Today, 03:00 PM", status: .pending),
            LabTestRequest(patientName: "Emma Davis",    testName: "Urine Analysis",        doctorName: "Dr. Sen",    department: "Microbiology", requestedDate: "Yesterday",       status: .pending)
=======
    // MARK: - Sample Data
    private var upcomingTests: [LabTestUIRequest] {
        [
            LabTestUIRequest(patientName: "Oliver Smith",  testName: "Complete Blood Count",  doctorName: "Dr. Saif",   department: "Hematology",     requestedDate: "Today, 11:00 AM", status: .upcoming),
            LabTestUIRequest(patientName: "Ava Johnson",   testName: "Lipid Panel",           doctorName: "Dr. Mehra",  department: "Biochemistry",   requestedDate: "Today, 01:30 PM", status: .upcoming),
            LabTestUIRequest(patientName: "Liam Williams", testName: "Liver Function Test",   doctorName: "Dr. Kapoor", department: "Biochemistry",   requestedDate: "Today, 03:00 PM", status: .incomplete),
            LabTestUIRequest(patientName: "Emma Davis",    testName: "Urine Analysis",        doctorName: "Dr. Sen",    department: "Microbiology",   requestedDate: "Yesterday",       status: .incomplete)
>>>>>>> 32e1f4aecd701dacbb962f471c7a3753aa33cc99
        ]
    }

    private var completedTests: [LabTestUIRequest] {
        [
<<<<<<< HEAD
            LabTestRequest(patientName: "Noah Garcia",  testName: "Blood Glucose", doctorName: "Dr. Saif",   department: "Biochemistry",  requestedDate: "Today, 09:00 AM",     status: .completed),
            LabTestRequest(patientName: "Mia Brown",    testName: "Thyroid Panel", doctorName: "Dr. Mehra",  department: "Endocrinology", requestedDate: "Yesterday, 02:00 PM", status: .completed),
            LabTestRequest(patientName: "James Wilson", testName: "HbA1c",         doctorName: "Dr. Kapoor", department: "Biochemistry",  requestedDate: "Yesterday, 04:30 PM", status: .completed)
=======
            LabTestUIRequest(patientName: "Noah Garcia",  testName: "Blood Glucose",     doctorName: "Dr. Saif",   department: "Biochemistry",  requestedDate: "Today, 09:00 AM",     status: .completed),
            LabTestUIRequest(patientName: "Mia Brown",    testName: "Thyroid Panel",     doctorName: "Dr. Mehra",  department: "Endocrinology", requestedDate: "Yesterday, 02:00 PM", status: .completed),
            LabTestUIRequest(patientName: "James Wilson", testName: "HbA1c",             doctorName: "Dr. Kapoor", department: "Biochemistry",  requestedDate: "Yesterday, 04:30 PM", status: .completed)
>>>>>>> 32e1f4aecd701dacbb962f471c7a3753aa33cc99
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    headerView
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .offset(y: appearAnimation ? 0 : -30)
                        .opacity(appearAnimation ? 1 : 0)

                    testRequestsSection
                        .padding(.top, 20)
                        .offset(y: appearAnimation ? 0 : 20)
                        .opacity(appearAnimation ? 1 : 0)
                }
            }
            .navigationDestination(item: $selectedTest) { test in
                UploadTestDetailView(test: test)
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileView()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appearAnimation = true }
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
                Text("\(selectedSegment == 0 ? upcomingTests.count : completedTests.count)")
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

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    let tests = selectedSegment == 0 ? upcomingTests : completedTests
                    ForEach(tests) { test in
                        LabTestRequestCard(test: test)
                            .onTapGesture {
                                selectedTest = test
                            }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Lab Test Request Card
struct LabTestRequestCard: View {
    let test: LabTestUIRequest

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Left icon
            ZStack {
                Circle()
                    .fill(test.status.color.opacity(0.12))
                    .frame(width: 48, height: 48)
                Text(String(test.patientName.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(test.status.color)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(test.patientName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textSecondary)
                    Text(test.testName)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textSecondary)
                    Text(test.requestedDate)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            Text(test.status.rawValue)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(test.status.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(test.status.color.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

// MARK: - iOS 26 Liquid Glass Upload Sheet
struct GlassUploadSheet: View {
    @Binding var isPresented: Bool
    var onCamera:       () -> Void
    var onPhotoLibrary: () -> Void
    var onDocuments:    () -> Void

    var body: some View {
        ZStack {
            // Optional dim background
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

    // MARK: - Capsule Button
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
            .background(.regularMaterial) // 🔥 more prominent liquid glass
            .background(Color.white.opacity(0.2)) // catches light
            .clipShape(Capsule())           // 🔥 capsule shape
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.5), lineWidth: 1.0) // strong edge reflection
            )
            .shadow(color: .black.opacity(0.08), radius: 12, y: 5) // lighter floating effect
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action handler
    private func fire(action: @escaping () -> Void) {
        isPresented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            action()
        }
    }
}


// MARK: - Upload Test Detail View
struct UploadTestDetailView: View {
<<<<<<< HEAD
    let test: LabTestRequest

    @State private var showSourceSheet    = false
    @State private var showCamera         = false
    @State private var showPhotoLibrary   = false
    @State private var showDocumentPicker = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var uploadedImage: UIImage?
    @State private var uploadedFileName: String?

=======
    let test: LabTestUIRequest
    @State private var showUploadConfirmation = false
>>>>>>> 32e1f4aecd701dacbb962f471c7a3753aa33cc99
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // ── Test Info Hero Card ──
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppTheme.primaryDark.opacity(0.12))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "flask.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(AppTheme.primaryDark)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(test.testName)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)

                                Text(test.status.rawValue)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(test.status.color)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(test.status.color.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }

                        Divider()

                        detailRow(icon: "person.fill",          label: "Patient",       value: test.patientName)
                        detailRow(icon: "stethoscope",          label: "Requested By",  value: test.doctorName)
                        detailRow(icon: "building.2.fill",      label: "Department",    value: test.department ?? "—")
                        detailRow(icon: "calendar.badge.clock", label: "Requested On",  value: test.requestedDate)
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // ── Upload Section ──
                    uploadSection
                        .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Upload Test")
        .navigationBarTitleDisplayMode(.inline)

        // Camera
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView { image in
                uploadedImage    = image
                uploadedFileName = nil
                showCamera       = false
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
                        uploadedImage    = img
                        uploadedFileName = nil
                    }
                }
            }
        }

        // Documents
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { url in
                uploadedFileName  = url.lastPathComponent
                uploadedImage     = nil
                showDocumentPicker = false
            }
        }
        .onAppear {
            if test.status == .completed {
                uploadedFileName = "Lab_Report_Final.pdf"
            }
        }
    }

    // MARK: - Upload Section Card
    private var uploadSection: some View {
        VStack(spacing: 0) {

            // Header row
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.doc.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.success)
                Text("Upload Results")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                if uploadedImage != nil || uploadedFileName != nil {
                    Text("Attached ✓")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.success.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            // Body — preview or placeholder text
            Group {
                if let img = uploadedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                } else if let fileName = uploadedFileName {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.richtext.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppTheme.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fileName)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(2)
                            Text("Ready to submit")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(AppTheme.success)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(AppTheme.primary.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                } else {
                    Text("Attach the lab report — it will be shared with\nthe requesting doctor and the patient.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                }
            }

            if test.status != .completed {
                Divider()
                    .padding(.horizontal, 20)

                // Plus button — opens custom glass sheet correctly anchored as a popover below
                Button {
                    showSourceSheet = true
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.primary)
                                .frame(width: 32, height: 32)
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text(uploadedImage != nil || uploadedFileName != nil ? "Replace File" : "Add File")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showSourceSheet) {
                    GlassUploadSheet(
                        isPresented:    $showSourceSheet,
                        onCamera:       { showCamera         = true },
                        onPhotoLibrary: { showPhotoLibrary   = true },
                        onDocuments:    { showDocumentPicker = true }
                    )
                    .presentationDetents([.height(260)])
                    .presentationDragIndicator(.hidden)
                    .presentationBackground(.clear)
                }
            }
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.primary)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
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
