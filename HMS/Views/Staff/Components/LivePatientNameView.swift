import SwiftUI

/// A view that automatically fetches and displays a patient's live full name 
/// from the `patients` Firestore table, falling back to a cached name if needed.
struct LivePatientNameView: View {
    let patientId: String
    let fallbackName: String
    var font: Font = .system(size: 14)
    var weight: Font.Weight = .regular
    var color: Color = AppTheme.textPrimary
    var lineLimit: Int? = nil
    
    @State private var liveName: String?
    
    var body: some View {
        Text(liveName ?? fallbackName)
            .font(font.weight(weight))
            .foregroundColor(color)
            .lineLimit(lineLimit)
            .task {
                do {
                    let profile = try await DoctorPatientRepository.shared.fetchPatientProfile(patientId: patientId)
                    await MainActor.run {
                        self.liveName = profile.fullName
                    }
                } catch {
                    // Fail silently and use fallback
                }
            }
    }
}

/// A view that fetches the patient's live initials for avatars
struct LivePatientAvatarInitial: View {
    let patientId: String
    let fallbackName: String
    var font: Font = .system(size: 10)
    var weight: Font.Weight = .bold
    var color: Color = AppTheme.textPrimary
    
    @State private var liveName: String?
    
    var body: some View {
        Text(String((liveName ?? fallbackName).prefix(1)))
            .font(font.weight(weight))
            .foregroundColor(color)
            .task {
                do {
                    let profile = try await DoctorPatientRepository.shared.fetchPatientProfile(patientId: patientId)
                    await MainActor.run {
                        self.liveName = profile.fullName
                    }
                } catch {
                    // Fail silently and use fallback
                }
            }
    }
}
