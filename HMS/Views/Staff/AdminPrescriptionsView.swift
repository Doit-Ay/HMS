import SwiftUI

struct AdminPrescriptionsView: View {
    let patientId: String
    let patientName: String
    
    @Environment(\.openURL) var openURL
    @State private var prescriptions: [PrescriptionDocument] = []
    @State private var consultationNotes: [ConsultationNote] = []
    @State private var isLoading = true
    @State private var animate = false
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            if isLoading {
                ProgressView("Fetching Prescriptions...")
                    .tint(AppTheme.primary)
            } else if prescriptions.isEmpty && consultationNotes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "pills.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.3))
                    Text("No Prescriptions Found")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    Text("There are no records of previous prescriptions.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        // Display PDFs from PrescriptionDocuments
                        ForEach(Array(prescriptions.enumerated()), id: \.element.id) { index, doc in
                            NavigationLink(destination: AdminDocumentViewerView(
                                name: "Prescription - \(doc.date)",
                                fileURL: doc.pdfUrl,
                                fileType: "pdf"
                            )) {
                                PrescriptionCard(
                                    doctorName: doc.doctorName,
                                    date: doc.date,
                                    type: "PDF Document"
                                )
                            }
                            .buttonStyle(.plain)
                            .offset(y: animate ? 0 : 20)
                            .opacity(animate ? 1 : 0)
                            .animation(.spring().delay(Double(index) * 0.05), value: animate)
                        }
                        
                        // Display simple text prescriptions from ConsultationNotes
                        ForEach(Array(consultationNotes.enumerated()), id: \.element.id) { index, note in
                            NavigationLink(destination: ConsultationNoteDetailView(note: note)) {
                                PrescriptionCard(
                                    doctorName: note.doctorName,
                                    date: note.date,
                                    type: "Consultation Note"
                                )
                            }
                            .buttonStyle(.plain)
                            .offset(y: animate ? 0 : 20)
                            .opacity(animate ? 1 : 0)
                            .animation(.spring().delay(Double(prescriptions.count + index) * 0.05), value: animate)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Prescriptions")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchPrescriptions()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { animate = true }
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    private func fetchPrescriptions() async {
        do {
            async let fetchDocs = DoctorPatientRepository.shared.fetchPatientPrescriptions(patientId: patientId)
            
            // Wait for both
            let fetchedPrescriptions = try await fetchDocs
            
            withAnimation {
                self.prescriptions = fetchedPrescriptions
                self.isLoading = false
            }
        } catch {
            print("Error fetching prescriptions: \(error)")
            withAnimation { isLoading = false }
        }
    }
}

struct PrescriptionCard: View {
    let doctorName: String
    let date: String
    let type: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: "pills.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(doctorName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                
                HStack {
                    Text(type)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.orange)
                    Spacer()
                    Text(date)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(AppTheme.textSecondary.opacity(0.4))
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(16)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

struct ConsultationNoteDetailView: View {
    let note: ConsultationNote
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Doctor")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    Text(note.doctorName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prescription")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    Text(note.prescription.isEmpty ? "No prescription provided." : note.prescription)
                        .font(.system(size: 16, design: .rounded))
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Consultation Notes")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    Text(note.notes.isEmpty ? "No notes provided." : note.notes)
                        .font(.system(size: 16, design: .rounded))
                }
            }
            .padding(24)
        }
        .navigationTitle("Note Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
