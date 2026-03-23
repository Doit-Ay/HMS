import SwiftUI

// Model for the patient strip
struct PatientStripModel: Identifiable, Equatable {
    var id: String = UUID().uuidString
    let name: String
    let time: String
    let status: AppointmentStatus
    
    enum AppointmentStatus {
        case upcoming, inProgress, done
        
        var color: Color {
            switch self {
            case .upcoming: return AppTheme.primary
            case .inProgress: return .orange // Amber
            case .done: return AppTheme.textSecondary
            }
        }
        
        var text: String {
            switch self {
            case .upcoming: return "Upcoming"
            case .inProgress: return "In Progress"
            case .done: return "Done"
            }
        }
    }
}

struct PatientCardStrip: View {
    let patients: [PatientStripModel]
    @Binding var activePatientID: String?
    
    // Animation state
    @State private var appearAnimation = false
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Array(patients.enumerated()), id: \.element.id) { index, patient in
                    let isActive = patient.id == activePatientID
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            activePatientID = patient.id
                        }
                    }) {
                        HStack(spacing: 12) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(AppTheme.primaryLight.opacity(0.3))
                                    .frame(width: 44, height: 44)
                                Text(String(patient.name.prefix(1)))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.primaryDark)
                            }
                            
                            // Info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(patient.name)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                    
                                HStack(spacing: 6) {
                                    Text(patient.time)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                    
                                    // Status Pill
                                    Text(patient.status.text)
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(patient.status.color)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(patient.status.color.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppTheme.cardSurface)
                        .cornerRadius(16)
                        // Active state styling
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isActive ? AppTheme.primary : Color.clear, lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(isActive ? 0.08 : 0.04), radius: isActive ? 10 : 6, x: 0, y: isActive ? 4 : 2)
                        .scaleEffect(isActive ? 1.05 : 1.0)
                    }
                    .buttonStyle(.plain)
                    // Staggered slide-in animation
                    .offset(x: appearAnimation ? 0 : 50)
                    .opacity(appearAnimation ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.5).delay(Double(index) * 0.1),
                        value: appearAnimation
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16) // Padding for the scale effect shadow
        }
        .onAppear {
            appearAnimation = true
            // Auto-select the first one if none selected
            if activePatientID == nil, let first = patients.first {
                activePatientID = first.id
            }
        }
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        PatientCardStrip(patients: [
            PatientStripModel(name: "Oliver Smith", time: "09:00 AM", status: .done),
            PatientStripModel(name: "Ava Johnson", time: "10:30 AM", status: .inProgress),
            PatientStripModel(name: "Liam Williams", time: "02:00 PM", status: .upcoming)
        ], activePatientID: .constant(nil))
    }
}
