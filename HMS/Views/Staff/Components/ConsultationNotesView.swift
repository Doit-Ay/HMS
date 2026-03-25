import SwiftUI
import FirebaseFirestore
import Combine

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
    
    // Dictation State
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var activeDictationField: DictationField? = nil
    @State private var textBeforeDictation: String = ""
    @State private var dictationStartDate: Date? = nil
    
    // Medicine State
    @State private var allMedicines: [AppMedicine] = []
    @State private var prescribedMedicines: [PrescribedMedicine] = []
    @State private var medicineSearchText: String = ""
    @State private var showMedicineDropdown: Bool = false
    @State private var isLoadingMedicines: Bool = false
    @State private var showMedicineSheet: Bool = false
    
    // Currently ConsultationNotesView doesn't pass doctor department directly,
    // so we'll pass nil to MedicinePrescriptionSheet to show all initially,
    // or we can fetch it if needed. For now, nil is fine.
    var doctorDepartment: String? = nil
    
    enum DictationField {
        case notes, prescription
    }
    
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
                                HStack {
                                    Label("Consultation Notes", systemImage: "note.text")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    dictationButton(for: .notes)
                                }
                                
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
                                HStack {
                                    Label("Prescription", systemImage: "pills.fill")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    dictationButton(for: .prescription)
                                }
                                
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
                            
                            // MARK: Prescribed Medicines Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label("Prescribed Medicines", systemImage: "pills.circle.fill")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    Button {
                                        showMedicineSheet = true
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(AppTheme.primary)
                                            .font(.system(size: 20))
                                    }
                                }
                                
                                // Prescribed Medicine Cards
                                if !prescribedMedicines.isEmpty {
                                    VStack(spacing: 12) {
                                        ForEach($prescribedMedicines) { $med in
                                            PrescribedMedicineCard(medicine: med) {
                                                withAnimation(.spring(response: 0.3)) {
                                                    prescribedMedicines.removeAll { $0.id == med.id }
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    Text("No medicines prescribed yet.")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .padding(.vertical, 8)
                                }
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
            .sheet(isPresented: $showMedicineSheet) {
                MedicinePrescriptionSheet(doctorDepartment: doctorDepartment) { med in
                    withAnimation(.spring(response: 0.3)) {
                        prescribedMedicines.append(med)
                    }
                }
            }
            .onChange(of: speechRecognizer.transcript) { newTranscript in
                guard !newTranscript.isEmpty, let field = activeDictationField else { return }
                
                let separator = textBeforeDictation.isEmpty ? "" : " "
                switch field {
                case .notes:
                    self.notes = textBeforeDictation + separator + newTranscript
                case .prescription:
                    self.prescription = textBeforeDictation + separator + newTranscript
                }
            }
        }
        .onDisappear {
            speechRecognizer.stopTranscribing()
        }
    }
    
    @ViewBuilder
    private func dictationButton(for field: DictationField) -> some View {
        let isDictatingThis = activeDictationField == field
        let activeColor = Color.red
        
        HStack(spacing: 12) {
            if isDictatingThis {
                HStack(spacing: 8) {
                    if let startDate = dictationStartDate {
                        Text(startDate, style: .timer)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundColor(activeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(activeColor.opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    AudioVisualizerView(isRecording: true, color: activeColor)
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
            
            Button(action: {
                toggleDictation(for: field)
            }) {
                Image(systemName: isDictatingThis ? "mic.fill" : "mic")
                    .font(.system(size: 18))
                    .foregroundColor(isDictatingThis ? .white : AppTheme.primary)
                    .padding(8)
                    .background(isDictatingThis ? activeColor : Color.gray.opacity(0.1))
                    .clipShape(Circle())
                    .shadow(color: isDictatingThis ? activeColor.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
            }
        }
    }
    
    private func toggleDictation(for field: DictationField) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if activeDictationField != nil {
                // Stop current dictation
                speechRecognizer.stopTranscribing()
                let previousField = activeDictationField
                activeDictationField = nil
                dictationStartDate = nil
                
                // If they tapped a different field, switch it immediately
                if previousField != field {
                    activeDictationField = field
                    textBeforeDictation = field == .notes ? notes : prescription
                    dictationStartDate = Date()
                    speechRecognizer.startTranscribing()
                }
            } else {
                // Start dictation
                activeDictationField = field
                textBeforeDictation = field == .notes ? notes : prescription
                dictationStartDate = Date()
                speechRecognizer.startTranscribing()
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
                    prescription: prescription,
                    createdAt: Date()
                )
                
                let generator = PrescriptionPDFGenerator()
                if let url = generator.generatePDF(note: note, labTests: [], prescribedMedicines: prescribedMedicines, patientAge: nil, patientGender: nil) {
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
                // Fetch medicines from the sub-collection
                prescribedMedicines = try await InventoryRepository.shared.fetchPrescribedMedicines(noteId: note.id)
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
                    createdAt: existingNoteId == nil ? Date() : nil
                )
                
                // 1. If a prescription was written, generate and upload the PDF silently
                if !prescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !prescribedMedicines.isEmpty {
                    let labTests = try? await DoctorPatientRepository.shared.fetchLabTestRequests(patientId: patientId, doctorId: doctorId)
                    
                    let generator = PrescriptionPDFGenerator()
                    if let rawPdfURL = generator.generatePDF(note: note, labTests: [], prescribedMedicines: prescribedMedicines, patientAge: nil, patientGender: nil) {
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
                    }
                }
                
                // 4. Save the core consultation note
                try await DoctorPatientRepository.shared.saveConsultationNote(note)
                
                // 5. Save the prescribed medicines to sub-collection
                if !prescribedMedicines.isEmpty {
                    try await InventoryRepository.shared.savePrescribedMedicines(noteId: noteId, medicines: prescribedMedicines)
                    
                    // Deduct stock for medicines
                    for med in prescribedMedicines {
                        let quantityToDeduct = med.timesPerDay * med.durationDays
                        try? await InventoryRepository.shared.deductStock(itemId: med.medicineId, quantity: quantityToDeduct)
                    }
                }
                
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

// MARK: - Prescribed Medicine Card
struct PrescribedMedicineCard: View {
    let medicine: PrescribedMedicine
    let onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: medicine.medicineType.sfSymbol)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(medicine.medicineName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(medicine.medicineType.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.7))
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            HStack {
                // Frequency
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(AppTheme.textSecondary)
                        .font(.system(size: 12))
                    Text(medicine.timesPerDay == 1 ? "Once daily" : medicine.timesPerDay == 2 ? "Twice daily" : "\(medicine.timesPerDay)x daily")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Duration
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundColor(AppTheme.textSecondary)
                        .font(.system(size: 12))
                    Text("For \(medicine.durationDays) day\(medicine.durationDays == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let notes = medicine.notes, !notes.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.bubble.fill")
                        .foregroundColor(AppTheme.textSecondary)
                        .font(.system(size: 12))
                        .padding(.top, 2)
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                        .italic()
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardSurface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.primary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
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
