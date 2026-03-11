import SwiftUI

// MARK: - Doctor Search View (Patient Booking Flow — Step 1)
struct DoctorSearchView: View {
    @State private var searchText = ""
    @State private var doctors: [HMSUser] = []
    @State private var filteredDoctors: [HMSUser] = []
    @State private var isLoading = true
    @State private var showFilter = false
    @State private var selectedDepartment: String? = nil
    @State private var animate = false
    
    private var allDepartments: [String] {
        Array(Set(doctors.compactMap { $0.department })).sorted()
    }
    
    var body: some View {
        ZStack {
            HMSBackground()
            
            VStack(spacing: 0) {
                // Search + Filter bar
                HStack(spacing: 12) {
                    // Search field
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                        
                        TextField("Search doctors...", text: $searchText)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                            .onChange(of: searchText) { _ in applyFilters() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
                    
                    // Filter button
                    Button(action: { showFilter.toggle() }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedDepartment != nil ? AppTheme.primary : Color.white)
                                .frame(width: 48, height: 48)
                                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
                            
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(selectedDepartment != nil ? .white : AppTheme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
                
                // Active filter chip
                if let dept = selectedDepartment {
                    HStack(spacing: 8) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.primary)
                        Text(dept)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.primary)
                        Button(action: {
                            withAnimation { selectedDepartment = nil; applyFilters() }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.primary.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Doctor list
                if isLoading {
                    Spacer()
                    ProgressView("Finding doctors...")
                        .tint(AppTheme.primary)
                    Spacer()
                } else if filteredDoctors.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 40))
                            .foregroundColor(AppTheme.textSecondary.opacity(0.3))
                        Text("No doctors found")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                        if !searchText.isEmpty || selectedDepartment != nil {
                            Text("Try adjusting your search or filters")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                        }
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(filteredDoctors.enumerated()), id: \.element.id) { index, doctor in
                                NavigationLink(destination: BookAppointmentView(doctor: doctor)) {
                                    DoctorSearchCard(doctor: doctor)
                                }
                                .buttonStyle(.plain)
                                .offset(y: animate ? 0 : 20)
                                .opacity(animate ? 1 : 0)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.05),
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
        .navigationTitle("Book Appointment")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showFilter) {
            DepartmentFilterSheet(
                departments: allDepartments,
                selected: $selectedDepartment,
                onApply: { applyFilters() }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear { loadDoctors() }
    }
    
    private func loadDoctors() {
        Task {
            do {
                let result = try await AuthManager.shared.fetchDoctors()
                doctors = result
                applyFilters()
            } catch {
                print("⚠️ Error fetching doctors: \(error.localizedDescription)")
            }
            isLoading = false
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animate = true
            }
        }
    }
    
    private func applyFilters() {
        var result = doctors
        
        if let dept = selectedDepartment {
            result = result.filter { $0.department == dept }
        }
        
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.fullName.lowercased().contains(query) ||
                ($0.specialization?.lowercased().contains(query) ?? false) ||
                ($0.department?.lowercased().contains(query) ?? false)
            }
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            filteredDoctors = result
        }
    }
}

// MARK: - Doctor Search Card
struct DoctorSearchCard: View {
    let doctor: HMSUser
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.primary.opacity(0.15), AppTheme.primaryMid.opacity(0.1)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: "stethoscope.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppTheme.primary)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Dr. \(doctor.fullName)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                
                if let spec = doctor.specialization {
                    Text(spec)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.primary)
                        .lineLimit(1)
                }
                
                if let dept = doctor.department {
                    HStack(spacing: 4) {
                        Image(systemName: "building.2")
                            .font(.system(size: 10))
                        Text(dept)
                            .font(.system(size: 12, design: .rounded))
                    }
                    .foregroundColor(AppTheme.textSecondary)
                }
            }
            
            Spacer()
            
            // Arrow
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary.opacity(0.4))
        }
        .padding(16)
        .background(Color.white.opacity(0.85))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Department Filter Sheet
struct DepartmentFilterSheet: View {
    let departments: [String]
    @Binding var selected: String?
    let onApply: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        // "All Departments" option
                        Button(action: {
                            selected = nil
                        }) {
                            HStack {
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.primary)
                                Text("All Departments")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                if selected == nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppTheme.primary)
                                }
                            }
                            .padding(16)
                            .background(selected == nil ? AppTheme.primary.opacity(0.08) : Color.white.opacity(0.6))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(selected == nil ? AppTheme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        ForEach(departments, id: \.self) { dept in
                            Button(action: {
                                selected = dept
                            }) {
                                HStack {
                                    Image(systemName: "building.2.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(selected == dept ? AppTheme.primary : AppTheme.textSecondary)
                                    Text(dept)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    if selected == dept {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppTheme.primary)
                                    }
                                }
                                .padding(16)
                                .background(selected == dept ? AppTheme.primary.opacity(0.08) : Color.white.opacity(0.6))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selected == dept ? AppTheme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
                
                // Apply button
                Button(action: {
                    onApply()
                    dismiss()
                }) {
                    Text("Apply Filter")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.primary)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .navigationTitle("Filter by Department")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    NavigationStack {
        DoctorSearchView()
    }
}
