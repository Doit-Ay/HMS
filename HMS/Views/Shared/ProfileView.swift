import SwiftUI
import PhotosUI
import FirebaseFirestore

// MARK: - Shared Profile View (used by admin)
struct ProfileView: View {
    @ObservedObject var session = UserSession.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showSaveToast = false
    @State private var showLogoutAlert = false

    // Profile header
    @State private var profileName = "Loading..."
    @State private var profileImage = "A"
    @State private var roleLabel = ""
    @State private var profileImageURL: String? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isUploadingPhoto = false

    // Editable fields
    @State private var personalFields: [ProfileInfoField] = []
    @State private var contactFields: [ProfileInfoField] = []

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // HERO SECTION
                    ZStack(alignment: .bottom) {
                        LinearGradient(
                            colors: [AppTheme.primaryLight.opacity(0.8), AppTheme.background],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 160)
                        .ignoresSafeArea(edges: .top)

                        // Top buttons
                        VStack {
                            HStack(spacing: 12) {
                                Spacer()

                                Button(action: toggleEditMode) {
                                    if isSaving {
                                        ProgressView()
                                            .tint(.white)
                                    } else if isEditing {
                                        Text("Save")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(AppTheme.primary)
                                            .clipShape(Capsule())
                                    } else {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(AppTheme.textPrimary)
                                            .frame(width: 44, height: 44)
                                            .background(AppTheme.cardSurface)
                                            .clipShape(Circle())
                                    }
                                }

                                Button(action: { dismiss() }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppTheme.textPrimary)
                                        .frame(width: 44, height: 44)
                                        .background(AppTheme.cardSurface)
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 16)

                            Spacer()
                        }

                        // Avatar
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

                    // Name & Role
                    VStack(spacing: 4) {
                        Text(roleLabel)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textSecondary)

                        Text(profileName)
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding(.top, 50)

                    // INFO CARDS
                    VStack(spacing: 20) {
                        ProfileInfoCard(title: "Personal", fields: $personalFields, isEditing: isEditing)
                        ProfileInfoCard(title: "Contact", fields: $contactFields, isEditing: isEditing)

                        // Sign Out Button
                        if !isEditing {
                            Button(action: {
                                showLogoutAlert = true
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
                    .padding(.bottom, 100)
                }
            }

        }
        .navigationBarHidden(true)
        .onAppear { loadUserData() }
        .alert("Success", isPresented: $showSaveToast) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Profile updated successfully")
        }
        .alert("Sign Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                try? AuthManager.shared.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
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

    // MARK: - Load Data
    private func loadUserData() {
        guard let user = session.currentUser else { return }

        profileName = user.fullName
        profileImage = String(user.fullName.prefix(1))
        roleLabel = user.role.displayName
        profileImageURL = user.profileImageURL

        personalFields = [
            ProfileInfoField(title: "Full Name", value: user.fullName),
            ProfileInfoField(title: "Gender", value: user.gender ?? "Not Set", options: ["Male", "Female", "Other"]),
            ProfileInfoField(title: "Date of Birth", value: user.dateOfBirth ?? "Not Set", isDateField: true)
        ]

        contactFields = [
            ProfileInfoField(title: "Phone Number", value: user.phoneNumber ?? "Not Set"),
            ProfileInfoField(title: "Email Address", value: user.email, isEditable: false)
        ]
    }

    // MARK: - Toggle Edit / Save
    private func toggleEditMode() {
        if isEditing {
            saveProfile()
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isEditing = true
            }
        }
    }

    private func saveProfile() {
        guard let user = session.currentUser else { return }
        let uid = user.id
        isSaving = true

        let fullName = personalFields.first(where: { $0.title == "Full Name" })?.value ?? ""
        let gender = personalFields.first(where: { $0.title == "Gender" })?.value
        let dob = personalFields.first(where: { $0.title == "Date of Birth" })?.value
        let phone = contactFields.first(where: { $0.title == "Phone Number" })?.value
        let safePhone = (phone == "Not Set" || phone?.isEmpty == true) ? nil : phone

        let db = Firestore.firestore()
        var updates: [String: Any] = [
            "fullName": fullName
        ]
        if let g = gender, g != "Not Set" { updates["gender"] = g }
        if let d = dob, d != "Not Set" { updates["dateOfBirth"] = d }
        if let p = safePhone { updates["phoneNumber"] = p }

        db.collection("users").document(uid).updateData(updates) { error in
            isSaving = false
            if error == nil {
                // Target role-specific collection mappings
                switch user.role {
                case .patient:
                    db.collection("patients").document(uid).setData(updates, merge: true)
                case .doctor:
                    db.collection("doctors").document(uid).setData(updates, merge: true)
                case .labTechnician:
                    db.collection("lab_technicians").document(uid).setData(updates, merge: true)
                default:
                    break
                }
                
                DispatchQueue.main.async {
                    var updatedUser = user
                    updatedUser.fullName = fullName
                    if let g = gender, g != "Not Set" { updatedUser.gender = g }
                    if let d = dob, d != "Not Set" { updatedUser.dateOfBirth = d }
                    if let p = safePhone { updatedUser.phoneNumber = p }
                    session.setUser(updatedUser)
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isEditing = false
                    }
                    profileName = fullName
                    profileImage = String(fullName.prefix(1))
                    triggerToast()
                }
            } else {
                print("Error updating profile: \(error?.localizedDescription ?? "Unknown Error")")
            }
        }
    }

    private func triggerToast() {
        showSaveToast = true
    }
}

#Preview {
    ProfileView()
}
