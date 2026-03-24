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
                    VStack(alignment: .leading, spacing: 14) {
                        // Custom App Color Icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.69, green: 0.35, blue: 0.88), Color(red: 0.39, green: 0.35, blue: 0.86)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                                .shadow(color: Color(red: 0.39, green: 0.35, blue: 0.86).opacity(0.3), radius: 6, x: 0, y: 3)
                            
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        Text("Describe your symptoms")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Share what's bothering you, and our AI will guide you to the right specialist.")
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
                                }

                                Text(result.department)
                                    .font(.system(size: 28, weight: .bold, design: .serif))
                                    .foregroundColor(AppTheme.textPrimary)

                                Text(result.reason)
                                    .font(.system(size: 15, weight: .regular, design: .default))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .lineSpacing(2)

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
