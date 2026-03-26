import SwiftUI
import PhotosUI
import FirebaseFirestore

struct DoctorProfileView: View {
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showSaveToast = false
    @State private var appearAnimation = false
    @State private var isLoadingProfile = true
    
    @Environment(\.dismiss) private var dismiss
    
    // Profile photo
    @State private var profileImage = "Dr. S"
    @State private var profileImageURL: String? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isUploadingPhoto = false
    
    // Dynamic form data populated on load
    @State private var personalFields: [ProfileInfoField] = []
    @State private var professionalFields: [ProfileInfoField] = []
    @State private var contactFields: [ProfileInfoField] = []
    
    // Header labels
    @State private var profileName: String = "Loading..."
    @State private var profileSpecialty: String = "Specialty"
    
    // Stats labels
    @State private var rating: String = "Not Set"
    @State private var totalPatients: String = "..."
    @State private var totalAppointments: String = "..."
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    // 1. Hero Section
                    ZStack(alignment: .bottom) {
                        // Gradient background
                        LinearGradient(
                            colors: [AppTheme.primaryLight.opacity(0.8), AppTheme.background],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 160)
                        
                        // Top Nav Buttons
                        VStack {
                            HStack(spacing: 12) {
                                Spacer()
                                
                                if !isLoadingProfile {
                                    // Edit/Save Button
                                    Button(action: toggleEditMode) {
                                        if isSaving {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(AppTheme.primary)
                                                .clipShape(Capsule())
                                        } else if isEditing {
                                            Text("Save")
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(AppTheme.primary)
                                                .clipShape(Capsule())
                                                .shadow(color: AppTheme.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                                        } else {
                                            Image(systemName: "pencil")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(AppTheme.textPrimary)
                                                .frame(width: 44, height: 44)
                                                .background(AppTheme.cardSurface)
                                                .clipShape(Circle())
                                                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                                        }
                                    }
                                }
                                
                                // Close Button
                                Button(action: { dismiss() }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppTheme.textPrimary)
                                        .frame(width: 44, height: 44)
                                        .background(AppTheme.cardSurface)
                                        .clipShape(Circle())
                                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            Spacer()
                        }
                        
                        // Overlapping Avatar + Title
                        VStack(spacing: 8) {
                            ProfilePhotoView(
                                initial: profileImage,
                                imageURL: profileImageURL,
                                isEditing: isEditing,
                                isUploading: isUploadingPhoto,
                                selectedItem: $selectedPhotoItem
                            )
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                    
                    if isLoadingProfile {
                        // Loading skeleton
                        VStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.12))
                                .frame(width: 100, height: 16)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.12))
                                .frame(width: 180, height: 28)
                            
                            HStack(spacing: 16) {
                                ForEach(0..<3) { _ in
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.08))
                                        .frame(height: 70)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            
                            ForEach(0..<3) { _ in
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.06))
                                    .frame(height: 100)
                                    .padding(.horizontal, 24)
                            }
                        }
                        .padding(.top, 50)
                    } else {
                        VStack(spacing: 4) {
                            Text(profileSpecialty)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                            
                            Text(profileName)
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        .padding(.top, 50)
                        .offset(y: appearAnimation ? 0 : 20)
                        .opacity(appearAnimation ? 1 : 0)
                        
                        // 2. Stats Bar
                        DoctorStatsBar(
                            rating: rating,
                            totalPatients: totalPatients,
                            appointments: totalAppointments
                        )
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .offset(y: appearAnimation ? 0 : 30)
                            .opacity(appearAnimation ? 1 : 0)
                        
                        // 3. Info Cards & Sign Out
                        VStack(spacing: 20) {
                            ProfileInfoCard(title: "Personal", fields: $personalFields, isEditing: isEditing)
                            ProfileInfoCard(title: "Professional", fields: $professionalFields, isEditing: isEditing)
                            ProfileInfoCard(title: "Contact", fields: $contactFields, isEditing: isEditing)
                            
                            // Sign Out Button
                            if !isEditing {
                                Button(action: {
                                    try? AuthManager.shared.signOut()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Sign Out")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                    }
                                    .foregroundColor(Color.red.opacity(0.8))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(AppTheme.cardSurface)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                                }
                                .padding(.top, 12)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, isEditing ? 40 : 100)
                        .offset(y: appearAnimation ? 0 : 40)
                        .opacity(appearAnimation ? 1 : 0)
                    }
                }
            }
            
            // 4. Removed Bottom CTA
        }
        .navigationBarHidden(true)
        .task {
            await loadAllProfileData()
        }
        .alert("Success", isPresented: $showSaveToast) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Profile updated successfully")
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let item = newItem,
                  let userId = UserSession.shared.currentUser?.id else { return }
            Task {
                isUploadingPhoto = true
                do {
                    let url = try await ProfilePhotoManager.shared.uploadProfilePhoto(pickerItem: item, userId: userId)
                    await MainActor.run {
                        profileImageURL = url
                        isUploadingPhoto = false
                        selectedPhotoItem = nil
                    }
                } catch {
                    print("❌ Photo upload failed: \(error)")
                    await MainActor.run {
                        isUploadingPhoto = false
                        selectedPhotoItem = nil
                    }
                }
            }
        }
    }
    
    
    /// Single entry point: load everything, then reveal with animation
    private func loadAllProfileData() async {
        guard let user = UserSession.shared.currentUser else {
            isLoadingProfile = false
            return
        }
        
        let db = FirebaseFirestore.Firestore.firestore()
        
        // Fetch doctor profile + stats in parallel
        async let profileResult: Void = loadDoctorProfile(db: db, user: user)
        async let statsResult: Void = fetchDoctorStats()
        
        _ = await (profileResult, statsResult)
        
        // Reveal content with animation (single transition, no flicker)
        withAnimation(.easeOut(duration: 0.5)) {
            isLoadingProfile = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.5)) {
                appearAnimation = true
            }
        }
    }
    
    private func loadDoctorProfile(db: Firestore, user: HMSUser) async {
        do {
            let doc = try await db.collection("doctors").document(user.id).getDocument()
            guard let data = doc.data() else {
                // Fallback to session data
                await populateFromSession(user: user)
                return
            }
            
            let fullName       = data["fullName"]       as? String ?? user.fullName
            let dob            = data["dateOfBirth"]    as? String ?? "Not Set"
            let gender         = data["gender"]         as? String ?? "Not Set"
            let specialty      = data["specialization"] as? String ?? "Not Set"
            let phone          = data["phoneNumber"]    as? String ?? "Not Set"
            let email          = data["email"]          as? String ?? user.email
            let department     = data["department"]     as? String ?? "Not Set"
            let dateJoined     = data["createdAt"]      as? Timestamp
            let avgRating      = data["averageRating"]  as? Double
            
            await MainActor.run {
                profileName = fullName.hasPrefix("Dr.") ? fullName : "Dr. \(fullName)"
                profileSpecialty = (department != "Not Set") ? department : (specialty != "Not Set" ? specialty : "Consultation")
                profileImage = String(fullName.replacingOccurrences(of: "Dr. ", with: "").prefix(1))
                profileImageURL = data["profileImageURL"] as? String ?? user.profileImageURL
                
                if let r = avgRating, r > 0 {
                    rating = String(format: "%.1f", r)
                } else {
                    rating = "N/A"
                }
                
                personalFields = [
                    ProfileInfoField(title: "Full Name", value: fullName),
                    ProfileInfoField(title: "Date of Birth", value: dob, isDateField: true),
                    ProfileInfoField(title: "Gender", value: gender, options: ["Male", "Female", "Other"])
                ]
                
                professionalFields = [
                    ProfileInfoField(title: "Department", value: department, options: ["Cardiology", "Neurology", "Pediatrics", "General Medicine", "Orthopedics", "Dermatology", "ENT", "Ophthalmology"]),
                    ProfileInfoField(title: "Date Joined", value: dateJoined != nil ? formatDate(dateJoined!.dateValue()) : "Unknown", isEditable: false)
                ]
                
                contactFields = [
                    ProfileInfoField(title: "Phone Number", value: phone, keyboardType: .phonePad),
                    ProfileInfoField(title: "Email Address", value: email, isEditable: false, keyboardType: .emailAddress)
                ]
            }
        } catch {
            print("Error loading doctor profile: \(error)")
            await populateFromSession(user: user)
        }
    }
    
    private func populateFromSession(user: HMSUser) async {
        await MainActor.run {
            profileName = user.fullName.hasPrefix("Dr.") ? user.fullName : "Dr. \(user.fullName)"
            profileSpecialty = user.department ?? user.specialization ?? "Consultation"
            profileImage = String(user.fullName.replacingOccurrences(of: "Dr. ", with: "").prefix(1))
            profileImageURL = user.profileImageURL
            
            if let r = user.averageRating, r > 0 {
                rating = String(format: "%.1f", r)
            } else {
                rating = "N/A"
            }
            
            personalFields = [
                ProfileInfoField(title: "Full Name", value: user.fullName),
                ProfileInfoField(title: "Date of Birth", value: user.dateOfBirth ?? "Not Set", isDateField: true),
                ProfileInfoField(title: "Gender", value: user.gender ?? "Not Set", options: ["Male", "Female", "Other"])
            ]
            professionalFields = [
                ProfileInfoField(title: "Department", value: user.department ?? "Not Set", options: ["Cardiology", "Neurology", "Pediatrics", "General Medicine", "Orthopedics", "Dermatology", "ENT", "Ophthalmology"]),
                ProfileInfoField(title: "Date Joined", value: formatDate(user.createdAt), isEditable: false)
            ]
            contactFields = [
                ProfileInfoField(title: "Phone Number", value: user.phoneNumber ?? "Not Set", keyboardType: .phonePad),
                ProfileInfoField(title: "Email Address", value: user.email, isEditable: false, keyboardType: .emailAddress)
            ]
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func fetchDoctorStats() async {
        guard let user = UserSession.shared.currentUser else { return }
        let db = FirebaseFirestore.Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("appointments")
                .whereField("doctorId", isEqualTo: user.id)
                .getDocuments()
            
            let count = snapshot.documents.count
            
            // Calculate unique patients by mapping to patientId and converting to Set
            let uniquePatientIds = Set(snapshot.documents.compactMap { doc -> String? in
                return doc.data()["patientId"] as? String
            })
            
            await MainActor.run {
                self.totalAppointments = "\(count)"
                self.totalPatients = "\(uniquePatientIds.count)"
            }
        } catch {
            print("Error fetching dynamic doctor stats: \(error)")
            await MainActor.run {
                self.totalAppointments = "0"
                self.totalPatients = "0"
            }
        }
    }
    
    private func toggleEditMode() {
        if isEditing {
            // Save Action
            isSaving = true
            Task {
                guard let uid = UserSession.shared.currentUser?.id else {
                    await MainActor.run { isSaving = false }
                    return
                }
                
                let fullName = personalFields.first(where: { $0.title == "Full Name" })?.value ?? ""
                let dob = personalFields.first(where: { $0.title == "Date of Birth" })?.value
                let gender = personalFields.first(where: { $0.title == "Gender" })?.value
                let department = professionalFields.first(where: { $0.title == "Department" })?.value
                let phone = contactFields.first(where: { $0.title == "Phone Number" })?.value
                let safePhone = (phone == "Not Set" || phone?.isEmpty == true) ? nil : phone
                
                do {
                    try await AuthManager.shared.updateCurrentDoctorProfile(
                        uid: uid,
                        fullName: fullName,
                        department: department,
                        phoneNumber: safePhone,
                        dateOfBirth: dob,
                        gender: gender
                    )
                    
                    await MainActor.run {
                        self.isSaving = false
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            self.isEditing = false
                        }
                        
                        // Sync header display from edited fields
                        let updatedName = self.personalFields.first(where: { $0.title == "Full Name" })?.value ?? ""
                        self.profileName = updatedName.hasPrefix("Dr.") ? updatedName : "Dr. \(updatedName)"
                        self.profileImage = String(updatedName.replacingOccurrences(of: "Dr. ", with: "").prefix(1))
                        if let dept = self.professionalFields.first(where: { $0.title == "Department" })?.value, dept != "Not Set" {
                            self.profileSpecialty = dept
                        }
                        self.triggerToast()
                    }
                } catch {
                    print("Error saving profile: \(error.localizedDescription)")
                    await MainActor.run {
                        self.isSaving = false
                    }
                }
            }
        } else {
            // Enter Edit Mode Action
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isEditing = true
            }
        }
    }
    
    private func triggerToast() {
        showSaveToast = true
    }
}

#Preview {
    DoctorProfileView()
}
