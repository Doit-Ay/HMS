import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import FirebaseCore

// MARK: - Auth Manager
@MainActor
class AuthManager {

    static let shared = AuthManager()
    private var db: Firestore { Firestore.firestore() }  // computed — safe before configure()
    private var authListener: AuthStateDidChangeListenerHandle?

    private init() {
        listenToAuthState()
    }

    deinit {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Auth State Listener
    private func listenToAuthState() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }
            if let firebaseUser = firebaseUser {
                Task {
                    await self.fetchUserProfile(uid: firebaseUser.uid)
                }
            } else {
                UserSession.shared.clearSession()
            }
        }
    }

    // MARK: - Fetch User Profile from Firestore
    func fetchUserProfile(uid: String) async {
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            if let data = doc.data(), let user = try? Firestore.Decoder().decode(HMSUser.self, from: data) {
                // Default: no OTP required (app reopen via auth listener)
                UserSession.shared.setUser(user, requiresOTP: false)
            } else {
                UserSession.shared.setLoading(false)
            }
        } catch {
            print("Error fetching user profile: \(error)")
            UserSession.shared.setLoading(false)
        }
    }

    // MARK: - Unified Email/Password Login
    /// Signs in any user (patient or staff) — role is determined from Firestore.
    /// AppRouter handles routing to the correct dashboard automatically.
    func login(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        await fetchUserProfile(uid: result.user.uid)
        await ActivityLogManager.shared.logAction(action: "User Login", details: "Logged in via Email: \(email)")
        // Trigger OTP for fresh login
        UserSession.shared.needsOTPVerification = true
        UserSession.shared.pendingOTPEmail = email
        await sendOTPForUser(email: email)
    }

    // MARK: - Unified Google Sign-In
    /// Google sign-in for any user. New Google users are auto-registered as patients.
    /// Existing users are signed in regardless of role — AppRouter routes them.
    func googleSignInUnified(presenting viewController: UIViewController) async throws {
        let googleUser = try await googleSignIn(presenting: viewController)
        if UserSession.shared.userRole == nil {
            // New Google user — create as patient
            let newUser = HMSUser(
                id: googleUser.uid,
                email: googleUser.email ?? "",
                fullName: googleUser.displayName ?? "Patient",
                role: .patient
            )
            try await saveUserToFirestore(user: newUser, db: nil)
            let patientProfile = PatientProfile(from: newUser)
            try await savePatientProfile(profile: patientProfile, db: nil)
            UserSession.shared.setUser(newUser, requiresOTP: true)
        }
        // Trigger OTP for fresh Google sign-in
        let email = googleUser.email ?? UserSession.shared.currentUser?.email ?? ""
        UserSession.shared.needsOTPVerification = true
        UserSession.shared.pendingOTPEmail = email
        await sendOTPForUser(email: email)
    }

    // MARK: - Patient Email/Password Login
    func patientLogin(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        await fetchUserProfile(uid: result.user.uid)
        // Ensure the logged-in user is a patient
        if UserSession.shared.userRole != .patient {
            try Auth.auth().signOut()
            UserSession.shared.clearSession()
            throw AuthError.wrongRole("This account is not a patient account. Please use Staff login.")
        }
        await ActivityLogManager.shared.logAction(action: "Patient Login", details: "Patient logged in: \(email)")
        // Trigger OTP for fresh login
        UserSession.shared.needsOTPVerification = true
        UserSession.shared.pendingOTPEmail = email
        await sendOTPForUser(email: email)
    }

    // MARK: - Staff Email/Password Login
    func staffLogin(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        await fetchUserProfile(uid: result.user.uid)
        // Ensure the logged-in user is staff
        if UserSession.shared.userRole == .patient {
            try Auth.auth().signOut()
            UserSession.shared.clearSession()
            throw AuthError.wrongRole("This account is not a staff account. Please use Patient login.")
        }
        await ActivityLogManager.shared.logAction(action: "Staff Login", details: "Staff logged in: \(email)")
        // Trigger OTP for fresh login
        UserSession.shared.needsOTPVerification = true
        UserSession.shared.pendingOTPEmail = email
        await sendOTPForUser(email: email)
    }

    // MARK: - Patient Registration
    // Writes to TWO collections:
    //   users/{uid}    → role assignment (master user table)
    //   patients/{uid} → patient-specific clinical profile
    func registerPatient(email: String, password: String, fullName: String, phone: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        var user = HMSUser(
            id: result.user.uid,
            email: email,
            fullName: fullName,
            role: .patient
        )
        user.phoneNumber = phone

        // 1. Save to `users` collection (role assignment)
        try await saveUserToFirestore(user: user, db: nil)

        // 2. Save to `patients` collection (patient profile)
        var patientProfile = PatientProfile(from: user)
        patientProfile.phoneNumber = phone
        try await savePatientProfile(profile: patientProfile, db: nil)

        UserSession.shared.setUser(user, requiresOTP: true)
        await ActivityLogManager.shared.logAction(action: "Patient Registration", details: "Registered new patient: \(email)")
        // Send OTP for email verification
        await sendOTPForUser(email: email)
    }

    // MARK: - Google Sign-In (Patient)
    // For new Google users: writes to both `users` and `patients` collections.
    func googleSignInPatient(presenting viewController: UIViewController) async throws {
        let googleUser = try await googleSignIn(presenting: viewController)
        if UserSession.shared.userRole == nil {
            // New Google user — create as patient in both collections
            let newUser = HMSUser(
                id: googleUser.uid,
                email: googleUser.email ?? "",
                fullName: googleUser.displayName ?? "Patient",
                role: .patient
            )
            // 1. Save to `users` collection
            try await saveUserToFirestore(user: newUser, db: nil)
            // 2. Save to `patients` collection
            let patientProfile = PatientProfile(from: newUser)
            try await savePatientProfile(profile: patientProfile, db: nil)
            UserSession.shared.setUser(newUser, requiresOTP: true)
        } else if UserSession.shared.userRole != .patient {
            try Auth.auth().signOut()
            UserSession.shared.clearSession()
            throw AuthError.wrongRole("This Google account is registered as staff. Please use Staff login.")
        }
        // Trigger OTP for fresh Google sign-in
        let email = googleUser.email ?? UserSession.shared.currentUser?.email ?? ""
        await ActivityLogManager.shared.logAction(action: "Google Sign-In", details: "Patient logged in via Google: \(email)")
        UserSession.shared.needsOTPVerification = true
        UserSession.shared.pendingOTPEmail = email
        await sendOTPForUser(email: email)
    }

    // MARK: - Google Sign-In (Staff)
    func googleSignInStaff(presenting viewController: UIViewController) async throws {
        let user = try await googleSignIn(presenting: viewController)
        if UserSession.shared.userRole == nil {
            try Auth.auth().signOut()
            UserSession.shared.clearSession()
            throw AuthError.notFound("No staff account found for this Google account. Please contact your administrator.")
        } else if UserSession.shared.userRole == .patient {
            try Auth.auth().signOut()
            UserSession.shared.clearSession()
            throw AuthError.wrongRole("This Google account is registered as a patient. Please use Patient login.")
        }
        // Trigger OTP for fresh Google sign-in
        let email = user.email ?? UserSession.shared.currentUser?.email ?? ""
        await ActivityLogManager.shared.logAction(action: "Google Sign-In", details: "Staff logged in via Google: \(email)")
        UserSession.shared.needsOTPVerification = true
        UserSession.shared.pendingOTPEmail = email
        await sendOTPForUser(email: email)
    }

    // MARK: - Private Google Sign-In Helper
    private func googleSignIn(presenting viewController: UIViewController) async throws -> (uid: String, email: String?, displayName: String?) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.configuration("Firebase client ID not found.")
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.unknown("Google ID token not found.")
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        await fetchUserProfile(uid: authResult.user.uid)
        return (authResult.user.uid, authResult.user.email, authResult.user.displayName)
    }

    // MARK: - Forgot Password
    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - Sign Out
    func signOut() throws {
        let currentUser = UserSession.shared.currentUser
        if let user = currentUser {
            Task {
                await ActivityLogManager.shared.logAction(action: "User Logout", details: "User signed out.", userOverride: user)
            }
        }
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        UserSession.shared.clearSession()
    }

    // MARK: - Admin: Add Staff Member
    // Uses a SECONDARY Firebase App instance so the admin is never signed out.
    // A random temp password is generated internally — the staff member receives
    // a Firebase "set password" email and must set their own password before logging in.
    func addStaffMember(
        email: String,
        fullName: String,
        role: UserRole,
        department: String?,
        specialization: String?,
        employeeID: String?,
        defaultSlots: [String]? = nil
    ) async throws {
        // Step 1 — Get a secondary Firebase App to isolate auth from admin session
        let secondaryAppName = "HMSStaffCreation"
        let options = FirebaseApp.app()!.options

        if FirebaseApp.app(name: secondaryAppName) == nil {
            FirebaseApp.configure(name: secondaryAppName, options: options)
        }
        guard let secondaryApp = FirebaseApp.app(name: secondaryAppName) else {
            throw AuthError.unknown("Could not create secondary Firebase instance.")
        }

        // Step 2 — Create the staff Firebase Auth account using secondary Auth
        let secondaryAuth = Auth.auth(app: secondaryApp)
        let tempPassword = generateTempPassword()
        let result = try await secondaryAuth.createUser(withEmail: email, password: tempPassword)

        // Step 3 — Save to `users` Firestore collection
        let adminDB = Firestore.firestore()
        
        var staff = HMSUser(id: result.user.uid, email: email, fullName: fullName, role: role)
        staff.department     = department
        staff.specialization = specialization
        staff.employeeID     = employeeID
        staff.defaultSlots   = defaultSlots
        
        try await saveUserToFirestore(user: staff, db: adminDB)

        // Step 4 — Save to role-specific collection
        switch role {
        case .doctor:
            let doctorProfile = DoctorProfile(from: staff)
            try await saveDoctorProfile(profile: doctorProfile, db: adminDB)
        case .labTechnician:
            let labTechProfile = LabTechnicianProfile(from: staff)
            try await saveLabTechnicianProfile(profile: labTechProfile, db: adminDB)
        default:
            break
        }

        // Step 5 — Auto-generate doctor_slots for the next 7 days (doctors only)
        if role == .doctor && defaultSlots != nil {
            try await generateDefaultSlotsForWeek(for: staff)
        }

        // Step 6 — Clean up: sign out of secondary auth
        try? secondaryAuth.signOut()

        // Step 7 — Send password reset email
        try await Auth.auth().sendPasswordReset(withEmail: email)
        
        await ActivityLogManager.shared.logAction(action: "Add Staff", details: "Added \(role.displayName) \(fullName) (\(email))")
    }

    // Generates a secure random temporary password
    private func generateTempPassword() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let random  = (0..<16).map { _ in letters.randomElement()! }
        return String(random) + "Hx1!"   // suffix ensures complexity requirements
    }


    // MARK: - Admin: Deactivate Staff Member
    func deactivateStaff(uid: String) async throws {
        try await db.collection("users").document(uid).updateData(["isActive": false])
        await ActivityLogManager.shared.logAction(action: "Deactivate Staff", details: "Deactivated staff member UID: \(uid)")
    }

    // MARK: - Admin: Reactivate Staff Member
    func reactivateStaff(uid: String) async throws {
        try await db.collection("users").document(uid).updateData(["isActive": true])
        await ActivityLogManager.shared.logAction(action: "Reactivate Staff", details: "Reactivated staff member UID: \(uid)")
    }

    // MARK: - Admin: Update Staff Member
    func updateStaffMember(
        uid: String,
        fullName: String,
        role: UserRole,
        department: String?,
        specialization: String?,
        employeeID: String?,
        defaultSlots: [String]? = nil
    ) async throws {
        // Step 1 — Update `users` Firestore collection
        var updates: [String: Any] = [
            "fullName": fullName
        ]
        updates["department"]     = department
        updates["specialization"] = specialization
        updates["employeeID"]     = employeeID
        if let slots = defaultSlots {
            updates["defaultSlots"] = slots
        }

        try await db.collection("users").document(uid).updateData(updates)

        // Step 2 — Update role-specific collection (merge: true creates if missing)
        switch role {
        case .doctor:
            var doctorUpdates: [String: Any] = [
                "id": uid,
                "email": "",    // will be merged, not overwritten if exists
                "fullName": fullName,
                "isActive": true
            ]
            doctorUpdates["department"]     = department
            doctorUpdates["specialization"] = specialization
            doctorUpdates["employeeID"]     = employeeID
            if let slots = defaultSlots {
                doctorUpdates["defaultSlots"] = slots
            }
            try await db.collection("doctors").document(uid).setData(doctorUpdates, merge: true)
            
        case .labTechnician:
            var labTechUpdates: [String: Any] = [
                "id": uid,
                "fullName": fullName,
                "isActive": true
            ]
            labTechUpdates["department"] = department
            labTechUpdates["employeeID"] = employeeID
            try await db.collection("lab_technicians").document(uid).setData(labTechUpdates, merge: true)
        default:
            break
        }
        
        await ActivityLogManager.shared.logAction(action: "Update Staff", details: "Updated profile for staff member UID: \(uid)")
    }

    // MARK: - Self-Serve: Update Current Doctor Profile
    func updateCurrentDoctorProfile(
        uid: String,
        fullName: String,
        specialization: String?,
        phoneNumber: String?,
        dateOfBirth: String?,
        gender: String?
    ) async throws {
        // 1. PRIMARY: Update `doctors` collection with ALL fields explicitly
        let doctorUpdates: [String: Any] = [
            "fullName":       fullName,
            "specialization": specialization ?? "Not Set",
            "phoneNumber":    phoneNumber    ?? "Not Set",
            "dateOfBirth":    dateOfBirth    ?? "Not Set",
            "gender":         gender         ?? "Not Set"
        ]
        try await db.collection("doctors").document(uid).updateData(doctorUpdates)
        
        // 2. Update the local singleton state so UI reflects immediately
        await MainActor.run {
            if let user = UserSession.shared.currentUser {
                var updatedUser = user
                updatedUser.fullName = fullName
                updatedUser.specialization = specialization ?? updatedUser.specialization
                updatedUser.phoneNumber = phoneNumber ?? updatedUser.phoneNumber
                updatedUser.dateOfBirth = dateOfBirth ?? updatedUser.dateOfBirth
                updatedUser.gender = gender ?? updatedUser.gender
                UserSession.shared.setUser(updatedUser)
            }
        }
    }

    // MARK: - Sync current doctor profile fields to doctors collection
    func syncDoctorProfileToFirestore(user: HMSUser) async {
        let fields: [String: Any] = [
            "id":             user.id,
            "email":          user.email,
            "fullName":       user.fullName,
            "isActive":       user.isActive,
            "phoneNumber":    user.phoneNumber    ?? "Not Set",
            "dateOfBirth":    user.dateOfBirth    ?? "Not Set",
            "gender":         user.gender         ?? "Not Set",
            "department":     user.department     ?? "Not Set",
            "specialization": user.specialization ?? "Not Set",
            "employeeID":     user.employeeID     ?? "Not Set"
        ]
        do {
            try await db.collection("doctors").document(user.id).setData(fields, merge: true)
        } catch {
            print("syncDoctorProfileToFirestore error: \(error)")
        }
    }

    // MARK: - Backfill ALL doctors in doctors collection with missing fields
    // Reads only from the `doctors` collection. Sets missing fields to "Not Set".
    func backfillAllDoctorsInFirestore() async {
        do {
            let snapshot = try await db.collection("doctors").getDocuments()
            for doc in snapshot.documents {
                var data = doc.data()
                var updates: [String: Any] = [:]

                let requiredFields: [String] = [
                    "phoneNumber", "dateOfBirth", "gender",
                    "department", "specialization", "employeeID"
                ]
                for field in requiredFields {
                    if data[field] == nil {
                        updates[field] = "Not Set"
                    }
                }

                if !updates.isEmpty {
                    try await db.collection("doctors").document(doc.documentID).updateData(updates)
                    print("Backfilled doctor \(doc.documentID): \(updates.keys.joined(separator: ", "))")
                }
            }
            print("backfillAllDoctorsInFirestore: complete for \(snapshot.documents.count) doctors")
        } catch {
            print("backfillAllDoctorsInFirestore error: \(error)")
        }
    }

    // MARK: - Admin: Fetch Staff Members
    func fetchStaffMembers() async throws -> [HMSUser] {
        let snapshot = try await db.collection("users")
            .whereField("role", isNotEqualTo: "patient")
            .getDocuments()
        return snapshot.documents.compactMap {
            try? Firestore.Decoder().decode(HMSUser.self, from: $0.data())
        }
    }

    // MARK: - Fetch Patient Profile
    func fetchPatientProfile(uid: String) async throws -> PatientProfile? {
        let doc = try await db.collection("patients").document(uid).getDocument()
        guard let data = doc.data() else { return nil }
        return try Firestore.Decoder().decode(PatientProfile.self, from: data)
    }

    // MARK: - Fetch Doctor Profile
    func fetchDoctorProfile(uid: String) async throws -> DoctorProfile? {
        let doc = try await db.collection("doctors").document(uid).getDocument()
        guard let data = doc.data() else { return nil }
        return try Firestore.Decoder().decode(DoctorProfile.self, from: data)
    }

    // MARK: - Fetch Lab Technician Profile
    func fetchLabTechnicianProfile(uid: String) async throws -> LabTechnicianProfile? {
        let doc = try await db.collection("lab_technicians").document(uid).getDocument()
        guard let data = doc.data() else { return nil }
        return try Firestore.Decoder().decode(LabTechnicianProfile.self, from: data)
    }

    // MARK: - Save to `users` collection
    private func saveUserToFirestore(user: HMSUser, db dbInstance: Firestore?) async throws {
        let database = dbInstance ?? db
        let data = try Firestore.Encoder().encode(user)
        try await database.collection("users").document(user.id).setData(data)
    }

    // MARK: - Save to `patients` collection
    private func savePatientProfile(profile: PatientProfile, db dbInstance: Firestore?) async throws {
        let database = dbInstance ?? db
        let data = try Firestore.Encoder().encode(profile)
        try await database.collection("patients").document(profile.id).setData(data)
    }

    // MARK: - Save to `doctors` collection
    private func saveDoctorProfile(profile: DoctorProfile, db dbInstance: Firestore?) async throws {
        let database = dbInstance ?? db
        let data = try Firestore.Encoder().encode(profile)
        try await database.collection("doctors").document(profile.id).setData(data)
    }

    // MARK: - Save to `lab_technicians` collection
    private func saveLabTechnicianProfile(profile: LabTechnicianProfile, db dbInstance: Firestore?) async throws {
        let database = dbInstance ?? db
        let data = try Firestore.Encoder().encode(profile)
        try await database.collection("lab_technicians").document(profile.id).setData(data)
    }

    // MARK: - Fetch All Patients
    func fetchPatients() async throws -> [HMSUser] {
        let snapshot = try await db.collection("users")
            .whereField("role", isEqualTo: UserRole.patient.rawValue)
            .getDocuments()
        return snapshot.documents.compactMap { try? Firestore.Decoder().decode(HMSUser.self, from: $0.data()) }
    }

    // MARK: - Fetch All Doctors
    func fetchDoctors() async throws -> [HMSUser] {
        let snapshot = try await db.collection("doctors")
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        return snapshot.documents.compactMap { doc -> HMSUser? in
            let d = doc.data()
            guard let email = d["email"] as? String,
                  let fullName = d["fullName"] as? String else { return nil }
            var user = HMSUser(id: doc.documentID, email: email, fullName: fullName, role: .doctor)
            user.phoneNumber = d["phoneNumber"] as? String
            user.dateOfBirth = d["dateOfBirth"] as? String
            user.gender = d["gender"] as? String
            user.profileImageURL = d["profileImageURL"] as? String
            user.department = d["department"] as? String
            user.specialization = d["specialization"] as? String
            user.employeeID = d["employeeID"] as? String
            user.defaultSlots = d["defaultSlots"] as? [String]
            user.isActive = d["isActive"] as? Bool ?? true
            return user
        }
    }

    // MARK: - Doctor Slot Management

    /// Add a single slot for a doctor
    func addDoctorSlot(_ slot: DoctorSlot) async throws {
        let data = try Firestore.Encoder().encode(slot)
        try await db.collection("doctor_slots").document(slot.id).setData(data)
    }

    /// Fetch all slots for a specific doctor on a given date
    func fetchSlots(doctorId: String, date: String) async throws -> [DoctorSlot] {
        let snapshot = try await db.collection("doctor_slots")
            .whereField("doctorId", isEqualTo: doctorId)
            .whereField("date", isEqualTo: date)
            .getDocuments()
        return snapshot.documents.compactMap {
            try? Firestore.Decoder().decode(DoctorSlot.self, from: $0.data())
        }.sorted { $0.startTime < $1.startTime }
    }

    /// Toggle a slot's status between available and unavailable
    func toggleSlotStatus(slotId: String, newStatus: SlotStatus) async throws {
        try await db.collection("doctor_slots").document(slotId).updateData([
            "status": newStatus.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Delete a specific slot
    func deleteSlot(slotId: String) async throws {
        try await db.collection("doctor_slots").document(slotId).delete()
    }

    /// Fetch ALL slots for a given date (across all doctors)
    func fetchAllSlots(forDate date: String) async throws -> [DoctorSlot] {
        let snapshot = try await db.collection("doctor_slots")
            .whereField("date", isEqualTo: date)
            .getDocuments()
        return snapshot.documents.compactMap {
            try? Firestore.Decoder().decode(DoctorSlot.self, from: $0.data())
        }
    }

    /// Fetch ALL slots for a given month (format: "yyyy-MM")
    func fetchAllSlots(forMonth month: String) async throws -> [DoctorSlot] {
        let startDate = month + "-01"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: startDate) else { return [] }
        let calendar = Calendar.current
        guard let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) else { return [] }
        let endDate = formatter.string(from: endOfMonth)

        let snapshot = try await db.collection("doctor_slots")
            .whereField("date", isGreaterThanOrEqualTo: startDate)
            .whereField("date", isLessThanOrEqualTo: endDate)
            .getDocuments()
        return snapshot.documents.compactMap {
            try? Firestore.Decoder().decode(DoctorSlot.self, from: $0.data())
        }
    }

    // MARK: - Appointment Statistics

    /// Fetch all appointments (optionally filtered by date range)
    func fetchAppointments(from startDate: String? = nil, to endDate: String? = nil) async throws -> [Appointment] {
        var query: Query = db.collection("appointments")
        if let start = startDate {
            query = query.whereField("date", isGreaterThanOrEqualTo: start)
        }
        if let end = endDate {
            query = query.whereField("date", isLessThanOrEqualTo: end)
        }
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap {
            try? Firestore.Decoder().decode(Appointment.self, from: $0.data())
        }
    }

    /// Fetch appointments for a specific date
    func fetchAppointments(forDate date: String) async throws -> [Appointment] {
        let snapshot = try await db.collection("appointments")
            .whereField("date", isEqualTo: date)
            .getDocuments()
        return snapshot.documents.compactMap {
            try? Firestore.Decoder().decode(Appointment.self, from: $0.data())
        }
    }

    /// Fetch all appointments in a given month (format: "yyyy-MM")
    func fetchAppointments(forMonth month: String) async throws -> [Appointment] {
        let startDate = month + "-01"
        // Calculate end of month
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: startDate) else { return [] }
        let calendar = Calendar.current
        guard let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) else { return [] }
        let endDate = formatter.string(from: endOfMonth)

        return try await fetchAppointments(from: startDate, to: endDate)
    }

    // MARK: - Doctor Unavailability Management

    /// Save or update a doctor unavailability entry
    func saveUnavailability(_ entry: DoctorUnavailability) async throws {
        let data = try Firestore.Encoder().encode(entry)
        try await db.collection("doctor_unavailability").document(entry.id).setData(data, merge: true)
    }

    /// Fetch all unavailability entries for a doctor in a given month (format: "yyyy-MM")
    func fetchUnavailability(doctorId: String, month: String) async throws -> [DoctorUnavailability] {
        let startDate = month + "-01"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: startDate) else { return [] }
        let calendar = Calendar.current
        guard let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) else { return [] }
        let endDate = formatter.string(from: endOfMonth)

        // Query by doctorId only (single field — no composite index needed)
        // then filter by date range client-side
        let snapshot = try await db.collection("doctor_unavailability")
            .whereField("doctorId", isEqualTo: doctorId)
            .getDocuments()
        return snapshot.documents.compactMap {
            try? Firestore.Decoder().decode(DoctorUnavailability.self, from: $0.data())
        }.filter { $0.date >= startDate && $0.date <= endDate }
    }

    /// Delete an unavailability entry (when doctor marks day as available again)
    func deleteUnavailability(id: String) async throws {
        try await db.collection("doctor_unavailability").document(id).delete()
    }

    /// Delete unavailability for a specific doctor on a specific date
    func deleteUnavailability(doctorId: String, date: String) async throws {
        let snapshot = try await db.collection("doctor_unavailability")
            .whereField("doctorId", isEqualTo: doctorId)
            .whereField("date", isEqualTo: date)
            .getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }

    // MARK: - Default Slot Generation

    /// Generate DoctorSlot documents from a doctor's defaultSlots array for a specific date
    func generateDefaultSlots(for doctor: HMSUser, on date: String) async throws {
        guard let defaults = doctor.defaultSlots, !defaults.isEmpty else { return }

        for slotLabel in defaults {
            let (start, end) = slotTimeRange(for: slotLabel)
            let slot = DoctorSlot(
                id: UUID().uuidString,
                doctorId: doctor.id,
                doctorName: doctor.fullName,
                department: doctor.department,
                date: date,
                startTime: start,
                endTime: end,
                status: .available,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await addDoctorSlot(slot)
        }
    }

    /// Generate default slots for multiple days (e.g. next 7 days after doctor creation)
    func generateDefaultSlotsForWeek(for doctor: HMSUser) async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current

        for dayOffset in 0..<7 {
            guard let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }
            let dateString = formatter.string(from: futureDate)
            try await generateDefaultSlots(for: doctor, on: dateString)
        }
    }

    /// Map a slot label to start/end time strings
    private func slotTimeRange(for label: String) -> (start: String, end: String) {
        switch label.lowercased() {
        case "morning":   return ("09:00", "13:00")
        case "afternoon": return ("13:00", "17:00")
        case "evening":   return ("17:00", "22:00")
        default:
            // Custom format: "HH:mm-HH:mm"
            let parts = label.split(separator: "-").map(String.init)
            if parts.count == 2 {
                return (parts[0].trimmingCharacters(in: .whitespaces),
                        parts[1].trimmingCharacters(in: .whitespaces))
            }
            return ("09:00", "10:00") // fallback
        }
    }

    // MARK: - Patient Appointment Booking

    /// Generate 30-min slot chunks from a doctor's defaultSlots, filtering out unavailable time ranges
    func generate30MinSlots(
        from defaultSlots: [String],
        unavailability: DoctorUnavailability?,
        bookedSlots: [DoctorSlot]
    ) -> [(start: String, end: String, isBooked: Bool)] {
        var allChunks: [(start: String, end: String, isBooked: Bool)] = []

        for label in defaultSlots {
            let (rangeStart, rangeEnd) = slotTimeRange(for: label)
            // Split into 30-min chunks
            var current = rangeStart
            while current < rangeEnd {
                let next = add30Min(to: current)
                if next <= rangeEnd {
                    var isBooked = false
                    // Check if this chunk is already booked
                    for booked in bookedSlots {
                        if booked.startTime == current && booked.endTime == next && booked.status == .booked {
                            isBooked = true
                            break
                        }
                    }
                    allChunks.append((start: current, end: next, isBooked: isBooked))
                }
                current = next
            }
        }

        // Filter out unavailable time ranges
        if let unav = unavailability {
            if unav.type == "unavailable" {
                return [] // whole day off
            }
            if unav.type == "halfDay", let uStart = unav.startTime, let uEnd = unav.endTime {
                allChunks = allChunks.filter { chunk in
                    // Remove chunks that overlap with unavailability
                    !(chunk.start >= uStart && chunk.start < uEnd)
                }
            }
        }

        return allChunks
    }

    /// Add 30 minutes to a "HH:mm" time string
    private func add30Min(to time: String) -> String {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return time }
        var hour = parts[0]
        var minute = parts[1] + 30
        if minute >= 60 {
            minute -= 60
            hour += 1
        }
        return String(format: "%02d:%02d", hour, minute)
    }

    /// Book an appointment — creates Appointment doc and marks/creates slot as booked
    func bookAppointment(_ appointment: Appointment) async throws {
        // 1. Save the appointment
        let data = try Firestore.Encoder().encode(appointment)
        try await db.collection("appointments").document(appointment.id).setData(data)

        // 2. Create or update the slot as booked
        let slot = DoctorSlot(
            id: appointment.slotId,
            doctorId: appointment.doctorId,
            doctorName: appointment.doctorName,
            department: appointment.department,
            date: appointment.date,
            startTime: appointment.startTime,
            endTime: appointment.endTime,
            status: .booked,
            createdAt: Date(),
            updatedAt: Date()
        )
        let slotData = try Firestore.Encoder().encode(slot)
        try await db.collection("doctor_slots").document(slot.id).setData(slotData, merge: true)
    }

    /// Update the status of an appointment (e.g. "scheduled" → "completed")
    func updateAppointmentStatus(appointmentId: String, status: String) async throws {
        try await db.collection("appointments").document(appointmentId).updateData([
            "status": status
        ])
    }

    /// Fetch a single appointment by ID
    func fetchAppointment(appointmentId: String) async throws -> Appointment? {
        let doc = try await db.collection("appointments").document(appointmentId).getDocument()
        guard let data = doc.data() else { return nil }
        return try Firestore.Decoder().decode(Appointment.self, from: data)
    }

    /// Fetch appointments for a specific doctor on a given date
    func fetchDoctorAppointments(doctorId: String, date: String) async throws -> [Appointment] {
        let snapshot = try await db.collection("appointments")
            .whereField("doctorId", isEqualTo: doctorId)
            .whereField("date", isEqualTo: date)
            .getDocuments()
        return snapshot.documents.compactMap {
            try? Firestore.Decoder().decode(Appointment.self, from: $0.data())
        }.sorted { $0.startTime < $1.startTime }
    }
    
    /// Fetch all appointments for a specific doctor
    func fetchAllDoctorAppointments(doctorId: String) async throws -> [Appointment] {
        let snapshot = try await db.collection("appointments")
            .whereField("doctorId", isEqualTo: doctorId)
            .getDocuments()
        return snapshot.documents.compactMap {
            try? Firestore.Decoder().decode(Appointment.self, from: $0.data())
        }
    }

    /// Fetch appointments for a specific doctor in a given month (format: "yyyy-MM")
    func fetchDoctorAppointments(doctorId: String, month: String) async throws -> [Appointment] {
        let startDate = month + "-01"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: startDate) else { return [] }
        let calendar = Calendar.current
        guard let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) else { return [] }
        let endDate = formatter.string(from: endOfMonth)

        let snapshot = try await db.collection("appointments")
            .whereField("doctorId", isEqualTo: doctorId)
            .getDocuments()
        return snapshot.documents.compactMap {
            try? Firestore.Decoder().decode(Appointment.self, from: $0.data())
        }.filter { $0.date >= startDate && $0.date <= endDate }
    }

    /// Fetch appointments for the logged-in patient
    func fetchPatientAppointments(patientId: String) async throws -> [Appointment] {
        let snapshot = try await db.collection("appointments")
            .whereField("patientId", isEqualTo: patientId)
            .getDocuments()
        return snapshot.documents.compactMap {
            try? Firestore.Decoder().decode(Appointment.self, from: $0.data())
        }.sorted { $0.date < $1.date }
    }

    /// Fetch a single doctor's HMSUser record
    func fetchDoctor(id: String) async throws -> HMSUser? {
        let doc = try await db.collection("users").document(id).getDocument()
        guard doc.exists else { return nil }
        return try? Firestore.Decoder().decode(HMSUser.self, from: doc.data() ?? [:])
    }

    // MARK: - OTP Helper
    /// Sends an OTP email for the given user. Failures are logged but do not block auth.
    private func sendOTPForUser(email: String) async {
        do {
            try await EmailOTPManager.shared.sendOTP(to: email)
        } catch {
            print("⚠️ Failed to send OTP: \(error.localizedDescription)")
        }
    }
} // <-- Close AuthManager class here

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case wrongRole(String)
    case notFound(String)
    case configuration(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .wrongRole(let msg):    return msg
        case .notFound(let msg):     return msg
        case .configuration(let msg):return msg
        case .unknown(let msg):      return msg
        }
    }
}
