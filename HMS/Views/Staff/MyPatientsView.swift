import SwiftUI

struct PatientGroup: Identifiable {
    var id: String { patientId }
    let patientId: String
    let patientName: String
    let appointments: [Appointment]
    
    var hasUpcoming: Bool {
        appointments.contains { $0.status.lowercased() == "scheduled" }
    }
    
    var visitCount: Int {
        appointments.count
    }
    
    // Nearest or most recent date for sorting
    var sortDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let dates = appointments.compactMap { formatter.date(from: $0.date) }
        
        if hasUpcoming {
            // Earliest upcoming (smallest date)
            let upcomingDates = appointments
                .filter { $0.status.lowercased() == "scheduled" }
                .compactMap { formatter.date(from: $0.date) }
            return upcomingDates.min() ?? Date.distantFuture
        } else {
            // Most recent past (largest date)
            return dates.max() ?? Date.distantPast
        }
    }
}

struct MyPatientsView: View {
    @State private var allAppointments: [Appointment] = []
    @State private var isLoading = true
    
    // Search State
    @State private var searchText = ""
    
    // UI Animation State
    @State private var appearAnimation = false
    
    // Derived Data
    private var patientGroups: [PatientGroup] {
        // Group by ID
        let dict = Dictionary(grouping: allAppointments, by: { $0.patientId })
        var groups = dict.map { (id, appts) in
            let name = appts.first?.patientName ?? "Unknown"
            return PatientGroup(patientId: id, patientName: name, appointments: appts)
        }
        
        // Search filter
        if !searchText.isEmpty {
            groups = groups.filter { $0.patientName.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Sort by most recent visit
        return groups.sorted { $0.sortDate > $1.sortDate }
    }
    
    
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header & Search
                VStack(spacing: 20) {
                    HStack {
                        Text("My Patients")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    // Search Bar
                    HMSSearchBar(placeholder: "Search patients...", text: $searchText)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
                .offset(y: appearAnimation ? 0 : -20)
                .opacity(appearAnimation ? 1 : 0)
                
                // List Content
                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(AppTheme.primary)
                    Spacer()
                } else if patientGroups.isEmpty {
                    Spacer()
                    // Empty State
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.textSecondary.opacity(0.4))
                        Text("No patients found.")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(patientGroups.enumerated()), id: \.element.id) { index, group in
                                NavigationLink(destination: PatientHistoryView(patientGroup: group)) {
                                    PatientGroupCard(group: group)
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .transition(.asymmetric(insertion: .scale(scale: 0.95).combined(with: .opacity), removal: .opacity))
                                // Staggered Animation Logic
                                .opacity(appearAnimation ? 1 : 0)
                                .offset(y: appearAnimation ? 0 : 30)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05), value: appearAnimation)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                    .refreshable {
                        await reloadAppointmentsAsync()
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if !appearAnimation {
                withAnimation(.easeOut(duration: 0.1)) {
                    appearAnimation = true
                }
                loadAppointments()
            }
        }
    }    
    // For manual refreshable
    private func reloadAppointmentsAsync() async {
        guard let doctorId = UserSession.shared.currentUser?.id else { return }
        do {
            let appointments = try await AuthManager.shared.fetchAllDoctorAppointments(doctorId: doctorId)
            await MainActor.run {
                self.allAppointments = appointments.filter { $0.status != "cancelled" }
            }
        } catch {
            #if DEBUG
            print("Error reloading patients: \(error)")
            #endif
        }
    }
    
    private func loadAppointments() {
        guard let doctorId = UserSession.shared.currentUser?.id else { return }
        isLoading = true
        
        Task {
            do {
                let appointments = try await AuthManager.shared.fetchAllDoctorAppointments(doctorId: doctorId)
                await MainActor.run {
                    self.allAppointments = appointments.filter { $0.status != "cancelled" }
                    withAnimation { self.isLoading = false }
                }
            } catch {
                #if DEBUG
                print("Error loading patients: \(error)")
                #endif
                await MainActor.run { self.isLoading = false }
            }
        }
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Premium Patient Group Card
struct PatientGroupCard: View {
    let group: PatientGroup
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [AppTheme.primaryLight, AppTheme.primary], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 58, height: 58)
                
                LivePatientAvatarInitial(
                    patientId: group.patientId,
                    fallbackName: group.patientName,
                    font: .system(size: 26, design: .rounded),
                    weight: .bold,
                    color: .white
                )
            }
            
            // Middle: Info
            VStack(alignment: .leading, spacing: 6) {
                LivePatientNameView(
                    patientId: group.patientId,
                    fallbackName: group.patientName,
                    font: .system(size: 18, weight: .bold, design: .rounded),
                    weight: .bold,
                    color: AppTheme.textPrimary,
                    lineLimit: 1
                )
                
                Text(formatLastVisitDate(group.sortDate))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
            
            // Right: Visit Count & Chevron
            VStack(alignment: .trailing, spacing: 10) {
                Text("\(group.visitCount) visit\(group.visitCount == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary.opacity(0.4))
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.cardSurface)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        )
    }
    
    private func formatLastVisitDate(_ date: Date) -> String {
        // If the date is distantFuture/distantPast, return generic
        if date == Date.distantFuture || date == Date.distantPast {
            return "No prior visits"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return "Last visit · \(formatter.string(from: date))"
    }
}
