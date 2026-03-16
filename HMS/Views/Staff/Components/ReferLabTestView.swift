import SwiftUI
import FirebaseFirestore

struct ReferLabTestView: View {
    @Environment(\.dismiss) var dismiss
    
    // Dependencies
    let doctorId: String
    let doctorName: String
    let patientId: String
    let patientName: String
    
    // Categorized common lab tests for better UI organization
    let testCategories: [(name: String, icon: String, tests: [String])] = [
        ("Routine Blood", "drop.fill", [
            "Complete Blood Count (CBC)",
            "Blood Sugar (Fasting/PP)",
            "HbA1c"
        ]),
        ("Organ Function", "lungs.fill", [
            "Lipid Profile",
            "Liver Function Test (LFT)",
            "Kidney Function Test (KFT)",
            "Thyroid Profile (T3, T4, TSH)"
        ]),
        ("Imaging & Scans", "waveform.path.ecg", [
            "X-Ray Chest PA View",
            "ECG",
            "Ultrasound Whole Abdomen"
        ]),
        ("Other Tests", "microbe.fill", [
            "Urine Routine & Microscopy",
            "Vitamin D (25-OH)",
            "Vitamin B12"
        ])
    ]
    
    // State
    @State private var selectedTests: Set<String> = []
    @State private var customTest: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dynamic background with slight gradient
                LinearGradient(
                    colors: [AppTheme.background, AppTheme.primaryLight.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Premium Header card
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.primaryLight.opacity(0.5))
                                    .frame(width: 56, height: 56)
                                
                                Image(systemName: "microscope")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundColor(AppTheme.primary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Refer Lab Tests")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                HStack(spacing: 4) {
                                    Text("For:")
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                    Text(patientName)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.primaryDark)
                                }
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: AppTheme.primary.opacity(0.08), radius: 12, x: 0, y: 6)
                        .padding(.horizontal)
                        
                        // Categories and Tests
                        VStack(spacing: 20) {
                            ForEach(testCategories, id: \.name) { category in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 8) {
                                        Image(systemName: category.icon)
                                            .foregroundColor(AppTheme.primary)
                                            .font(.system(size: 14, weight: .semibold))
                                        Text(category.name)
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundColor(AppTheme.textPrimary)
                                    }
                                    .padding(.horizontal, 4)
                                    
                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                        ForEach(category.tests, id: \.self) { test in
                                            TestToggleCard(
                                                title: test,
                                                isSelected: selectedTests.contains(test),
                                                action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { toggleTest(test) } }
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Custom Test Input Area
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.dashed")
                                    .foregroundColor(AppTheme.primary)
                                Text("Custom Entry")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            .padding(.horizontal, 4)
                            
                            HStack(spacing: 12) {
                                TextField("Enter specific test name...", text: $customTest)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                    .font(.system(size: 15, design: .rounded))
                                
                                Button(action: {
                                    withAnimation(.spring()) {
                                        addCustomTest()
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 50)
                                        .background(customTest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : AppTheme.primary)
                                        .cornerRadius(12)
                                        .shadow(color: customTest.isEmpty ? Color.clear : AppTheme.primary.opacity(0.3), radius: 5, x: 0, y: 3)
                                }
                                .disabled(customTest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Sticky Bottom Action Area (Empty spacer for scroll padding)
                        Spacer().frame(height: 140)
                    }
                    .padding(.top, 16)
                }
                
                // Floating Bottom Bar for Selection Summary & Submit
                VStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        if !selectedTests.isEmpty {
                            // Selected summary bar
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("\(selectedTests.count) test\(selectedTests.count == 1 ? "" : "s") selected:")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                    Spacer()
                                    Button("Clear All") {
                                        withAnimation { selectedTests.removeAll() }
                                    }
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.red)
                                }
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(selectedTests), id: \.self) { test in
                                            HStack(spacing: 4) {
                                                Text(test)
                                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                                    .foregroundColor(AppTheme.primaryDark)
                                                
                                                Button(action: {
                                                    withAnimation(.spring()) { toggleTest(test) }
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(AppTheme.primaryDark.opacity(0.6))
                                                }
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(AppTheme.primaryLight.opacity(0.6))
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .overlay(
                                Rectangle().frame(height: 1).foregroundColor(Color.gray.opacity(0.1)),
                                alignment: .top
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Submit Button Area
                        VStack(spacing: 12) {
                            if let error = errorMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button(action: saveReferral) {
                                HStack(spacing: 12) {
                                    if isSaving {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Submit Referral")
                                        Image(systemName: "arrow.right.circle.fill")
                                    }
                                }
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(selectedTests.isEmpty ? Color.gray.opacity(0.6) : AppTheme.primary)
                                .cornerRadius(16)
                                .shadow(color: selectedTests.isEmpty ? Color.clear : AppTheme.primary.opacity(0.4), radius: 10, x: 0, y: 5)
                            }
                            .disabled(isSaving || selectedTests.isEmpty)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                        .background(Color.white)
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: -5)
                    .edgesIgnoringSafeArea(.bottom)
                }
            }
            .navigationTitle("Lab Tests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
    
    private func toggleTest(_ test: String) {
        if selectedTests.contains(test) {
            selectedTests.remove(test)
        } else {
            selectedTests.insert(test)
        }
    }
    
    private func addCustomTest() {
        let trimmed = customTest.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            selectedTests.insert(trimmed)
            customTest = ""
        }
    }
    
    private func saveReferral() {
        guard !selectedTests.isEmpty else { return }
        
        Task {
            isSaving = true
            errorMessage = nil
            do {
                let request = LabTestRequest(
                    id: UUID().uuidString,
                    doctorId: doctorId,
                    doctorName: doctorName,
                    patientId: patientId,
                    patientName: patientName,
                    testNames: Array(selectedTests),
                    status: "pending",
                    dateReferred: Date()
                )
                
                try await DoctorPatientRepository.shared.saveLabTestRequest(request)
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct TestToggleCard: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                HStack(alignment: .top) {
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundColor(isSelected ? AppTheme.primaryDark : AppTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer(minLength: 4)
                    
                    ZStack {
                        Circle()
                            .stroke(isSelected ? AppTheme.primary : Color.gray.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        
                        if isSelected {
                            Circle()
                                .fill(AppTheme.primary)
                                .frame(width: 14, height: 14)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(height: 75, alignment: .top)
            .background(isSelected ? AppTheme.primaryLight.opacity(0.2) : Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppTheme.primary.opacity(0.8) : Color.gray.opacity(0.15), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? AppTheme.primary.opacity(0.1) : Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
            .scaleEffect(isSelected ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ReferLabTestView(
        doctorId: "test_doc",
        doctorName: "Dr. Smith",
        patientId: "test_pat",
        patientName: "John Doe"
    )
}

