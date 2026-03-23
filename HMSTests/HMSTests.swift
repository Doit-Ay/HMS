//
//  HMSTests.swift
//  HMSTests
//
//  Created by admin99 on 07/03/26.
//

import Testing
import Foundation
@testable import HMS

// MARK: - UserRole Enum Tests
struct UserRoleTests {

    // MARK: Raw Value Parsing
    @Test func patientRawValue() {
        let role = UserRole(rawValue: "patient")
        #expect(role == .patient)
    }

    @Test func adminRawValue() {
        let role = UserRole(rawValue: "admin")
        #expect(role == .admin)
    }

    @Test func doctorRawValue() {
        let role = UserRole(rawValue: "doctor")
        #expect(role == .doctor)
    }

    @Test func labTechnicianRawValue() {
        let role = UserRole(rawValue: "lab_technician")
        #expect(role == .labTechnician)
    }

    @Test func invalidRoleReturnsNil() {
        let role = UserRole(rawValue: "superadmin")
        #expect(role == nil)
    }

    @Test func emptyStringRoleReturnsNil() {
        let role = UserRole(rawValue: "")
        #expect(role == nil)
    }

    // MARK: Display Names
    @Test func patientDisplayName() {
        #expect(UserRole.patient.displayName == "Patient")
    }

    @Test func adminDisplayName() {
        #expect(UserRole.admin.displayName == "Admin")
    }

    @Test func doctorDisplayName() {
        #expect(UserRole.doctor.displayName == "Doctor")
    }

    @Test func labTechnicianDisplayName() {
        #expect(UserRole.labTechnician.displayName == "Lab Technician")
    }

    // MARK: SF Symbols
    @Test func patientSFSymbol() {
        #expect(UserRole.patient.sfSymbol == "person.circle.fill")
    }

    @Test func adminSFSymbol() {
        #expect(UserRole.admin.sfSymbol == "shield.checkered")
    }

    @Test func doctorSFSymbol() {
        #expect(UserRole.doctor.sfSymbol == "stethoscope.circle.fill")
    }

    @Test func labTechnicianSFSymbol() {
        #expect(UserRole.labTechnician.sfSymbol == "flask.fill")
    }

    // MARK: isStaff
    @Test func patientIsNotStaff() {
        #expect(UserRole.patient.isStaff == false)
    }

    @Test func adminIsStaff() {
        #expect(UserRole.admin.isStaff == true)
    }

    @Test func doctorIsStaff() {
        #expect(UserRole.doctor.isStaff == true)
    }

    @Test func labTechnicianIsStaff() {
        #expect(UserRole.labTechnician.isStaff == true)
    }

    // MARK: CaseIterable
    @Test func allCasesCount() {
        #expect(UserRole.allCases.count == 4)
    }

    @Test func allCasesContainsAllRoles() {
        let allCases = UserRole.allCases
        #expect(allCases.contains(.patient))
        #expect(allCases.contains(.admin))
        #expect(allCases.contains(.doctor))
        #expect(allCases.contains(.labTechnician))
    }
}

// MARK: - HMSUser Model Tests
struct HMSUserTests {

    @Test func initializationSetsRequiredFields() {
        let user = HMSUser(id: "uid123", email: "test@hospital.com", fullName: "Dr. Smith", role: .doctor)
        #expect(user.id == "uid123")
        #expect(user.email == "test@hospital.com")
        #expect(user.fullName == "Dr. Smith")
        #expect(user.role == .doctor)
    }

    @Test func initializationSetsIsActiveTrue() {
        let user = HMSUser(id: "uid1", email: "a@b.com", fullName: "Test", role: .patient)
        #expect(user.isActive == true)
    }

    @Test func initializationSetsCreatedAt() {
        let before = Date()
        let user = HMSUser(id: "uid1", email: "a@b.com", fullName: "Test", role: .patient)
        let after = Date()
        #expect(user.createdAt != nil)
        #expect(user.createdAt! >= before)
        #expect(user.createdAt! <= after)
    }

    @Test func optionalFieldsAreNilByDefault() {
        let user = HMSUser(id: "uid1", email: "a@b.com", fullName: "Test", role: .patient)
        #expect(user.phoneNumber == nil)
        #expect(user.dateOfBirth == nil)
        #expect(user.gender == nil)
        #expect(user.profileImageURL == nil)
        #expect(user.department == nil)
        #expect(user.specialization == nil)
        #expect(user.employeeID == nil)
        #expect(user.bloodGroup == nil)
        #expect(user.defaultSlots == nil)
    }

    @Test func optionalFieldsCanBeSet() {
        var user = HMSUser(id: "uid1", email: "doc@h.com", fullName: "Dr. A", role: .doctor)
        user.phoneNumber = "+91-9876543210"
        user.department = "Cardiology"
        user.specialization = "Interventional Cardiology"
        user.employeeID = "EMP001"
        user.defaultSlots = ["morning", "afternoon"]
        #expect(user.phoneNumber == "+91-9876543210")
        #expect(user.department == "Cardiology")
        #expect(user.specialization == "Interventional Cardiology")
        #expect(user.employeeID == "EMP001")
        #expect(user.defaultSlots?.count == 2)
    }
}

// MARK: - PatientProfile Tests
struct PatientProfileTests {

    @Test func convenienceInitCopiesFieldsFromHMSUser() {
        var user = HMSUser(id: "p1", email: "patient@test.com", fullName: "John Doe", role: .patient)
        user.phoneNumber = "1234567890"
        user.bloodGroup = "O+"

        let profile = PatientProfile(from: user)
        #expect(profile.id == "p1")
        #expect(profile.email == "patient@test.com")
        #expect(profile.fullName == "John Doe")
        #expect(profile.phoneNumber == "1234567890")
        #expect(profile.bloodGroup == "O+")
        #expect(profile.isActive == true)
        #expect(profile.createdAt != nil)
    }

    @Test func convenienceInitLeavesOptionalFieldsNil() {
        let user = HMSUser(id: "p2", email: "p@t.com", fullName: "Jane", role: .patient)
        let profile = PatientProfile(from: user)
        #expect(profile.height == nil)
        #expect(profile.weight == nil)
        #expect(profile.address == nil)
        #expect(profile.emergencyContactName == nil)
        #expect(profile.emergencyContactPhone == nil)
        #expect(profile.allergies == nil)
        #expect(profile.medicalHistory == nil)
        #expect(profile.currentMedications == nil)
        #expect(profile.age == nil)
    }
}

// MARK: - DoctorProfile Tests
struct DoctorProfileTests {

    @Test func convenienceInitCopiesFieldsFromHMSUser() {
        var user = HMSUser(id: "d1", email: "dr@test.com", fullName: "Dr. Patel", role: .doctor)
        user.phoneNumber = "9999999999"
        user.dateOfBirth = "1985-05-15"
        user.gender = "Male"
        user.department = "Orthopedics"
        user.specialization = "Joint Replacement"
        user.employeeID = "DOC100"

        let profile = DoctorProfile(from: user)
        #expect(profile.id == "d1")
        #expect(profile.email == "dr@test.com")
        #expect(profile.fullName == "Dr. Patel")
        #expect(profile.phoneNumber == "9999999999")
        #expect(profile.dateOfBirth == "1985-05-15")
        #expect(profile.gender == "Male")
        #expect(profile.department == "Orthopedics")
        #expect(profile.specialization == "Joint Replacement")
        #expect(profile.employeeID == "DOC100")
        #expect(profile.isActive == true)
        #expect(profile.createdAt != nil)
    }

    @Test func qualificationsAndLicenseNumberAreNilByDefault() {
        let user = HMSUser(id: "d2", email: "dr2@t.com", fullName: "Dr. B", role: .doctor)
        let profile = DoctorProfile(from: user)
        #expect(profile.qualifications == nil)
        #expect(profile.licenseNumber == nil)
    }
}

// MARK: - LabTechnicianProfile Tests
struct LabTechnicianProfileTests {

    @Test func convenienceInitCopiesFieldsFromHMSUser() {
        var user = HMSUser(id: "lt1", email: "lab@test.com", fullName: "Ravi Kumar", role: .labTechnician)
        user.phoneNumber = "8888888888"
        user.department = "Pathology"
        user.employeeID = "LAB050"

        let profile = LabTechnicianProfile(from: user)
        #expect(profile.id == "lt1")
        #expect(profile.email == "lab@test.com")
        #expect(profile.fullName == "Ravi Kumar")
        #expect(profile.phoneNumber == "8888888888")
        #expect(profile.department == "Pathology")
        #expect(profile.employeeID == "LAB050")
        #expect(profile.isActive == true)
        #expect(profile.createdAt != nil)
    }

    @Test func certificationsAndLabSectionAreNilByDefault() {
        let user = HMSUser(id: "lt2", email: "lt@t.com", fullName: "Tech", role: .labTechnician)
        let profile = LabTechnicianProfile(from: user)
        #expect(profile.certifications == nil)
        #expect(profile.labSection == nil)
    }
}

// MARK: - SlotStatus Enum Tests
struct SlotStatusTests {

    @Test func availableRawValue() {
        #expect(SlotStatus(rawValue: "available") == .available)
    }

    @Test func unavailableRawValue() {
        #expect(SlotStatus(rawValue: "unavailable") == .unavailable)
    }

    @Test func bookedRawValue() {
        #expect(SlotStatus(rawValue: "booked") == .booked)
    }

    @Test func invalidStatusReturnsNil() {
        #expect(SlotStatus(rawValue: "pending") == nil)
    }

    @Test func displayNames() {
        #expect(SlotStatus.available.displayName == "Available")
        #expect(SlotStatus.unavailable.displayName == "Unavailable")
        #expect(SlotStatus.booked.displayName == "Booked")
    }

    @Test func allCasesCount() {
        #expect(SlotStatus.allCases.count == 3)
    }
}

// MARK: - SystemActivityLog Tests
struct SystemActivityLogTests {

    @Test func initializationWithDefaults() {
        let log = SystemActivityLog(
            userId: "u1",
            userName: "Admin User",
            userRole: .admin,
            action: "User Login"
        )
        #expect(!log.id.isEmpty)               // UUID is auto-generated
        #expect(log.userId == "u1")
        #expect(log.userName == "Admin User")
        #expect(log.userRole == .admin)
        #expect(log.action == "User Login")
        #expect(log.details == nil)             // optional, defaults to nil
    }

    @Test func initializationWithAllFields() {
        let now = Date()
        let log = SystemActivityLog(
            id: "custom-id",
            userId: "u2",
            userName: "Dr. X",
            userRole: .doctor,
            action: "View Patient",
            details: "Viewed patient record #42",
            timestamp: now
        )
        #expect(log.id == "custom-id")
        #expect(log.details == "Viewed patient record #42")
        #expect(log.timestamp == now)
    }

    @Test func timestampDefaultsToNow() {
        let before = Date()
        let log = SystemActivityLog(userId: "u", userName: "N", userRole: .patient, action: "A")
        let after = Date()
        #expect(log.timestamp >= before)
        #expect(log.timestamp <= after)
    }
}

// MARK: - AuthError Tests
struct AuthErrorTests {

    @Test func wrongRoleErrorDescription() {
        let error = AuthError.wrongRole("Not a staff account")
        #expect(error.errorDescription == "Not a staff account")
    }

    @Test func notFoundErrorDescription() {
        let error = AuthError.notFound("No account found")
        #expect(error.errorDescription == "No account found")
    }

    @Test func configurationErrorDescription() {
        let error = AuthError.configuration("Firebase not configured")
        #expect(error.errorDescription == "Firebase not configured")
    }

    @Test func unknownErrorDescription() {
        let error = AuthError.unknown("Something went wrong")
        #expect(error.errorDescription == "Something went wrong")
    }

    @Test func authErrorConformsToLocalizedError() {
        let error: LocalizedError = AuthError.wrongRole("Test")
        #expect(error.errorDescription == "Test")
    }
}

// MARK: - OTPError Tests
struct OTPErrorTests {

    @Test func expiredErrorDescription() {
        let error = OTPError.expired
        #expect(error.errorDescription == "This verification code has expired. Please request a new one.")
    }

    @Test func invalidCodeErrorDescription() {
        let error = OTPError.invalidCode
        #expect(error.errorDescription == "Incorrect verification code. Please try again.")
    }

    @Test func tooManyAttemptsErrorDescription() {
        let error = OTPError.tooManyAttempts
        #expect(error.errorDescription == "Too many failed attempts. Please request a new code.")
    }

    @Test func sendFailedErrorDescription() {
        let error = OTPError.sendFailed("Network timeout")
        #expect(error.errorDescription == "Failed to send verification code: Network timeout")
    }

    @Test func otpErrorConformsToLocalizedError() {
        let error: LocalizedError = OTPError.expired
        #expect(error.errorDescription != nil)
    }
}

// MARK: - UserSession Tests
@MainActor
struct UserSessionTests {

    @Test func setUserUpdatesAllFields() {
        let session = UserSession.shared
        let user = HMSUser(id: "test-uid", email: "test@test.com", fullName: "Test User", role: .patient)

        session.setUser(user, requiresOTP: false)

        #expect(session.currentUser?.id == "test-uid")
        #expect(session.userRole == .patient)
        #expect(session.isLoggedIn == true)
        #expect(session.isLoading == false)
        #expect(session.needsOTPVerification == false)
        #expect(session.pendingOTPEmail == nil)

        // Cleanup
        session.clearSession()
    }

    @Test func setUserWithOTPRequirement() {
        let session = UserSession.shared
        let user = HMSUser(id: "uid2", email: "doc@h.com", fullName: "Dr. Test", role: .doctor)

        session.setUser(user, requiresOTP: true)

        #expect(session.isLoggedIn == true)
        #expect(session.needsOTPVerification == true)
        #expect(session.pendingOTPEmail == "doc@h.com")

        // Cleanup
        session.clearSession()
    }

    @Test func confirmOTPVerificationClearsOTPState() {
        let session = UserSession.shared
        let user = HMSUser(id: "uid3", email: "u@e.com", fullName: "User", role: .admin)

        session.setUser(user, requiresOTP: true)
        #expect(session.needsOTPVerification == true)

        session.confirmOTPVerification()
        #expect(session.needsOTPVerification == false)
        #expect(session.pendingOTPEmail == nil)

        // Cleanup
        session.clearSession()
    }

    @Test func clearSessionResetsEverything() {
        let session = UserSession.shared
        let user = HMSUser(id: "uid4", email: "u@e.com", fullName: "User", role: .labTechnician)
        session.setUser(user, requiresOTP: true)

        session.clearSession()

        #expect(session.currentUser == nil)
        #expect(session.userRole == nil)
        #expect(session.isLoggedIn == false)
        #expect(session.isLoading == false)
        #expect(session.needsOTPVerification == false)
        #expect(session.pendingOTPEmail == nil)
    }

    @Test func setLoadingUpdatesFlag() {
        let session = UserSession.shared

        session.setLoading(true)
        #expect(session.isLoading == true)

        session.setLoading(false)
        #expect(session.isLoading == false)
    }
}

// MARK: - DoctorSlot Model Tests
struct DoctorSlotTests {

    @Test func doctorSlotInitialization() {
        let slot = DoctorSlot(
            id: "slot-1",
            doctorId: "doc-1",
            doctorName: "Dr. Smith",
            department: "Cardiology",
            date: "2026-03-23",
            startTime: "09:00",
            endTime: "09:30",
            status: SlotStatus.available,
            createdAt: Date(),
            updatedAt: Date()
        )
        #expect(slot.id == "slot-1")
        #expect(slot.doctorId == "doc-1")
        #expect(slot.date == "2026-03-23")
        #expect(slot.startTime == "09:00")
        #expect(slot.endTime == "09:30")
        #expect(slot.status == .available)
    }
}

// MARK: - Appointment Model Tests
struct AppointmentTests {

    @Test func appointmentInitialization() {
        let appt = Appointment(
            id: "appt-1",
            slotId: "slot-1",
            doctorId: "doc-1",
            doctorName: "Dr. Smith",
            patientId: "pat-1",
            patientName: "John Doe",
            department: "Cardiology",
            date: "2026-03-23",
            startTime: "09:00",
            endTime: "09:30",
            status: "scheduled",
            createdAt: Date()
        )
        #expect(appt.id == "appt-1")
        #expect(appt.slotId == "slot-1")
        #expect(appt.doctorId == "doc-1")
        #expect(appt.patientId == "pat-1")
        #expect(appt.status == "scheduled")
    }

    @Test func appointmentStatusValues() {
        // Verify the expected status strings work
        let statuses = ["scheduled", "completed", "cancelled"]
        for status in statuses {
            let appt = Appointment(
                id: "a", slotId: "s", doctorId: "d", doctorName: "Dr",
                patientId: "p", patientName: "Pat", date: "2026-01-01",
                startTime: "09:00", endTime: "09:30", status: status
            )
            #expect(appt.status == status)
        }
    }
}

// MARK: - ConsultationNote Model Tests
struct ConsultationNoteTests {

    @Test func consultationNoteInitialization() {
        let note = ConsultationNote(
            id: "cn-1",
            appointmentId: "appt-1",
            doctorId: "doc-1",
            doctorName: "Dr. Patel",
            patientId: "pat-1",
            patientName: "Jane Doe",
            date: "2026-03-23",
            startTime: "10:00",
            endTime: "10:30",
            notes: "Patient presents with mild fever.",
            prescription: "Paracetamol 500mg, twice daily for 3 days",
            createdAt: Date()
        )
        #expect(note.id == "cn-1")
        #expect(note.appointmentId == "appt-1")
        #expect(note.notes == "Patient presents with mild fever.")
        #expect(note.prescription.contains("Paracetamol"))
    }
}

// MARK: - LabTestRequest Model Tests
struct LabTestRequestTests {

    @Test func labTestRequestInitialization() {
        let request = LabTestRequest(
            id: "ltr-1",
            doctorId: "doc-1",
            doctorName: "Dr. A",
            patientId: "pat-1",
            patientName: "Patient B",
            testNames: ["CBC", "Lipid Profile", "Blood Sugar"],
            status: "pending",
            dateReferred: Date()
        )
        #expect(request.id == "ltr-1")
        #expect(request.testNames.count == 3)
        #expect(request.testNames.contains("CBC"))
        #expect(request.status == "pending")
    }
}

// MARK: - PrescriptionDocument Model Tests
struct PrescriptionDocumentTests {

    @Test func prescriptionDocumentInitialization() {
        let doc = PrescriptionDocument(
            id: "rx-1",
            appointmentId: "appt-1",
            doctorId: "doc-1",
            doctorName: "Dr. Kumar",
            patientId: "pat-1",
            patientName: "Arjun",
            date: "2026-03-23",
            startTime: "14:00",
            pdfUrl: "https://storage.example.com/rx-1.pdf",
            createdAt: Date(),
            customName: nil
        )
        #expect(doc.id == "rx-1")
        #expect(doc.pdfUrl.contains("rx-1.pdf"))
        #expect(doc.customName == nil)
    }

    @Test func prescriptionDocumentWithCustomName() {
        let doc = PrescriptionDocument(
            id: "rx-2",
            appointmentId: "appt-2",
            doctorId: "doc-2",
            doctorName: "Dr. B",
            patientId: "pat-2",
            patientName: "Meera",
            date: "2026-03-23",
            startTime: "15:00",
            pdfUrl: "https://example.com/rx.pdf",
            createdAt: Date(),
            customName: "Follow-up Prescription"
        )
        #expect(doc.customName == "Follow-up Prescription")
    }
}

// MARK: - DoctorUnavailability Model Tests
struct DoctorUnavailabilityTests {

    @Test func fullDayUnavailability() {
        let entry = DoctorUnavailability(
            id: "unav-1",
            doctorId: "doc-1",
            date: "2026-03-25",
            type: "unavailable",
            startTime: nil,
            endTime: nil,
            createdAt: Date()
        )
        #expect(entry.type == "unavailable")
        #expect(entry.startTime == nil)
        #expect(entry.endTime == nil)
    }

    @Test func halfDayUnavailability() {
        let entry = DoctorUnavailability(
            id: "unav-2",
            doctorId: "doc-1",
            date: "2026-03-26",
            type: "halfDay",
            startTime: "09:00",
            endTime: "13:00",
            createdAt: Date()
        )
        #expect(entry.type == "halfDay")
        #expect(entry.startTime == "09:00")
        #expect(entry.endTime == "13:00")
    }
}
