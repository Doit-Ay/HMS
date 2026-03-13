import SwiftUI
import Combine

@MainActor
class PatientDetailViewModel: ObservableObject {
    @Published var patient: PatientProfile?
    @Published var pastAppointments: [Appointment] = []
    @Published var upcomingAppointments: [Appointment] = []
    
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    
    private let patientId: String
    private let doctorId: String
    
    init(patientId: String, doctorId: String) {
        self.patientId = patientId
        self.doctorId = doctorId
    }
    
    func loadPatientData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch profile and appointments concurrently
            async let profileTask = DoctorPatientRepository.shared.fetchPatientProfile(patientId: patientId)
            async let appointmentsTask = DoctorPatientRepository.shared.fetchPatientAppointments(patientId: patientId, doctorId: doctorId)
            
            let (fetchedProfile, fetchedAppointments) = try await (profileTask, appointmentsTask)
            
            self.patient = fetchedProfile
            
            // Filter appointments based on status / date
            self.pastAppointments = fetchedAppointments.filter { $0.status == "completed" || $0.status == "cancelled" }
            self.upcomingAppointments = fetchedAppointments.filter { $0.status == "scheduled" || $0.status == "in-progress" || $0.status == "in_progress" }
            
            // Add slight artificial delay to prevent jarring flash of skeleton loader
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            withAnimation(.easeOut(duration: 0.4)) {
                self.isLoading = false
            }
            
        } catch {
            print("⚠️ Failed to load patient data: \(error.localizedDescription)")
            withAnimation {
                self.errorMessage = "Unable to load patient data. Please try again."
                self.isLoading = false
            }
        }
    }
    
    // Helper to format age
    var ageString: String {
        // First check the direct age field (saved as Int by PatientProfileView)
        if let age = patient?.age, age > 0 {
            return "\(age) yrs"
        }
        // Fallback: try computing from dateOfBirth
        guard let dobString = patient?.dateOfBirth, !dobString.isEmpty, dobString != "Not Set" else {
            return "Unknown"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let dobDate = formatter.date(from: dobString) {
            let ageComponents = Calendar.current.dateComponents([.year], from: dobDate, to: Date())
            if let year = ageComponents.year {
                return "\(year) yrs"
            }
        }
        return "Unknown"
    }
}
