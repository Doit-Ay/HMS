//
//  MedicinePrescriptionSheet.swift
//  HMS
//
//  Created by Nishtha on 25/03/26.
//

import SwiftUI

// MARK: - Medicine Prescription Sheet
// Shown when a doctor taps "Add Medicine" in ConsultationNotesView.
// Loads medicines filtered to the doctor's department from Firestore.
struct MedicinePrescriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let doctorDepartment: String?
    let onAdd: (PrescribedMedicine) -> Void

    @State private var medicines: [InventoryItem] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedMedicine: InventoryItem? = nil

    // Form state (shown after selecting a medicine)
    @State private var timesPerDay: Int = 1
    @State private var durationDays: Int = 5
    @State private var notes: String = ""
    @State private var showForm = false

    private var filtered: [InventoryItem] {
        guard !searchText.isEmpty else { return medicines }
        return medicines.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading Medicines…").tint(AppTheme.primary)
                } else if medicines.isEmpty {
                    emptyState
                } else if showForm, let med = selectedMedicine {
                    prescriptionForm(for: med)
                } else {
                    medicineList
                }
            }
            .navigationTitle(showForm ? "Set Dosage" : "Select Medicine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if showForm {
                        Button("Back") {
                            withAnimation { showForm = false }
                        }
                        .foregroundColor(AppTheme.primary)
                    } else {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            .task { await loadMedicines() }
        }
    }

    // MARK: - Medicine List
    private var medicineList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                // Department context banner
                if let dept = doctorDepartment {
                    HStack(spacing: 8) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.primary)
                        Text("Showing medicines for \(dept)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.primary.opacity(0.06))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                }

                ForEach(filtered) { med in
                    Button {
                        selectedMedicine = med
                        timesPerDay = 1
                        durationDays = 5
                        notes = ""
                        withAnimation { showForm = true }
                    } label: {
                        medicineRow(med)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 30)
        }
        .searchable(text: $searchText, prompt: "Search medicines…")
    }

    private func medicineRow(_ med: InventoryItem) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: med.medicineType?.sfSymbol ?? "pills.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.primary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(med.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                HStack(spacing: 6) {
                    if let type = med.medicineType {
                        Text(type.displayName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.primary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(AppTheme.primary.opacity(0.1))
                            .cornerRadius(5)
                    }
                    Text("\(med.quantity) \(med.unit)s available")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary.opacity(0.4))
        }
        .padding(14)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    // MARK: - Prescription Form
    private func prescriptionForm(for med: InventoryItem) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Medicine header
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primary.opacity(0.12))
                            .frame(width: 56, height: 56)
                        Image(systemName: med.medicineType?.sfSymbol ?? "pills.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppTheme.primary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(med.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        Text(med.medicineType?.displayName ?? "Medicine")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(AppTheme.cardSurface)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)

                // Times per day
                VStack(alignment: .leading, spacing: 10) {
                    Label("Times Per Day", systemImage: "sun.and.horizon.fill")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    HStack(spacing: 12) {
                        ForEach([1, 2, 3, 4], id: \.self) { times in
                            timesButton(times)
                        }
                        Spacer()
                    }
                }
                .padding(16)
                .background(AppTheme.cardSurface)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)

                // Duration
                VStack(alignment: .leading, spacing: 10) {
                    Label("Duration (Days)", systemImage: "calendar")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    HStack(spacing: 16) {
                        Button {
                            if durationDays > 1 { durationDays -= 1 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(AppTheme.warning)
                        }
                        .buttonStyle(.plain)

                        Text("\(durationDays)")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(minWidth: 50)

                        Button {
                            durationDays += 1
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(AppTheme.success)
                        }
                        .buttonStyle(.plain)

                        Text("days")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                    }
                }
                .padding(16)
                .background(AppTheme.cardSurface)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)

                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Label("Instructions (Optional)", systemImage: "text.bubble")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    TextField("e.g. After meals, with water…", text: $notes, axis: .vertical)
                        .font(.system(size: 14, design: .rounded))
                        .padding(10)
                        .background(AppTheme.background)
                        .cornerRadius(10)
                        .lineLimit(2...4)
                }
                .padding(16)
                .background(AppTheme.cardSurface)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)

                // Summary
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total tablets required")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                        Text("\(timesPerDay * durationDays) \(med.unit)s")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.primary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(AppTheme.primary.opacity(0.06))
                .cornerRadius(14)

                // Add button
                Button {
                    let prescribed = PrescribedMedicine(
                        id: UUID().uuidString,
                        medicineId: med.firestoreId,
                        medicineName: med.name,
                        medicineType: med.medicineType ?? .tablet,
                        timesPerDay: timesPerDay,
                        durationDays: durationDays,
                        notes: notes.isEmpty ? nil : notes
                    )
                    onAdd(prescribed)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add to Prescription")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.primary)
                    .cornerRadius(16)
                    .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            .padding(16)
            .padding(.bottom, 30)
        }
    }

    private func timesButton(_ count: Int) -> some View {
        let isSelected = timesPerDay == count
        return Button {
            timesPerDay = count
        } label: {
            VStack(spacing: 4) {
                Text("\(count)x")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(count == 1 ? "Once" : count == 2 ? "Twice" : "\(count) times")
                    .font(.system(size: 10, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : AppTheme.primary)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(isSelected ? AppTheme.primary : AppTheme.primary.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills.fill")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.primary.opacity(0.3))
            Text("No Medicines Available")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            if let dept = doctorDepartment {
                Text("No medicines assigned to \(dept).\nAsk admin to add medicines for your department.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }

    private func loadMedicines() async {
        do {
            let fetched = try await InventoryRepository.shared.fetchMedicines(forDepartment: doctorDepartment)
            await MainActor.run {
                medicines = fetched.sorted { $0.name < $1.name }
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}
