import SwiftUI
import FirebaseFirestore

struct ConsultationNotesView: View {
    @Environment(\.dismiss) var dismiss
    
    // Dependencies
    let appointmentId: String
    let doctorId: String
    let doctorName: String
    let patientId: String
    let patientName: String
    let appointmentDate: String
    let startTime: String
    let endTime: String
    
    // State
    @State private var notes: String = ""
    @State private var prescription: String = ""
    @State private var isSaving = false
    @State private var isLoading = true
    @State private var existingNoteId: String? = nil
    @State private var errorMessage: String? = nil
    
    // PDF Generation State
    @State private var generatedPDFURL: URL? = nil
    @State private var showPDFPreview = false
    @State private var isGeneratingPDF = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading...")
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header banner
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Consultation: \(patientName)")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("Write your notes and prescription below.")
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.primary)
                            }
                            .padding()
                            .background(AppTheme.cardSurface)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                            
                            // Notes Section
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Consultation Notes", systemImage: "note.text")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                TextEditor(text: $notes)
                                    .frame(minHeight: 150)
                                    .padding(8)
                                    .background(AppTheme.cardSurface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppTheme.textSecondary.opacity(0.2), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
                            }
                            
                            // Prescription Section
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Prescription", systemImage: "pills.fill")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                TextEditor(text: $prescription)
                                    .frame(minHeight: 150)
                                    .padding(8)
                                    .background(AppTheme.cardSurface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppTheme.textSecondary.opacity(0.2), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
                            }
                            
                            if let error = errorMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .multilineTextAlignment(.center)
                            }
                            
                            Spacer().frame(height: 20)
                            
                            // Buttons
                            VStack(spacing: 16) {
                                // Save Button
                                Button(action: saveNotes) {
                                    HStack {
                                        if isSaving {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "checkmark.circle.fill")
                                            Text("Save Notes")
                                        }
                                    }
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(AppTheme.primary)
                                    .cornerRadius(16)
                                    .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                                }
                                .disabled(isSaving || isGeneratingPDF)
                                
                                // Generate PDF Button
                                if existingNoteId != nil {
                                    Button(action: generatePDF) {
                                        HStack {
                                            if isGeneratingPDF {
                                                ProgressView()
                                                    .tint(AppTheme.primary)
                                            } else {
                                                Image(systemName: "doc.viewfinder.fill")
                                                Text("Generate Prescription PDF")
                                            }
                                        }
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(AppTheme.primaryLight.opacity(0.3))
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(AppTheme.primary.opacity(0.5), lineWidth: 1.5)
                                        )
                                    }
                                    .disabled(isGeneratingPDF || isSaving)
                                }
                            }
                        }
                        .padding(24)
                    }
                }
            }
            .navigationTitle("Consultation Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                }
            }
            .task {
                await fetchExistingNotes()
            }
            .sheet(isPresented: $showPDFPreview) {
                if let url = generatedPDFURL {
                    PDFViewerSheet(pdfURL: url)
                }
            }
        }
    }
    
    private func generatePDF() {
        Task {
            isGeneratingPDF = true
            errorMessage = nil
            do {
                // Fetch recent lab tests for this patient by this doctor
                let labTests = try await DoctorPatientRepository.shared.fetchLabTestRequests(patientId: patientId, doctorId: doctorId)
                
                // Construct the current note state
                let noteId = existingNoteId ?? UUID().uuidString
                let note = ConsultationNote(
                    id: noteId,
                    appointmentId: appointmentId,
                    doctorId: doctorId,
                    doctorName: doctorName,
                    patientId: patientId,
                    patientName: patientName,
                    date: appointmentDate,
                    startTime: startTime,
                    endTime: endTime,
                    notes: notes,
                    prescription: prescription, // Use live text
                    createdAt: Date()
                )
                
                let generator = PrescriptionPDFGenerator()
                if let url = generator.generatePDF(note: note, labTests: labTests, patientAge: nil, patientGender: nil) {
                    await MainActor.run {
                        self.generatedPDFURL = url
                        self.showPDFPreview = true
                        self.isGeneratingPDF = false
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "Failed to generate PDF."
                        self.isGeneratingPDF = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to fetch data for PDF: \(error.localizedDescription)"
                    self.isGeneratingPDF = false
                }
            }
        }
    }
    
    private func fetchExistingNotes() async {
        do {
            isLoading = true
            if let note = try await DoctorPatientRepository.shared.fetchConsultationNote(appointmentId: appointmentId) {
                existingNoteId = note.id
                notes = note.notes
                prescription = note.prescription
            }
            isLoading = false
        } catch {
            print("Failed to fetch existing notes: \(error)")
            isLoading = false
        }
    }
    
    private func saveNotes() {
        Task {
            isSaving = true
            errorMessage = nil
            do {
                let noteId = existingNoteId ?? UUID().uuidString
                let note = ConsultationNote(
                    id: noteId,
                    appointmentId: appointmentId,
                    doctorId: doctorId,
                    doctorName: doctorName,
                    patientId: patientId,
                    patientName: patientName,
                    date: appointmentDate,
                    startTime: startTime,
                    endTime: endTime,
                    notes: notes,
                    prescription: prescription,
                    createdAt: existingNoteId == nil ? Date() : nil // preserve existing if possible, or omit
                )
                
                // 1. If a prescription was written, generate and upload the PDF silently
                if !prescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let labTests = try? await DoctorPatientRepository.shared.fetchLabTestRequests(patientId: patientId, doctorId: doctorId)
                    
                    let generator = PrescriptionPDFGenerator()
                    if let rawPdfURL = generator.generatePDF(note: note, labTests: labTests ?? [], patientAge: nil, patientGender: nil) {
                        // 2. Upload to Firebase Storage
                        let remoteUrl = try await DoctorPatientRepository.shared.uploadPrescriptionPDF(localURL: rawPdfURL, appointmentId: appointmentId)
                        
                        // 3. Save the metadata document
                        let prescriptionDoc = PrescriptionDocument(
                            id: UUID().uuidString,
                            appointmentId: appointmentId,
                            doctorId: doctorId,
                            doctorName: doctorName,
                            patientId: patientId,
                            patientName: patientName,
                            date: appointmentDate,
                            startTime: startTime,
                            pdfUrl: remoteUrl,
                            createdAt: Date()
                        )
                        try await DoctorPatientRepository.shared.savePrescriptionDocument(prescriptionDoc)
                        
                        print("Saved Prescription to Database completely!")
                    }
                }
                
                // 4. Finally, save the core consultation note
                try await DoctorPatientRepository.shared.saveConsultationNote(note)
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    ConsultationNotesView(
        appointmentId: "test_appt",
        doctorId: "test_doc",
        doctorName: "Dr. Smith",
        patientId: "test_pat",
        patientName: "John Doe",
        appointmentDate: "2026-03-16",
        startTime: "10:00",
        endTime: "10:30"
    )
}
