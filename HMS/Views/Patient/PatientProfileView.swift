import SwiftUI
import FirebaseFirestore

struct PatientProfileView: View {

    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showSaveToast = false
    @State private var appearAnimation = false

    @Environment(\.dismiss) private var dismiss

    // Profile Image placeholder
    @State private var profileImage = "P"

    // Profile fields
    @State private var personalFields: [ProfileInfoField] = []
    @State private var medicalFields: [ProfileInfoField] = []
    @State private var contactFields: [ProfileInfoField] = []

    @State private var profileName: String = "Loading..."
    @State private var roleLabel: String = "Patient"

    // Stats
    @State private var ageStat: String = "-"
    @State private var heightStat: String = "-"
    @State private var weightStat: String = "-"

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
                        .frame(height: 220)
                        .ignoresSafeArea(edges: .top)

                        // Navigation Buttons
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
                                            .background(Color.white)
                                            .clipShape(Circle())
                                    }
                                }

                                Button(action: { dismiss() }) {

                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppTheme.textPrimary)
                                        .frame(width: 44, height: 44)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                }

                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 16)

                            Spacer()
                        }

                        // Avatar
                        VStack(spacing: 8) {

                            ZStack(alignment: .bottomTrailing) {

                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 110, height: 110)
                                    .shadow(radius: 10)

                                    .overlay(
                                        Text(profileImage)
                                            .font(.system(size: 40, weight: .bold))
                                            .foregroundColor(AppTheme.primaryDark)
                                    )

                                if isEditing {

                                    Circle()
                                        .fill(AppTheme.primary)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .foregroundColor(.white)
                                        )
                                }

                            }
                            .offset(y: 55)
                        }
                    }

                    VStack(spacing: 4) {

                        Text(roleLabel)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textSecondary)

                        Text(profileName)
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundColor(AppTheme.textPrimary)

                    }
                    .padding(.top, 65)

                    // STATS BAR
                    HStack {

                        PatientStatItem(label: "Age", value: $ageStat, isEditing: isEditing)

                        PatientStatItem(label: "Height", value: $heightStat, isEditing: isEditing)

                        PatientStatItem(label: "Weight", value: $weightStat, isEditing: isEditing)

                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    // INFO CARDS
                    VStack(spacing: 20) {

                        ProfileInfoCard(title: "Personal", fields: $personalFields, isEditing: isEditing)

                        ProfileInfoCard(title: "Medical", fields: $medicalFields, isEditing: isEditing)

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
                                .background(Color.white)
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

            if showSaveToast {

                HStack {

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)

                    Text("Profile updated successfully")
                        .foregroundColor(.white)

                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.green)
                .clipShape(Capsule())
                .padding(.bottom, 40)

            }
        }
        .navigationBarHidden(true)
        .onAppear {

            loadUserData()

            withAnimation(.easeOut(duration: 0.6)) {

                appearAnimation = true
            }
        }
    }

    // LOAD PATIENT DATA

    private func loadUserData() {

        guard let user = UserSession.shared.currentUser else { return }

        profileName = user.fullName
        profileImage = String(user.fullName.prefix(1))

        let db = Firestore.firestore()

        Task {

            let doc = try? await db.collection("patients")
                .document(user.id)
                .getDocument()

            guard let data = doc?.data() else { return }

            let age = data["age"] as? Int ?? 0
            let height = data["height"] as? Int ?? 0
            let weight = data["weight"] as? Int ?? 0

            ageStat = "\(age)"
            heightStat = "\(height)"
            weightStat = "\(weight)"

            personalFields = [
                ProfileInfoField(title: "Full Name", value: user.fullName),
//                ProfileInfoField(title: "Age", value: "\(age)", keyboardType: .numberPad),
                ProfileInfoField(title: "Gender", value: data["gender"] as? String ?? "Not Set", options: ["Male","Female","Other"])
            ]

            medicalFields = [
                ProfileInfoField(title: "Blood Group", value: data["bloodGroup"] as? String ?? "Not Set", options: ["A+","A-","B+","B-","O+","O-","AB+","AB-"]),
                ProfileInfoField(title: "Allergies", value: data["allergies"] as? String ?? "None")
            ]

            contactFields = [
                ProfileInfoField(title: "Phone Number", value: user.phoneNumber ?? "Not Set"),
                ProfileInfoField(title: "Email Address", value: user.email, isEditable: false),
                ProfileInfoField(title: "Emergency Contact Name", value: data["emergencyContactName"] as? String ?? "Not Set"),
                ProfileInfoField(title: "Emergency Contact Phone", value: data["emergencyContactPhone"] as? String ?? "Not Set")
            ]
        }
    }

    // SAVE PROFILE

    private func toggleEditMode() {

        if isEditing {

            saveProfile()

        } else {

            withAnimation {
                isEditing = true
            }
        }
    }

    private func saveProfile() {

        guard let uid = UserSession.shared.currentUser?.id else { return }

        isSaving = true

        let db = Firestore.firestore()

        let data: [String:Any] = [

//            "age": Int(personalFields.first(where:{$0.title == "Age"})?.value ?? "0") ?? 0,
            "gender": personalFields.first(where:{$0.title == "Gender"})?.value ?? "",
            "bloodGroup": medicalFields.first(where:{$0.title == "Blood Group"})?.value ?? "",
            "allergies": medicalFields.first(where:{$0.title == "Allergies"})?.value ?? "",
            "emergencyContactName": contactFields.first(where:{$0.title == "Emergency Contact Name"})?.value ?? "",
            "emergencyContactPhone": contactFields.first(where:{$0.title == "Emergency Contact Phone"})?.value ?? "",
            "age": Int(ageStat) ?? 0,
            "height": Int(heightStat) ?? 0,
            "weight": Int(weightStat) ?? 0
        ]

        db.collection("patients")
            .document(uid)
            .setData(data, merge: true) { _ in

                isSaving = false
                isEditing = false
                triggerToast()
            }
    }

    private func triggerToast() {

        withAnimation {
            showSaveToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {

            withAnimation {
                showSaveToast = false
            }
        }
    }
}

struct PatientStatItem: View {

    let label: String
    @Binding var value: String
    let isEditing: Bool

    var body: some View {

        VStack(spacing: 4) {

            if isEditing {

                TextField("", text: $value)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 60)
                    .padding(6)
                    .background(AppTheme.primaryMid.opacity(0.3))
                    .cornerRadius(6)

            } else {

                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.primary)

            }

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)

        }
        .frame(maxWidth: .infinity)
    }
}
