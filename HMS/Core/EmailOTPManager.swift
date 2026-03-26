import Foundation
import FirebaseFirestore

// MARK: - Email OTP Manager
// Handles OTP generation, Firestore storage, email trigger, and verification.
// Email delivery requires the Firebase "Trigger Email" extension installed in your project.
// Without it, OTPs are still stored in Firestore for manual/dev verification.
@MainActor
class EmailOTPManager {

    static let shared = EmailOTPManager()
    private var db: Firestore { Firestore.firestore() }
    private let otpLength = 6
    private let otpExpirySeconds: TimeInterval = 300  // 5 minutes

    private init() {}

    // MARK: - Generate & Send OTP

    /// Generates a 6-digit OTP, stores it in Firestore, and triggers email delivery.
    /// Returns the document ID for tracking.
    @discardableResult
    func sendOTP(to email: String) async throws -> String {
        let code = generateCode()
        let docId = UUID().uuidString
        let now = Date()
        let expiry = now.addingTimeInterval(otpExpirySeconds)

        // 1. Store OTP in `otp_verifications` collection
        let otpData: [String: Any] = [
            "email": email.lowercased(),
            "code": code,
            "createdAt": Timestamp(date: now),
            "expiresAt": Timestamp(date: expiry),
            "verified": false,
            "attempts": 0
        ]
        try await db.collection("otp_verifications").document(docId).setData(otpData)

        // 2. Write to `mail` collection for Firebase Trigger Email extension
        let mailData: [String: Any] = [
            "to": email.lowercased(),
            "message": [
                "subject": "CureIt - Your Verification Code",
                "html": """
                <!DOCTYPE html>
                <html>
                <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
                </head>
                <body style="margin: 0; padding: 0; background-color: #F5F8FA;">
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color: #F5F8FA;">
                <tr><td align="center" style="padding: 24px 16px;">
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width: 420px; background: #FFFFFF; border-radius: 20px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.06);">

                <!-- Header -->
                <tr><td style="background: linear-gradient(135deg, #05AA97, #4ECDC4); padding: 28px 24px; text-align: center;">
                    <h1 style="color: #FFFFFF; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; font-size: 26px; font-weight: 800; margin: 0; letter-spacing: -0.5px;">CureIt</h1>
                    <p style="color: rgba(255,255,255,0.85); font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 12px; margin: 4px 0 0 0;">Your Health, Our Priority</p>
                </td></tr>

                <!-- Body -->
                <tr><td style="padding: 32px 24px 24px;">
                    <h2 style="text-align: center; color: #1A2B3C; font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 20px; font-weight: 700; margin: 0 0 8px 0;">Verify Your Email</h2>
                    <p style="text-align: center; color: #6B7B8D; font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 14px; line-height: 1.5; margin: 0 0 28px 0;">Use the code below to complete your sign-in to CureIt.</p>

                    <!-- OTP Code Box -->
                    <div style="background: #F0FAFA; border: 2px solid #05AA97; border-radius: 16px; padding: 20px 16px; text-align: center; margin: 0 0 24px 0;">
                        <span style="font-family: -apple-system, BlinkMacSystemFont, 'Courier New', monospace; font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #1A2B3C;">\(code)</span>
                    </div>

                    <p style="text-align: center; color: #9BABB8; font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 13px; line-height: 1.6; margin: 0;">This code expires in <strong style="color: #6B7B8D;">5 minutes</strong>.<br>If you didn't request this, you can safely ignore this email.</p>
                </td></tr>

                <!-- Footer -->
                <tr><td style="padding: 16px 24px 24px; text-align: center; border-top: 1px solid #F0F2F5;">
                    <p style="color: #B0BEC5; font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 11px; margin: 0;">© CureIt Health Services</p>
                </td></tr>

                </table>
                </td></tr>
                </table>
                </body>
                </html>
                """
            ] as [String: Any]
        ]
        try await db.collection("mail").document(docId).setData(mailData)

        #if DEBUG
        print("📧 OTP sent to \(email) [doc: \(docId)]")
        #endif
        return docId
    }

    // MARK: - Verify OTP

    /// Verifies the OTP code entered by the user.
    /// Returns `true` if valid, throws on failure.
    func verifyOTP(email: String, code: String) async throws -> Bool {
        let normalizedEmail = email.lowercased()

        // Query for the most recent unverified OTP for this email
        let snapshot = try await db.collection("otp_verifications")
            .whereField("email", isEqualTo: normalizedEmail)
            .whereField("verified", isEqualTo: false)
            .getDocuments()

        // Find the most recent valid entry
        let validDocs = snapshot.documents.compactMap { doc -> (DocumentSnapshot, Date)? in
            guard let expiresAt = (doc.data()["expiresAt"] as? Timestamp)?.dateValue(),
                  expiresAt > Date() else { return nil }
            let createdAt = (doc.data()["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
            return (doc, createdAt)
        }.sorted { $0.1 > $1.1 }  // newest first

        guard let (latestDoc, _) = validDocs.first else {
            throw OTPError.expired
        }

        // Check attempt count (max 5)
        let attempts = latestDoc.data()?["attempts"] as? Int ?? 0
        if attempts >= 5 {
            throw OTPError.tooManyAttempts
        }

        // Increment attempts
        try await latestDoc.reference.updateData(["attempts": attempts + 1])

        // Check the code
        let storedCode = latestDoc.data()?["code"] as? String ?? ""
        if storedCode == code {
            // Mark as verified
            try await latestDoc.reference.updateData(["verified": true])
            // Clean up older unverified OTPs for this email
            await cleanupOldOTPs(email: normalizedEmail)
            return true
        } else {
            throw OTPError.invalidCode
        }
    }

    // MARK: - Resend OTP

    /// Invalidates any existing OTP and sends a fresh one.
    @discardableResult
    func resendOTP(to email: String) async throws -> String {
        // Delete all unverified OTPs for this email
        let normalizedEmail = email.lowercased()
        let snapshot = try await db.collection("otp_verifications")
            .whereField("email", isEqualTo: normalizedEmail)
            .whereField("verified", isEqualTo: false)
            .getDocuments()

        for doc in snapshot.documents {
            try await doc.reference.delete()
        }

        // Send a new OTP
        return try await sendOTP(to: email)
    }

    // MARK: - Helpers

    private func generateCode() -> String {
        let code = Int.random(in: 100000...999999)
        return String(code)
    }

    private func cleanupOldOTPs(email: String) async {
        do {
            let snapshot = try await db.collection("otp_verifications")
                .whereField("email", isEqualTo: email)
                .whereField("verified", isEqualTo: false)
                .getDocuments()
            for doc in snapshot.documents {
                try? await doc.reference.delete()
            }
        } catch {
            #if DEBUG
            print("OTP cleanup error: \(error)")
            #endif
        }
    }
}

// MARK: - OTP Errors
enum OTPError: LocalizedError {
    case expired
    case invalidCode
    case tooManyAttempts
    case sendFailed(String)

    var errorDescription: String? {
        switch self {
        case .expired:
            return "This verification code has expired. Please request a new one."
        case .invalidCode:
            return "Incorrect verification code. Please try again."
        case .tooManyAttempts:
            return "Too many failed attempts. Please request a new code."
        case .sendFailed(let msg):
            return "Failed to send verification code: \(msg)"
        }
    }
}
