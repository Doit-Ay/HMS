import SwiftUI
import FirebaseFirestore

// MARK: - AI Symptom Checker View
struct AISymptomCheckerView: View {

    @State private var symptoms: String = ""
    @State private var isAnalyzing = false
    @State private var result: TriageResult? = nil
    @State private var recommendedDoctors: [HMSUser] = []
    @State private var isLoadingDoctors = false
    @State private var pulseAnimation = false
    @State private var showResult = false
    @FocusState private var textEditorFocused: Bool

    private let characterLimit = 400

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Header
                    VStack(alignment: .leading, spacing: 8) {
                        Label("AI Symptom Checker", systemImage: "brain.head.profile")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.primary)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(AppTheme.primaryLight.opacity(0.3))
                            .clipShape(Capsule())

                        Text("Describe your symptoms")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Our AI will recommend the right department and doctors for you, instantly.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // MARK: Symptoms Input Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Describe your symptoms")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)

                        ZStack(alignment: .topLeading) {
                            if symptoms.isEmpty {
                                Text("e.g., I have had a severe headache and blurry vision for 2 days…")
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                            }
                            TextEditor(text: $symptoms)
                                .focused($textEditorFocused)
                                .font(.system(size: 16, design: .rounded))
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
                                .font(.system(size: 12, design: .rounded))
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
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            } else {
                                HStack(spacing: 10) {
                                    Image(systemName: "waveform.path.ecg")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Analyze Symptoms")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
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
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                }

                                Text(result.department)
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)

                                Text(result.reason)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)

                                Divider()

                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 11))
                                    Text("This is not a medical diagnosis. Always consult a doctor.")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            .padding(18)
                            .background(AppTheme.cardSurface)
                            .cornerRadius(20)
                            .shadow(color: .green.opacity(0.1), radius: 15, x: 0, y: 6)

                            // Doctors Section
                            Text("Recommended Doctors")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)

                            if isLoadingDoctors {
                                HStack { Spacer(); ProgressView().tint(AppTheme.primary); Spacer() }
                                    .padding(.vertical, 20)
                            } else if recommendedDoctors.isEmpty {
                                HStack { Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: "person.slash.fill").font(.system(size: 36)).foregroundColor(AppTheme.textSecondary.opacity(0.3))
                                        Text("No doctors found in \(result.department)")
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 20)
                            } else {
                                LazyVStack(spacing: 16) {
                                    ForEach(recommendedDoctors) { doctor in
                                        NavigationLink(destination: BookAppointmentView(doctor: doctor)) {
                                            DoctorProfileCard(doctor: doctor)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
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
    }

    // MARK: - Analyze
    private func analyze() async {
        withAnimation {
            isAnalyzing = true
            showResult = false
        }
        let triageResult = await AITriageService.shared.analyzeSymptoms(symptoms)
        await MainActor.run {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.result = triageResult
                self.isAnalyzing = false
                self.showResult = true
            }
        }
        await fetchDoctors(for: triageResult.department)
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
                withAnimation { recommendedDoctors = filtered; isLoadingDoctors = false }
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
