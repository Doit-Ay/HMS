import SwiftUI

struct PatientDetailView: View {
    let patientId: String
    let patientName: String // Provided globally as placeholder before fetch
    let doctorId: String
    
    @StateObject private var viewModel: PatientDetailViewModel
    
    @Environment(\.presentationMode) var presentationMode
    
    // Animation States
    @State private var appearAnimation = false
    @State private var statsAnimated = false
    @State private var photoScale: CGFloat = 0.95
    @State private var photoOpacity: Double = 0
    @State private var statsCountValues: [Int] = [0, 0, 0] // 0: Height, 1: Weight
    
    // Extracted targets for animations
    private var targetHeight: Int {
        if let h = viewModel.patient?.height, let val = Int(h.replacingOccurrences(of: "cm", with: "").trimmingCharacters(in: .whitespaces)) { return val }
        return 0
    }
    
    private var targetWeight: Int {
        if let w = viewModel.patient?.weight, let val = Int(w.replacingOccurrences(of: "kg", with: "").trimmingCharacters(in: .whitespaces)) { return val }
        return 0
    }
    
    // Designated initializer (no main-actor access in default args)
    init(patientId: String, patientName: String, doctorId: String) {
        self.patientId = patientId
        self.patientName = patientName
        self.doctorId = doctorId
        _viewModel = StateObject(wrappedValue: PatientDetailViewModel(patientId: patientId, doctorId: doctorId))
    }
    
    // Convenience initializer that safely reads UserSession on the main actor
    init(patientId: String, patientName: String) {
        let id = (try? MainActor.assumeIsolated { UserSession.shared.currentUser?.id }) ?? ""
        self.init(patientId: patientId, patientName: patientName, doctorId: id)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()
            
            if viewModel.isLoading {
                PatientDetailSkeletonView()
                    .transition(.opacity)
            } else if let error = viewModel.errorMessage {
                ErrorStateView(error: error) {
                    Task { await viewModel.loadPatientData() }
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        
                        // 1. Header with gradient background
                        buildProfileHeader()
                            .offset(y: appearAnimation ? 0 : 20)
                            .opacity(appearAnimation ? 1 : 0)
                        
                        // 2. Stats Row (overlapping header)
                        buildStatsRow()
                            .padding(.horizontal, 20)
                            .offset(y: -30)
                            .offset(y: appearAnimation ? 0 : 30)
                            .opacity(appearAnimation ? 1 : 0)
                        
                        // 3. Info Cards
                        VStack(spacing: 16) {
                            buildContactCard()
                            buildMedicalHistoryCard()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, -10)
                        .offset(y: appearAnimation ? 0 : 40)
                        .opacity(appearAnimation ? 1 : 0)
                        
                        // 4. Appointment History
                        buildAppointmentHistory()
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
        .task {
            await viewModel.loadPatientData()
            guard !viewModel.isLoading && viewModel.errorMessage == nil else { return }
            
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                photoScale = 1.0
                photoOpacity = 1.0
            }
            animateCounters()
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    // MARK: - Subcomponents
    
    @ViewBuilder
    private func buildProfileHeader() -> some View {
        ZStack(alignment: .bottom) {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [AppTheme.primary.opacity(0.15), AppTheme.primary.opacity(0.05), AppTheme.background]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)
            
            VStack(spacing: 14) {
                // Profile Photo with ring
                ZStack {
                    Circle()
                        .fill(AppTheme.cardSurface)
                        .frame(width: 108, height: 108)
                        .shadow(color: AppTheme.primary.opacity(0.2), radius: 12, x: 0, y: 6)
                    
                    Circle()
                        .stroke(
                            LinearGradient(colors: [AppTheme.primary, AppTheme.primaryMid], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 3
                        )
                        .frame(width: 104, height: 104)
                    
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(AppTheme.primary.opacity(0.4))
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                }
                .scaleEffect(photoScale)
                .opacity(photoOpacity)
                
                // Name
                Text(viewModel.patient?.fullName ?? patientName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                
                // Pills: Age · Gender · BloodGroup
                HStack(spacing: 10) {
                    pillText(viewModel.ageString, icon: "calendar")
                    pillText(formatFieldValue(viewModel.patient?.gender), icon: "person")
                    pillText(formatFieldValue(viewModel.patient?.bloodGroup), icon: "drop.fill")
                }
                
                Spacer().frame(height: 40)
            }
        }
    }
    
    @ViewBuilder
    private func pillText(_ text: String, icon: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundColor(AppTheme.primaryDark)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(AppTheme.cardSurface)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private func buildStatsRow() -> some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Height",
                value: targetHeight > 0 ? "\(statsCountValues[0]) cm" : "N/A",
                icon: "arrow.up.and.down",
                accentColor: .blue
            )
            StatCard(
                title: "Weight",
                value: targetWeight > 0 ? "\(statsCountValues[1]) kg" : "N/A",
                icon: "scalemass.fill",
                accentColor: .green
            )
            StatCard(
                title: "Blood",
                value: formatFieldValue(viewModel.patient?.bloodGroup),
                icon: "drop.fill",
                accentColor: .red
            )
        }
    }
    
    @ViewBuilder
    private func buildContactCard() -> some View {
        InfoCardContainer(title: "Contact Information", icon: "phone.fill") {
            VStack(alignment: .leading, spacing: 16) {
                InfoRow(icon: "phone.fill", label: "Phone", value: formatFieldValue(viewModel.patient?.phoneNumber))
                Divider()
                InfoRow(icon: "envelope.fill", label: "Email", value: viewModel.patient?.email ?? "Not provided")
                if let address = viewModel.patient?.address, !address.isEmpty {
                    Divider()
                    InfoRow(icon: "mappin.and.ellipse", label: "Address", value: address)
                }
            }
        }
    }
    
    @ViewBuilder
    private func buildMedicalHistoryCard() -> some View {
        InfoCardContainer(title: "Medical Data", icon: "cross.case.fill") {
            VStack(alignment: .leading, spacing: 20) {
                // Conditions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Conditions")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    TagCloudView(tags: viewModel.patient?.medicalHistory ?? [], emptyText: "No known conditions")
                }
                
                // Allergies
                VStack(alignment: .leading, spacing: 8) {
                    Text("Allergies")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    TagCloudView(
                        tags: viewModel.patient?.allergies ?? [],
                        emptyText: "No known allergies",
                        tagColor: AppTheme.warning
                    )
                }
                
                // Medications
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Medications")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    TagCloudView(
                        tags: viewModel.patient?.currentMedications ?? [],
                        emptyText: "No current medications",
                        tagColor: AppTheme.primary
                    )
                }
                
                Divider()
                
                // View Records Button
                NavigationLink(destination: DoctorMedicalHistoryView(patientId: patientId, patientName: viewModel.patient?.fullName ?? patientName)) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 15))
                        Text("View Medical Records")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.primary)
                    .padding(14)
                    .background(AppTheme.primary.opacity(0.08))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private func buildAppointmentHistory() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Appointments")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            
            if viewModel.upcomingAppointments.isEmpty && viewModel.pastAppointments.isEmpty {
                Text("No appointment records with this patient.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.top, 10)
            } else {
                // Upcoming
                ForEach(Array(viewModel.upcomingAppointments.enumerated()), id: \.element.id) { index, appt in
                    AppointmentHistoryRow(appointment: appt)
                        .offset(y: appearAnimation ? 0 : 50)
                        .opacity(appearAnimation ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.1), value: appearAnimation)
                }
                
                if !viewModel.pastAppointments.isEmpty && !viewModel.upcomingAppointments.isEmpty {
                    Divider().padding(.vertical, 8)
                }
                
                // Past
                ForEach(Array(viewModel.pastAppointments.enumerated()), id: \.element.id) { index, appt in
                    AppointmentHistoryRow(appointment: appt)
                        .opacity(0.65) // fade past appointments
                        .offset(y: appearAnimation ? 0 : 50)
                        .opacity(appearAnimation ? 0.65 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index + viewModel.upcomingAppointments.count) * 0.1), value: appearAnimation)
                }
            }
        }
    }
    
    // CustomNavBar removed — using native .toolbar instead
    
    // MARK: - Helpers
    private func formatFieldValue(_ val: String?) -> String {
        let v = (val ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if v.isEmpty || v == "Not Set" { return "Not provided" }
        return v
    }
    
    private func animateCounters() {
        guard targetHeight > 0 || targetWeight > 0 else { return }
        // Simple counter loop
        let steps = 20
        let hStep = max(1, targetHeight / steps)
        let wStep = max(1, targetWeight / steps)
        
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.04) {
                if i == steps {
                    statsCountValues[0] = targetHeight
                    statsCountValues[1] = targetWeight
                } else {
                    statsCountValues[0] = min(statsCountValues[0] + hStep, targetHeight)
                    statsCountValues[1] = min(statsCountValues[1] + wStep, targetWeight)
                }
            }
        }
    }
}

// MARK: - View Components

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var accentColor: Color = AppTheme.primary
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(accentColor)
            }
            
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(AppTheme.cardSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
    }
}

struct InfoCardContainer<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.primary)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }
            
            content
        }
        .padding(20)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                .font(.system(size: 16))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
    }
}

struct TagCloudView: View {
    let tags: [String]
    let emptyText: String
    var tagColor: Color = AppTheme.success
    
    var body: some View {
        if tags.isEmpty {
            Text(emptyText)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                .italic()
        } else {
            // Flow layout approximation
            // For true flow layout in ancient SwiftUI forms we'd need a custom grid, 
            // but for simplicity we'll use a wrapping implementation
            WrappingHStack(models: tags, viewGenerator: { tag in
                Text(tag)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(tagColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(tagColor.opacity(0.12))
                    .cornerRadius(8)
            })
        }
    }
}

struct AppointmentHistoryRow: View {
    let appointment: Appointment
    
    var isUpcoming: Bool {
        let s = appointment.status.lowercased()
        return s == "scheduled" || s == "in-progress" || s == "in_progress"
    }
    
    var statusColor: Color {
        switch appointment.status.lowercased() {
        case "completed": return AppTheme.textSecondary
        case "cancelled": return AppTheme.error
        case "in-progress", "in_progress": return AppTheme.warning
        default: return AppTheme.success // scheduled
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Date block
            VStack(spacing: 4) {
                let parts = appointment.date.split(separator: "-")
                if parts.count == 3 {
                    Text(String(parts[2])) // Day
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(isUpcoming ? AppTheme.primary : AppTheme.textSecondary)
                    Text(monthName(String(parts[1]))) // Month
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(appointment.department ?? "Consultation")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Text(appointment.status.capitalized)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12))
                        .cornerRadius(6)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                    Text("\(appointment.startTime) - \(appointment.endTime)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
    }
    
    private func monthName(_ monthNum: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM"
        if let date = formatter.date(from: monthNum) {
            formatter.dateFormat = "MMM"
            return formatter.string(from: date).uppercased()
        }
        return monthNum
    }
}

// MARK: - Skeleton View
struct PatientDetailSkeletonView: View {
    @State private var shimmer = false
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 180, height: 26)
                
                HStack(spacing: 12) {
                    ForEach(0..<3) { _ in
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 30)
                    }
                }
            }
            .padding(.top, 40)
            
            HStack(spacing: 16) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 90)
                }
            }
            .padding(.horizontal, 24)
            
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 180)
                .padding(.horizontal, 24)
        }
        .opacity(shimmer ? 0.4 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

// A simple Error View
struct ErrorStateView: View {
    let error: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.error)
            Text(error)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Retry", action: retryAction)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.primary)
                .padding(.vertical, 8)
                .padding(.horizontal, 24)
                .background(AppTheme.primary.opacity(0.15))
                .cornerRadius(8)
        }
        .padding(40)
    }
}

// Simple Wrapping HStack for Tags
struct WrappingHStack<Model, V>: View where Model: Hashable, V: View {
    typealias ViewGenerator = (Model) -> V
    var models: [Model]
    var viewGenerator: ViewGenerator
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8
    
    @State private var totalHeight: CGFloat = .zero
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)
    }
    
    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            ForEach(self.models, id: \.self) { models in
                self.viewGenerator(models)
                    .padding(.horizontal, self.horizontalSpacing/2)
                    .padding(.vertical, self.verticalSpacing/2)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > g.size.width) {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if models == self.models.last! {
                            width = 0 //last item
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { d in
                        let result = height
                        if models == self.models.last! {
                            height = 0 // last item
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
    }
    
    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}

