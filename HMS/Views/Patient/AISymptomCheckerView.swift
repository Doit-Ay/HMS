import SwiftUI
import FirebaseFirestore

// MARK: - AI Symptom Checker View
struct AISymptomCheckerView: View {

    @State private var symptoms: String = ""
    @State private var isAnalyzing = false
    @State private var result: TriageResult? = nil
    @State private var recommendedDoctors: [HMSUser] = []
    @State private var isLoadingDoctors = false
    @State private var showResult = false
    @State private var showDoctors = false
    @FocusState private var textEditorFocused: Bool

    @State private var showInvalidInput = false

    private let characterLimit = 400

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Header
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 14) {
                            // Modern icon badge using app brand colors
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.primary, AppTheme.primaryMid],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 48, height: 48)
                                    .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)

                                Image(systemName: "stethoscope")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("AI Symptom Checker")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.primary)
                                    .textCase(.uppercase)
                                    .tracking(0.8)

                                Text("Describe your symptoms")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }

                        Text("Tell us what you're experiencing, and our AI will recommend the right specialist for you.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(AppTheme.textSecondary.opacity(0.8))
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // MARK: Symptoms Input Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Describe your symptoms")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)

                        ZStack(alignment: .topLeading) {
                            if symptoms.isEmpty {
                                Text("e.g., I have had a severe headache and blurry vision for 2 days…")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                            }
                            TextEditor(text: $symptoms)
                                .focused($textEditorFocused)
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.textPrimary)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 130)
                                .onChange(of: symptoms) { newVal in
                                    if newVal.count > characterLimit {
                                        symptoms = String(newVal.prefix(characterLimit))
                                    }
                                }
                        }

                        HStack {
                            Spacer()
                            Text("\(symptoms.count)/\(characterLimit)")
                                .font(.system(size: 12))
                                .foregroundColor(symptoms.count > 350 ? .orange : AppTheme.textSecondary.opacity(0.5))
                        }
                    }
                    .padding(18)
                    .background(AppTheme.cardSurface)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                    .padding(.horizontal, 20)

                    // MARK: Analyze Button
                    Button {
                        textEditorFocused = false
                        Task { await analyze() }
                    } label: {
                        ZStack {
                            if isAnalyzing {
                                HStack(spacing: 12) {
                                    PulsingDotsView()
                                    Text("Analyzing…")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            } else {
                                HStack(spacing: 10) {
                                    Image(systemName: "waveform.path.ecg")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Analyze Symptoms")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            symptoms.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? AnyView(AppTheme.textSecondary.opacity(0.4))
                            : AnyView(LinearGradient(
                                colors: [AppTheme.dashboardCardGradientStart, AppTheme.dashboardCardGradientEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                        )
                        .cornerRadius(18)
                        .shadow(
                            color: symptoms.isEmpty ? .clear : AppTheme.primary.opacity(0.35),
                            radius: 16, x: 0, y: 8
                        )
                    }
                    .disabled(symptoms.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)

                    // MARK: Results
                    if showResult, let result = result {
                        VStack(alignment: .leading, spacing: 20) {

                            // Department Result Card
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 20))
                                    Text("AI Recommendation")
                                        .font(.system(size: 13, weight: .bold, design: .default))
                                        .textCase(.uppercase)
                                        .foregroundColor(AppTheme.textSecondary)
                                    
                                    Spacer()
                                    
                                    Text(result.urgencyLevel.uppercased())
                                        .font(.system(size: 12, weight: .bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(
                                            result.urgencyLevel.lowercased() == "emergency" ? Color.red.opacity(0.15) :
                                            result.urgencyLevel.lowercased() == "urgent" ? Color.orange.opacity(0.15) :
                                            Color.green.opacity(0.15)
                                        )
                                        .foregroundColor(
                                            result.urgencyLevel.lowercased() == "emergency" ? .red :
                                            result.urgencyLevel.lowercased() == "urgent" ? .orange :
                                            .green
                                        )
                                        .cornerRadius(8)
                                }

                                Text(result.department)
                                    .font(.system(size: 28, weight: .bold, design: .serif))
                                    .foregroundColor(AppTheme.textPrimary)

                                Text(result.reason)
                                    .font(.system(size: 15, weight: .regular, design: .default))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .lineSpacing(2)
                                
                                if !result.possibleConditions.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Possible Conditions:")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(AppTheme.textPrimary)
                                        
                                        ForEach(result.possibleConditions, id: \.self) { condition in
                                            HStack(alignment: .top, spacing: 6) {
                                                Circle()
                                                    .fill(AppTheme.textSecondary.opacity(0.5))
                                                    .frame(width: 4, height: 4)
                                                    .padding(.top, 6)
                                                Text(condition)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(AppTheme.textSecondary)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                
                                if !result.homeCare.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "cross.case.fill")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 12))
                                            Text("Home Care / First Aid")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(AppTheme.textPrimary)
                                        }
                                        Text(result.homeCare)
                                            .font(.system(size: 14))
                                            .foregroundColor(AppTheme.textSecondary)
                                            .lineSpacing(2)
                                    }
                                    .padding(.all, 12)
                                    .background(Color.blue.opacity(0.05))
                                    .cornerRadius(12)
                                    .padding(.vertical, 4)
                                }

                                Divider()

                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 11))
                                    Text("This is not a medical diagnosis. Always consult a doctor.")
                                        .font(.system(size: 12, weight: .regular, design: .default))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            .padding(18)
                            .background(AppTheme.cardSurface)
                            .cornerRadius(20)
                            .shadow(color: .green.opacity(0.1), radius: 15, x: 0, y: 6)

                            // Doctors Section
                            Text("Recommended Doctors")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)

                            if isLoadingDoctors {
                                HStack { Spacer(); ProgressView().tint(AppTheme.primary); Spacer() }
                                    .padding(.vertical, 20)
                            } else if recommendedDoctors.isEmpty {
                                VStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(AppTheme.primaryLight.opacity(0.2))
                                            .frame(width: 80, height: 80)
                                        Image(systemName: "calendar.badge.clock")
                                            .font(.system(size: 32))
                                            .foregroundColor(AppTheme.primary)
                                            .offset(x: -2, y: 0)
                                    }
                                    
                                    VStack(spacing: 6) {
                                        Text("Check Back Soon")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(AppTheme.textPrimary)
                                        
                                        Text("We currently don't have available doctors in \(result.department). Let us notify you when schedules open up.")
                                            .font(.system(size: 14, weight: .regular, design: .default))
                                            .foregroundColor(AppTheme.textSecondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 20)
                                            .lineSpacing(3)
                                    }
                                }
                                .padding(.vertical, 30)
                                .frame(maxWidth: .infinity)
                                .background(AppTheme.cardSurface)
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                            } else if showDoctors {
                                LazyVStack(spacing: 16) {
                                    ForEach(recommendedDoctors) { doctor in
                                        NavigationLink(destination: BookAppointmentView(doctor: doctor)) {
                                            DoctorProfileCard(doctor: doctor)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("AI Checker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert("Invalid Input", isPresented: $showInvalidInput) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please describe your medical symptoms clearly. For example: \"I have a headache and fever for 2 days.\"")
        }
    }

    // MARK: - Analyze
    private func analyze() async {
        withAnimation {
            isAnalyzing = true
            showResult = false
            showDoctors = false
        }
        let triageResult = await AITriageService.shared.analyzeSymptoms(symptoms)
        await MainActor.run {
            if let triageResult = triageResult {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.result = triageResult
                    self.isAnalyzing = false
                    self.showResult = true
                }
            } else {
                // Input was not a valid medical symptom
                withAnimation {
                    self.isAnalyzing = false
                    self.showResult = false
                    self.showDoctors = false
                    self.showInvalidInput = true
                }
            }
        }
        if let triageResult = triageResult {
            await fetchDoctors(for: triageResult.department)
        }
    }

    private func fetchDoctors(for department: String) async {
        await MainActor.run { isLoadingDoctors = true }
        do {
            let allDoctors = try await AuthManager.shared.fetchDoctors()
            
            let filtered = allDoctors.filter { doctor in
                let docDept = (doctor.department ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                let docSpec = (doctor.specialization ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                let aiDept = department.lowercased().trimmingCharacters(in: .whitespaces)
                
                if docDept.isEmpty && docSpec.isEmpty { return false }
                
                // 1. Direct or Contains match
                if docDept.contains(aiDept) || aiDept.contains(docDept) { return true }
                if docSpec.contains(aiDept) || aiDept.contains(docSpec) { return true }
                
                // 2. Root word approximations for common medical fields
                let roots = [
                    "cardio", "ortho", "pedia", "paedia", "neuro", "derma", 
                    "ophthal", "gynae", "gyne", "psych", "gastro", "uro", 
                    "onco", "general", "physician", "ent"
                ]
                
                for root in roots {
                    if aiDept.contains(root) && (docDept.contains(root) || docSpec.contains(root)) {
                        return true
                    }
                }
                
                return false
            }
            
            await MainActor.run {
                withAnimation { 
                    recommendedDoctors = filtered
                    isLoadingDoctors = false 
                }
                
                // Staggered animation for showing doctors after result card
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.showDoctors = true
                    }
                }
            }
        } catch {
            await MainActor.run { isLoadingDoctors = false }
        }
    }
}

// MARK: - Pulsing Dots Loader
struct PulsingDotsView: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 7, height: 7)
                    .scaleEffect(animate ? 1.0 : 0.4)
                    .opacity(animate ? 1 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.55)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.18),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

#Preview {
    NavigationStack {
        AISymptomCheckerView()
    }
}
