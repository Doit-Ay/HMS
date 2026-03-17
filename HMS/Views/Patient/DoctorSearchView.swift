import SwiftUI

// MARK: - Doctor Search View
struct DoctorSearchView: View {

    @State private var searchText = ""
    @State private var doctors: [HMSUser] = []
    @State private var filteredDoctors: [HMSUser] = []
    @State private var isLoading = true
    @State private var animate = false

    // Filter states
    @State private var showFilterSheet = false
    @State private var selectedDepartment: String? = nil
    @State private var departments: [String] = []

    var body: some View {

        ZStack {
            HMSBackground()

            VStack(spacing: 0) {

                // MARK: Search Bar
                HStack(spacing: 12) {

                    HStack(spacing: 10) {

                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.textSecondary)

                        TextField("Search doctors or specialization", text: $searchText)
                            .onChange(of: searchText) { _ in applyFilters() }
                    }
                    .padding()
                    .background(.white)
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)

                    // MARK: Filter Button
                    Button {

                        showFilterSheet = true

                    } label: {

                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.primary)
                            .frame(width: 44, height: 44)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)

                // MARK: Doctor List
                if isLoading {

                    Spacer()

                    ProgressView("Loading Doctors...")
                        .tint(AppTheme.primary)

                    Spacer()

                } else {

                    ScrollView(showsIndicators: false) {

                        LazyVStack(spacing: 16) {

                            ForEach(Array(filteredDoctors.enumerated()), id: \.element.id) { index, doctor in

                                NavigationLink(
                                    destination: BookAppointmentView(doctor: doctor)
                                ) {

                                    DoctorProfileCard(doctor: doctor)
                                }
                                .buttonStyle(.plain)
                                .offset(y: animate ? 0 : 25)
                                .opacity(animate ? 1 : 0)
                                .animation(
                                    .spring(response: 0.45, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.05),
                                    value: animate
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {

            NavigationStack {

                ZStack {

                    AppTheme.background
                        .ignoresSafeArea()

                    List {

                        Button {

                            selectedDepartment = nil
                            applyFilters()
                            showFilterSheet = false

                        } label: {

                            HStack {

                                Text("All Departments")
                                    .foregroundColor(AppTheme.textPrimary)

                                Spacer()

                                if selectedDepartment == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppTheme.primary)
                                }
                            }
                        }

                        ForEach(departments, id: \.self) { dept in

                            Button {

                                selectedDepartment = dept
                                applyFilters()
                                showFilterSheet = false

                            } label: {

                                HStack {

                                    Text(dept)
                                        .foregroundColor(AppTheme.textPrimary)

                                    Spacer()

                                    if selectedDepartment == dept {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AppTheme.primary)
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
                .navigationTitle("Filter by Department")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(AppTheme.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
            }
            .presentationDetents([.medium])   // Half screen
            .presentationDragIndicator(.visible)
        }
        .onAppear { loadDoctors() }
        .navigationTitle("Book Appointment")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Load Doctors
    private func loadDoctors() {

        Task {
            do {

                let result = try await AuthManager.shared.fetchDoctors()

                doctors = result

                // Extract unique departments
                departments = Array(Set(result.compactMap { $0.department })).sorted()

                applyFilters()

            } catch {

                print(error.localizedDescription)
            }

            isLoading = false

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animate = true
            }
        }
    }

    // MARK: Apply Filters
    private func applyFilters() {

        var result = doctors

        // Department filter
        if let dept = selectedDepartment {
            result = result.filter { $0.department == dept }
        }

        // Search filter
        if !searchText.isEmpty {

            let query = searchText.lowercased()

            result = result.filter {

                $0.fullName.lowercased().contains(query) ||
                ($0.specialization?.lowercased().contains(query) ?? false) ||
                ($0.department?.lowercased().contains(query) ?? false)

            }
        }

        filteredDoctors = result
    }
}


// MARK: - Doctor Profile Card (New Design)
struct DoctorProfileCard: View {

    let doctor: HMSUser

    var body: some View {

        HStack(spacing: 16) {

            // MARK: Doctor Image
            ZStack {

                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.primary.opacity(0.08))
                    .frame(width: 95, height: 105)

                if let url = doctor.profileImageURL,
                   let imageURL = URL(string: url) {

                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        doctorPlaceholderImage(for: doctor.gender)
                    }

                } else {
                    doctorPlaceholderImage(for: doctor.gender)
                }
            }
            .frame(width: 95, height: 105)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // MARK: Doctor Details
            VStack(alignment: .leading, spacing: 6) {

                // Rating
                HStack(spacing: 4) {

                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)

                    Text("4.9")
                        .font(.system(size: 13, weight: .semibold))

                    Text("• 44 reviews")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }

                // Doctor Name
                Text("Dr. \(doctor.fullName)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(2)

                // Specialization
                if let specialization = doctor.department {

                    Text(specialization)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textSecondary)
                }

                // Experience
                HStack(spacing: 6) {

                    Image(systemName: "stethoscope")
                        .font(.system(size: 12))

                    Text("Experience: 5 years")
                        .font(.system(size: 13))
                }
                .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

#Preview {
    NavigationStack {
        DoctorSearchView()
    }
}

// MARK: - Doctor Placeholder Image Helper
@ViewBuilder
func doctorPlaceholderImage(for gender: String?) -> some View {
    let g = gender?.lowercased() ?? ""
    if g == "male" {
        Image("doctor_placeholder_male")
            .resizable()
            .scaledToFill()
    } else if g == "female" {
        Image("doctor_placeholder_female")
            .resizable()
            .scaledToFill()
    } else {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(AppTheme.primaryDark.opacity(0.5))
            .padding(20)
    }
}
