import SwiftUI

struct AdminPatientSearchView: View {
    @State private var patients: [HMSUser] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var animate = false

    var filteredPatients: [HMSUser] {
        if searchText.isEmpty { return patients }
        return patients.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    HMSSearchBar(placeholder: "Search patients by name or email...", text: $searchText)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 12)

                    // Patient count header
                    if !isLoading && !patients.isEmpty {
                        HStack {
                            Text(searchText.isEmpty ? "All Patients" : "Results")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("(\(filteredPatients.count))")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }

                    if isLoading {
                        Spacer()
                        ProgressView("Loading patients...")
                            .tint(AppTheme.primary)
                        Spacer()
                    } else if filteredPatients.isEmpty {
                        Spacer()
                        VStack(spacing: 14) {
                            Image(systemName: "person.crop.circle.badge.xmark")
                                .font(.system(size: 44))
                                .foregroundColor(AppTheme.primaryMid.opacity(0.3))
                            Text(searchText.isEmpty ? "No patients found" : "No results found")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 10) {
                                ForEach(Array(filteredPatients.enumerated()), id: \.element.id) { index, patient in
                                    NavigationLink(destination: AdminPatientDetailView(patientUser: patient)) {
                                        PatientRowView(patient: patient)
                                    }
                                    .buttonStyle(.plain)
                                    .offset(y: animate ? 0 : 20)
                                    .opacity(animate ? 1 : 0)
                                    .animation(
                                        .spring(response: 0.45, dampingFraction: 0.8)
                                        .delay(Double(index) * 0.04),
                                        value: animate
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationTitle("Manage Patients")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task {
                fetchPatients()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        animate = true
                    }
                }
            }
        .toolbar(.hidden, for: .tabBar)
    }

    private func fetchPatients() {
        isLoading = true
        Task {
             do {
                 let list = try await AuthManager.shared.fetchPatients()
                 withAnimation(.spring()) {
                     patients = list
                 }
             } catch {
                 errorMessage = error.localizedDescription
                 showError = true
             }
             isLoading = false
        }
    }
}

// MARK: - Patient Row View
struct PatientRowView: View {
    let patient: HMSUser

    private var initials: String {
        let parts = patient.fullName.components(separatedBy: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        return String(patient.fullName.prefix(2)).uppercased()
    }

    var body: some View {
        HStack(spacing: 14) {
            // Initials avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.primaryDark.opacity(0.2), AppTheme.primaryDark.opacity(0.1)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                Text(initials)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryDark)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(patient.fullName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 6) {
                    Text(patient.email)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            
            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary.opacity(0.4))
        }
        .padding(16)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}
