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
                UserSession.shared.setUser(user)
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
            UserSession.shared.setUser(newUser)
        }
        // Existing users (patient or staff) — already fetched in googleSignIn helper
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

        UserSession.shared.setUser(user)
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
            UserSession.shared.setUser(newUser)
        } else if UserSession.shared.userRole != .patient {
            try Auth.auth().signOut()
            UserSession.shared.clearSession()
            throw AuthError.wrongRole("This Google account is registered as staff. Please use Staff login.")
        }
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
        employeeID: String?
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

        // Step 3 — Save to `users` Firestore collection using SECONDARY app context
        // This is key: the new user is signed into secondaryAuth, so they have permissions
        // to write their own document in the secondary Firestore instance.
        let adminDB = Firestore.firestore()
        
        var staff = HMSUser(id: result.user.uid, email: email, fullName: fullName, role: role)
        staff.department     = department
        staff.specialization = specialization
        staff.employeeID     = employeeID
        
        try await saveUserToFirestore(user: staff, db: adminDB)

        // Step 4 — Save to role-specific collection using secondary DB
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

        // Step 5 — Clean up: sign out of secondary auth
        try? secondaryAuth.signOut()

        // Step 6 — Send password reset email
        try await Auth.auth().sendPasswordReset(withEmail: email)
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
    }

    // MARK: - Admin: Update Staff Member
    func updateStaffMember(
        uid: String,
        fullName: String,
        role: UserRole,
        department: String?,
        specialization: String?,
        employeeID: String?
    ) async throws {
        // Step 1 — Update `users` Firestore collection
        var updates: [String: Any] = [
            "fullName": fullName
        ]
        updates["department"]     = department
        updates["specialization"] = specialization
        updates["employeeID"]     = employeeID

        try await db.collection("users").document(uid).updateData(updates)

        // Step 2 — Update role-specific collection
        switch role {
        case .doctor:
            var doctorUpdates: [String: Any] = ["fullName": fullName]
            doctorUpdates["department"]     = department
            doctorUpdates["specialization"] = specialization
            doctorUpdates["employeeID"]     = employeeID
            try await db.collection("doctors").document(uid).updateData(doctorUpdates)
            
        case .labTechnician:
            var labTechUpdates: [String: Any] = ["fullName": fullName]
            labTechUpdates["department"] = department
            labTechUpdates["employeeID"] = employeeID
            try await db.collection("lab_technicians").document(uid).updateData(labTechUpdates)
        default:
            break
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
}

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
