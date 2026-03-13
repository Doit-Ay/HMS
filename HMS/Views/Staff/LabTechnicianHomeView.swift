import SwiftUI

// MARK: - Lab Test Request Model
struct LabTestRequest: Identifiable, Hashable {
    let id = UUID()
    let patientName: String
    let testName: String
    let doctorName: String
    let department: String?
    let requestedDate: String
    let status: LabTestStatus

    enum LabTestStatus: String {
        case upcoming   = "Upcoming"
        case incomplete = "Incomplete"
        case completed  = "Completed"

        var color: Color {
            switch self {
            case .upcoming:   return .orange
            case .incomplete: return AppTheme.warning
            case .completed:  return AppTheme.success
            }
        }
    }
}

// MARK: - Lab Technician Home View
struct LabTechnicianHomeView: View {
    @State private var appearAnimation = false
    @State private var selectedSegment  = 0  // 0 = Upcoming/Incomplete, 1 = Completed
    @State private var selectedTest: LabTestRequest?

    // Greeting logic (same as Doctor's dashboard)
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning," }
        if hour < 17 { return "Good Afternoon," }
        return "Good Evening,"
    }

    private var technicianName: String {
        UserSession.shared.currentUser?.fullName.split(separator: " ").first.map(String.init) ?? "Technician"
    }

    // MARK: - Sample Data
    private var upcomingTests: [LabTestRequest] {
        [
            LabTestRequest(patientName: "Oliver Smith",  testName: "Complete Blood Count",  doctorName: "Dr. Saif",   department: "Hematology",     requestedDate: "Today, 11:00 AM", status: .upcoming),
            LabTestRequest(patientName: "Ava Johnson",   testName: "Lipid Panel",           doctorName: "Dr. Mehra",  department: "Biochemistry",   requestedDate: "Today, 01:30 PM", status: .upcoming),
            LabTestRequest(patientName: "Liam Williams", testName: "Liver Function Test",   doctorName: "Dr. Kapoor", department: "Biochemistry",   requestedDate: "Today, 03:00 PM", status: .incomplete),
            LabTestRequest(patientName: "Emma Davis",    testName: "Urine Analysis",        doctorName: "Dr. Sen",    department: "Microbiology",   requestedDate: "Yesterday",       status: .incomplete)
        ]
    }

    private var completedTests: [LabTestRequest] {
        [
            LabTestRequest(patientName: "Noah Garcia",  testName: "Blood Glucose",     doctorName: "Dr. Saif",   department: "Biochemistry",  requestedDate: "Today, 09:00 AM",     status: .completed),
            LabTestRequest(patientName: "Mia Brown",    testName: "Thyroid Panel",     doctorName: "Dr. Mehra",  department: "Endocrinology", requestedDate: "Yesterday, 02:00 PM", status: .completed),
            LabTestRequest(patientName: "James Wilson", testName: "HbA1c",             doctorName: "Dr. Kapoor", department: "Biochemistry",  requestedDate: "Yesterday, 04:30 PM", status: .completed)
        ]
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. Top Header (matches Doctor's dashboard)
                    headerView
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .offset(y: appearAnimation ? 0 : -30)
                        .opacity(appearAnimation ? 1 : 0)

                    // 2. Test Requests — Full Screen
                    testRequestsSection
                        .padding(.top, 20)
                        .offset(y: appearAnimation ? 0 : 20)
                        .opacity(appearAnimation ? 1 : 0)
                }
            }
            .navigationDestination(item: $selectedTest) { test in
                UploadTestDetailView(test: test)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
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
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }
            Spacer()
            NavigationLink(destination: ProfileView()) {
                ZStack {
                    Circle()
                        .fill(AppTheme.primaryDark.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "flask.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.primaryDark)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Test Requests Section (Full Screen)
    private var testRequestsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section Header
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

            // Segmented Control
            Picker("", selection: $selectedSegment) {
                Text("Upcoming / Incomplete").tag(0)
                Text("Completed").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)

            // Test List — fills remaining space
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    let tests = selectedSegment == 0 ? upcomingTests : completedTests
                    ForEach(tests) { test in
                        LabTestRequestCard(test: test)
                            .onTapGesture {
                                // Only navigate for incomplete tests
                                if test.status == .upcoming || test.status == .incomplete {
                                    selectedTest = test
                                }
                            }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Lab Test Request Card
struct LabTestRequestCard: View {
    let test: LabTestRequest

    private var isTappable: Bool {
        test.status == .upcoming || test.status == .incomplete
    }

    var body: some View {
        HStack(spacing: 14) {
            // Left icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(test.status.color.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: test.status == .completed ? "checkmark.seal.fill" : "flask.fill")
                    .font(.system(size: 20))
                    .foregroundColor(test.status.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(test.testName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textSecondary)
                    Text(test.patientName)
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

            VStack(spacing: 6) {
                // Status badge
                Text(test.status.rawValue)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(test.status.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(test.status.color.opacity(0.1))
                    .cornerRadius(8)

                // Chevron hint for tappable cards
                if isTappable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Upload Test Detail View (Push destination)
struct UploadTestDetailView: View {
    let test: LabTestRequest
    @State private var showUploadConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // Test Info Hero Card
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

                        detailRow(icon: "person.fill",         label: "Patient",       value: test.patientName)
                        detailRow(icon: "stethoscope",         label: "Requested By",  value: test.doctorName)
                        detailRow(icon: "building.2.fill",     label: "Department",    value: test.department ?? "—")
                        detailRow(icon: "calendar.badge.clock", label: "Requested On", value: test.requestedDate)
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // Upload Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "arrow.up.doc.fill")
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.success)
                            Text("Upload Results")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                        }

                        Text("Attach the test report for this request. The report will be visible to the requesting doctor and the patient.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)

                        // Upload area
                        Button {
                            showUploadConfirmation = true
                        } label: {
                            VStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.primary.opacity(0.1))
                                        .frame(width: 64, height: 64)
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(AppTheme.primary)
                                }

                                Text("Tap to Upload Report")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.primary)

                                Text("PDF, JPG, PNG supported")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(AppTheme.primary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                                    .background(AppTheme.primary.opacity(0.03).cornerRadius(18))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Upload Test")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Upload Report", isPresented: $showUploadConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Upload") {
                // TODO: Implement actual file upload
                dismiss()
            }
        } message: {
            Text("Upload report for \(test.testName) — \(test.patientName)?")
        }
    }

    // MARK: - Detail Row Helper
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

// MARK: - Preview
#Preview {
    LabTechnicianHomeView()
}
