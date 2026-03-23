import SwiftUI
import FirebaseFirestore

// MARK: - Patient Tab View
struct PatientTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PatientHomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

//            NavigationStack {
//                ProfileView()
//            }
//            .tabItem {
//                Label("Profile", systemImage: "person.circle.fill")
//            }
//            .tag(1)
        }
        .tint(AppTheme.primary)
    }
}

// MARK: - Patient Home View
struct PatientHomeView: View {
    @ObservedObject var session = UserSession.shared
    @State private var animate = false
    @State private var upcomingAppointments: [Appointment] = []
    @State private var isLoadingAppointments = true
    @State private var showProfileSheet = false

    var body: some View {
            ZStack(alignment: .top) {

                AppTheme.background
                    .ignoresSafeArea()

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.primaryLight.opacity(0.8), AppTheme.primaryLight.opacity(0.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: -100, y: -200)
                    .blur(radius: 60)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {

                        HeaderProfileView(session: session, showProfile: $showProfileSheet)
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            .offset(y: animate ? 0 : -30)
                            .opacity(animate ? 1 : 0)

                        VStack(spacing: 0) {

                            HStack {
                                VStack(alignment: .leading, spacing: 8) {

                                    Text("Your Health,\nOur Priority")
                                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineSpacing(4)

                                    Text("Find the right doctor and book your appointment easily.")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.9))
                                        .padding(.trailing, 40)
                                }

                                Spacer()
                            }
                            .padding(24)

                            NavigationLink(destination: DoctorSearchView()) {

                                HStack {
                                    Text("Book Appointment")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))

                                    Spacer()

                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 24))
                                }
                                .foregroundColor(AppTheme.primary)
                                .padding()
                                .background(AppTheme.cardSurface)
                                .cornerRadius(16)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 24)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(
                            ZStack {

                                LinearGradient(
                                    colors: [AppTheme.dashboardCardGradientStart, AppTheme.dashboardCardGradientEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )

                                Image(systemName: "cross.case.fill")
                                    .font(.system(size: 180))
                                    .foregroundColor(.white.opacity(0.1))
                                    .offset(x: 100, y: 20)
                                    .rotationEffect(.degrees(-15))
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .shadow(color: AppTheme.dashboardCardGradientStart.opacity(0.25), radius: 20, x: 0, y: 10)
                        .padding(.horizontal, 20)
                        .offset(y: animate ? 0 : 30)
                        .opacity(animate ? 1 : 0)

                        VStack(alignment: .leading, spacing: 20) {

//                            Text("Top Services")
//                                .font(.system(size: 22, weight: .bold, design: .rounded))
//                                .foregroundColor(AppTheme.textPrimary)
//                                .padding(.horizontal, 24)

//                            HStack(spacing: 16) {
//
//                                FeatureTile(icon: "doc.text.fill", title: "Records", color: AppTheme.primaryDark)
//                                FeatureTile(icon: "pills.fill", title: "Lab Tests", color: AppTheme.primaryMid)
////                                FeatureTile(icon: "waveform.path.ecg", title: "Appointments", color: AppTheme.primary)
//                            }
//                            .padding(.horizontal, 20)
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Top Services")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .padding(.horizontal, 24)

                                HStack(spacing: 16) {
                                    // Records Tile with NavigationLink
                                    NavigationLink {
                                        PatientRecordsMainView()
                                    } label: {
                                        FeatureTile(icon: "doc.text.fill", title: "Records", color: AppTheme.primaryDark)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    NavigationLink {
                                        LabTestsView()
                                    } label: {
                                        FeatureTile(icon: "pills.fill", title: "Lab Tests", color: AppTheme.primaryMid)
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    
                                    // Lab Tests Tile (non-navigating for now)
                                    
                                }
                                .padding(.horizontal, 20)
                            }
                            .offset(y: animate ? 0 : 40)
                            .opacity(animate ? 1 : 0)
                        }
                        .offset(y: animate ? 0 : 40)
                        .opacity(animate ? 1 : 0)

//                        VStack(alignment: .leading, spacing: 20) {
//
//                            HStack {
//
//                                Text("Vitals Overview")
//                                    .font(.system(size: 22, weight: .bold, design: .rounded))
//                                    .foregroundColor(AppTheme.textPrimary)
//
//                                Spacer()
//
//                                Button {
//
//                                } label: {
//
//                                    Text("See all")
//                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
//                                        .foregroundColor(AppTheme.primary)
//                                }
//                            }
//                            .padding(.horizontal, 24)
//
//                            VStack(spacing: 16) {
//
//                                VitalRow(
//                                    icon: "heart.fill",
//                                    title: "Heart Rate",
//                                    value: "—",
//                                    unit: "bpm",
//                                    iconColor: .red
//                                )
//
//                                VitalRow(
//                                    icon: "drop.fill",
//                                    title: "Blood Group",
//                                    value: session.currentUser?.bloodGroup ?? "—",
//                                    unit: "",
//                                    iconColor: AppTheme.primary
//                                )
//                            }
//                            .padding(.horizontal, 20)
//                        }
//                        .offset(y: animate ? 0 : 50)
//                        .opacity(animate ? 1 : 0)

                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Text("Upcoming Appointments")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                Spacer()
                                
                                NavigationLink(destination: PatientAppointmentsView()) {
                                    Text("See all")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.primary)
                                }
                            }
                            .padding(.horizontal, 24)
                            
                            if isLoadingAppointments {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding(.vertical, 30)
                                    Spacer()
                                }
                            } else if upcomingAppointments.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 12) {
                                        Image(systemName: "calendar.badge.plus")
                                            .font(.system(size: 32))
                                            .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                                        Text("No upcoming appointments")
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                    .padding(.vertical, 30)
                                    Spacer()
                                }
                            } else {
                                VStack(spacing: 16) {
                                    ForEach(upcomingAppointments.prefix(3)) { appointment in
                                        UpcomingAppointmentCard(appointment: appointment)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .offset(y: animate ? 0 : 60)
                        .opacity(animate ? 1 : 0)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showProfileSheet) {
                PatientProfileView()
            }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                animate = true
            }
        }
        .task {
            await fetchUpcomingAppointments()
        }
    }
    
    private func fetchUpcomingAppointments() async {
        guard let userId = session.currentUser?.id else {
            await MainActor.run { isLoadingAppointments = false }
            return
        }
        
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("appointments")
                .whereField("patientId", isEqualTo: userId)
                .whereField("status", in: ["scheduled"])
                .getDocuments()
            
            let fetchedApps = snapshot.documents.compactMap { doc -> Appointment? in
                let data = doc.data()
                return Appointment(
                    id: doc.documentID,
                    slotId: data["slotId"] as? String ?? "",
                    doctorId: data["doctorId"] as? String ?? "",
                    doctorName: data["doctorName"] as? String ?? "",
                    patientId: data["patientId"] as? String ?? "",
                    patientName: data["patientName"] as? String ?? "",
                    department: data["department"] as? String,
                    date: data["date"] as? String ?? "",
                    startTime: data["startTime"] as? String ?? "",
                    endTime: data["endTime"] as? String ?? "",
                    status: data["status"] as? String ?? ""
                )
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            
            // Sort by date and time
            let sortedApps = fetchedApps.sorted { app1, app2 in
                if app1.date != app2.date {
                    return app1.date < app2.date
                }
                return app1.startTime < app2.startTime
            }
            
            // Filter future or ongoing appointments today
            let nowStr = formatter.string(from: Date())
            let filteredApps = sortedApps.filter { "\($0.date) \($0.endTime)" >= nowStr }
            
            await MainActor.run {
                self.upcomingAppointments = filteredApps
                withAnimation {
                    self.isLoadingAppointments = false
                }
            }
        } catch {
            print("Error fetching appointments: \(error)")
            await MainActor.run {
                withAnimation {
                    self.isLoadingAppointments = false
                }
            }
        }
    }
}

// MARK: - Upcoming Appointment Card
struct UpcomingAppointmentCard: View {
    let appointment: Appointment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 12) {
                    Circle()
                        .fill(AppTheme.primaryLight.opacity(0.3))
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: "stethoscope")
                                .foregroundColor(AppTheme.primaryDark)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appointment.doctorName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text(appointment.department ?? "General")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                
                Spacer()
                
                // Status badge
                Text("Upcoming")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryDark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.primaryLight)
                    .clipShape(Capsule())
            }
            
            Divider()
                .background(Color.gray.opacity(0.1))
            
            HStack(spacing: 24) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundColor(AppTheme.primary)
                        .font(.system(size: 14))
                    Text(formatDate(appointment.date))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(AppTheme.primary)
                        .font(.system(size: 14))
                    Text("\(appointment.startTime) - \(appointment.endTime)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: AppTheme.textSecondary.opacity(0.08), radius: 10, x: 0, y: 4)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inputFormatter.date(from: dateString) else { return dateString }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMM d, yyyy"
        return outputFormatter.string(from: date)
    }
}

// MARK: - Vital Row (FIX ADDED)
struct VitalRow: View {

    let icon: String
    let title: String
    let value: String
    let unit: String
    let iconColor: Color

    var body: some View {

        HStack(spacing: 16) {

            ZStack {

                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 4) {

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                Text(value + (unit.isEmpty ? "" : " \(unit)"))
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: AppTheme.textSecondary.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Header Profile View
struct HeaderProfileView: View {

    @ObservedObject var session: UserSession
    @Binding var showProfile: Bool

    var body: some View {

        HStack {

            VStack(alignment: .leading, spacing: 6) {

                Text(Date().formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.primary)
                    .textCase(.uppercase)

                HStack(spacing: 6) {

                    Text("Hi,")
                        .font(.system(size: 28, weight: .regular, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)

                    Text(session.currentUser?.fullName.components(separatedBy: " ").first ?? "Patient")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }

            Spacer()

            // MARK: Profile Button — opens as bottom sheet
            Button {
                showProfile = true
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
}

// MARK: - Feature Tile
//struct FeatureTile: View {
//
//    let icon: String
//    let title: String
//    let color: Color
//
//    var body: some View {
//
//        Button {} label: {
//
//            VStack(spacing: 16) {
//
//                ZStack {
//
//                    Circle()
//                        .fill(color.opacity(0.15))
//                        .frame(width: 54, height: 54)
//
//                    Image(systemName: icon)
//                        .font(.system(size: 24, weight: .semibold))
//                        .foregroundColor(color)
//                }
//
//                Text(title)
//                    .font(.system(size: 14, weight: .bold, design: .rounded))
//                    .foregroundColor(AppTheme.textPrimary)
//            }
//            .frame(maxWidth: .infinity)
//            .padding(.vertical, 24)
//            .background(AppTheme.cardSurface)
//            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
//            .shadow(color: AppTheme.textSecondary.opacity(0.08), radius: 15, x: 0, y: 8)
//        }
//        .buttonStyle(.plain)
//    }
//}

// MARK: - Feature Tile
struct FeatureTile: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 54, height: 54)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: AppTheme.textSecondary.opacity(0.08), radius: 15, x: 0, y: 8)
    }
}

#Preview {
    PatientTabView()
}
