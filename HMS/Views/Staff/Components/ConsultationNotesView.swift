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
                                Label("Prescribed Medicines", systemImage: "pills.circle.fill")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                // Search Bar
                                VStack(spacing: 0) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(AppTheme.textSecondary)
                                        TextField("Search medicines...", text: $medicineSearchText)
                                            .font(.system(size: 15, design: .rounded))
                                            .onChange(of: medicineSearchText) { val in
                                                showMedicineDropdown = !val.trimmingCharacters(in: .whitespaces).isEmpty
                                            }
                                        if !medicineSearchText.isEmpty {
                                            Button { medicineSearchText = ""; showMedicineDropdown = false } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .background(AppTheme.cardSurface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppTheme.textSecondary.opacity(0.2), lineWidth: 1)
                                    )
                                    
                                    // Dropdown
                                    if showMedicineDropdown {
                                        let filtered = allMedicines.filter { med in
                                            med.name.localizedCaseInsensitiveContains(medicineSearchText) &&
                                            !prescribedMedicines.contains(where: { pm in pm.medicineName == med.name })
                                        }
                                        
                                        if filtered.isEmpty {
                                            Text("No medicines found")
                                                .font(.system(size: 14, design: .rounded))
                                                .foregroundColor(AppTheme.textSecondary)
                                                .padding(12)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(AppTheme.cardSurface)
                                                .cornerRadius(12)
                                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                                        } else {
                                            ScrollView {
                                                LazyVStack(spacing: 0) {
                                                    ForEach(filtered.prefix(8)) { med in
                                                        Button {
                                                            addMedicine(med)
                                                            medicineSearchText = ""
                                                            showMedicineDropdown = false
                                                        } label: {
                                                            HStack {
                                                                VStack(alignment: .leading, spacing: 2) {
                                                                    Text(med.name)
                                                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                                                        .foregroundColor(AppTheme.textPrimary)
                                                                    if let type = med.type {
                                                                        Text(type.capitalized)
                                                                            .font(.system(size: 11, design: .rounded))
                                                                            .foregroundColor(AppTheme.textSecondary)
                                                                    }
                                                                }
                                                                Spacer()
                                                                Image(systemName: "plus.circle.fill")
                                                                    .foregroundColor(AppTheme.primary)
                                                            }
                                                            .padding(.horizontal, 12)
                                                            .padding(.vertical, 10)
                                                        }
                                                        .buttonStyle(.plain)
                                                        if med.id != filtered.prefix(8).last?.id {
                                                            Divider().padding(.horizontal, 12)
                                                        }
                                                    }
                                                }
                                            }
                                            .frame(maxHeight: 230)
                                            .background(AppTheme.cardSurface)
                                            .cornerRadius(12)
                                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                                        }
                                    }
                                }
                                
                                // Prescribed Medicine Cards
                                if !prescribedMedicines.isEmpty {
                                    VStack(spacing: 12) {
                                        ForEach($prescribedMedicines) { $med in
                                            PrescribedMedicineCard(medicine: $med) {
                                                withAnimation(.spring(response: 0.3)) {
                                                    prescribedMedicines.removeAll { $0.id == med.id }
                                                }
                                            }
                                        }
                                    }
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
                await loadMedicines()
            }
            .sheet(isPresented: $showPDFPreview) {
                if let url = generatedPDFURL {
                    PDFViewerSheet(pdfURL: url)
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
                    prescribedMedicines: prescribedMedicines.isEmpty ? nil : prescribedMedicines,
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
                prescribedMedicines = note.prescribedMedicines ?? []
            }
            isLoading = false
        } catch {
            print("Failed to fetch existing notes: \(error)")
            isLoading = false
        }
    }
    
    private func loadMedicines() async {
        isLoadingMedicines = true
        do {
            allMedicines = try await DoctorPatientRepository.shared.fetchMedicines()
        } catch {
            print("Failed to fetch medicines: \(error)")
        }
        isLoadingMedicines = false
    }
    
    private func addMedicine(_ med: AppMedicine) {
        let prescribed = PrescribedMedicine(
            id: UUID().uuidString,
            medicineName: med.name,
            days: 5,
            morning: true,
            afternoon: false,
            night: true,
            beforeFood: false
        )
        withAnimation(.spring(response: 0.3)) {
            prescribedMedicines.append(prescribed)
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
                    prescribedMedicines: prescribedMedicines.isEmpty ? nil : prescribedMedicines,
                    createdAt: existingNoteId == nil ? Date() : nil
                )
                
                // 1. If a prescription was written, generate and upload the PDF silently
                if !prescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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

// MARK: - Prescribed Medicine Card
struct PrescribedMedicineCard: View {
    @Binding var medicine: PrescribedMedicine
    let onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "pill.fill")
                    .foregroundColor(AppTheme.primary)
                    .font(.system(size: 14))
                Text(medicine.medicineName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.7))
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Days
            HStack {
                Text("Duration")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        if medicine.days > 1 { medicine.days -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(AppTheme.primary)
                            .font(.system(size: 22))
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(medicine.days) day\(medicine.days == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(minWidth: 55)
                    
                    Button {
                        medicine.days += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.primary)
                            .font(.system(size: 22))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Timing Toggles
            HStack {
                Text("Timing")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                HStack(spacing: 8) {
                    timingChip(label: "Morning", icon: "sunrise.fill", isOn: $medicine.morning)
                    timingChip(label: "Afternoon", icon: "sun.max.fill", isOn: $medicine.afternoon)
                    timingChip(label: "Night", icon: "moon.fill", isOn: $medicine.night)
                }
            }
            
            // Before/After Food
            HStack {
                Text("Food")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        medicine.beforeFood = true
                    } label: {
                        Text("Before Food")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(medicine.beforeFood ? .white : AppTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(medicine.beforeFood ? AppTheme.primary : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        medicine.beforeFood = false
                    } label: {
                        Text("After Food")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(!medicine.beforeFood ? .white : AppTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(!medicine.beforeFood ? AppTheme.primary : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
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
    
    @ViewBuilder
    private func timingChip(label: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label.prefix(3))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isOn.wrappedValue ? .white : AppTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isOn.wrappedValue ? AppTheme.primary : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
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
