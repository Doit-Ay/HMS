import SwiftUI

struct AdminPatientDetailView: View {
    let patientUser: HMSUser
    
    @State private var profile: PatientProfile?
    @State private var isLoading = true
    @State private var animate = false
    
    // Computed Helpers
    private var ageString: String {
        if let age = profile?.age, age > 0 { return "\(age)" }
        guard let dobString = profile?.dateOfBirth, !dobString.isEmpty, dobString != "Not Set" else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let dobDate = formatter.date(from: dobString) {
            let years = Calendar.current.dateComponents([.year], from: dobDate, to: Date()).year ?? 0
            return "\(years)"
        }
        return "—"
    }

    private func safeValue(_ val: String?, fallback: String = "—") -> String {
        let v = (val ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if v.isEmpty || v == "Not Set" { return fallback }
        return v
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            if isLoading {
                ProgressView("Loading Profile...")
                    .tint(AppTheme.primary)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.primary.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                Text(String(patientUser.fullName.prefix(1)))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.primary)
                            }
                            
                            VStack(spacing: 4) {
                                Text(patientUser.fullName)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                Text(patientUser.email)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                                Text(safeValue(profile?.phoneNumber))
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        .padding(.top, 24)
                        .offset(y: animate ? 0 : 20)
                        .opacity(animate ? 1 : 0)
                        
                        // Clinical Information Pills
                        HStack(spacing: 16) {
                            AdminInfoPill(title: "Age", value: ageString)
                            AdminInfoPill(title: "Blood", value: safeValue(profile?.bloodGroup))
                            AdminInfoPill(title: "Height", value: safeValue(profile?.height))
                            AdminInfoPill(title: "Weight", value: safeValue(profile?.weight))
                        }
                        .padding(.horizontal, 24)
                        .offset(y: animate ? 0 : 20)
                        .opacity(animate ? 1 : 0)
                        
                        // Action Cards (Medical Records, Prescriptions)
                        VStack(spacing: 16) {
                            NavigationLink(destination: AdminMedicalRecordsView(patientId: patientUser.id, patientName: patientUser.fullName)) {
                                AdminActionCard(icon: "folder.fill", title: "Medical Records", subtitle: "View uploaded health documents and results", color: AppTheme.primary)
                            }
                            .buttonStyle(.plain)
                            
                            NavigationLink(destination: AdminPrescriptionsView(patientId: patientUser.id, patientName: patientUser.fullName)) {
                                AdminActionCard(icon: "pills.fill", title: "Prescriptions", subtitle: "View complete prescription history", color: AppTheme.primaryDark)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .offset(y: animate ? 0 : 20)
                        .opacity(animate ? 1 : 0)
                        
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Patient Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchPatientData()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animate = true
            }
        }
    }
    
    private func fetchPatientData() async {
        do {
            let fetchedProfile = try await DoctorPatientRepository.shared.fetchPatientProfile(patientId: patientUser.id)
            withAnimation {
                self.profile = fetchedProfile
                self.isLoading = false
            }
        } catch {
            print("Failed to fetch patient profile: \(error.localizedDescription)")
            withAnimation {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Reusable UI Components
struct AdminInfoPill: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

struct AdminActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(AppTheme.textSecondary.opacity(0.4))
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(22)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}
