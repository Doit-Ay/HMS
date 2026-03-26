import SwiftUI
import FirebaseFirestore

// MARK: - Inventory Management View (Root)
struct InventoryManagementView: View {
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab Picker
                    Picker("Category", selection: $selectedTab) {
                        Text("Beds").tag(0)
                        Text("Medicines").tag(1)
                        Text("Additionals").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    TabView(selection: $selectedTab) {
                        InventoryCategoryListView(category: .beds).tag(0)
                        InventoryCategoryListView(category: .medicines).tag(1)
                        InventoryCategoryListView(category: .additionals).tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
                }
            }
            .navigationTitle("Inventory")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Category List View
struct InventoryCategoryListView: View {
    let category: InventoryCategory
    @State private var items: [InventoryItem] = []
    @State private var isLoading = true
    @State private var showAddSheet = false
    @State private var editingItem: InventoryItem? = nil
    @State private var searchText = ""
    @State private var errorMessage: String? = nil

    private var filtered: [InventoryItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var lowStockCount: Int { items.filter { $0.quantity < 10 }.count }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            if isLoading {
                ProgressView("Loading \(category.displayName)…")
                    .tint(AppTheme.primary)
            } else if items.isEmpty {
                inventoryEmptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        summaryBar
                        LazyVStack(spacing: 10) {
                            ForEach(filtered) { item in
                                InventoryItemRow(item: item)
                                    .onTapGesture { editingItem = item }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 12)
                    .padding(.bottom, 30)
                }
                .searchable(text: $searchText, prompt: "Search \(category.displayName)…")
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            InventoryItemFormSheet(category: category, editingItem: nil) { _ in
                Task { await loadItems() }
            }
        }
        .sheet(item: $editingItem) { item in
            InventoryItemFormSheet(category: category, editingItem: item) { _ in
                Task { await loadItems() }
            }
        }
        .task { await loadItems() }
    }

    // MARK: - Summary Bar
    private var summaryBar: some View {
        HStack(spacing: 10) {
            Label("\(items.count) items", systemImage: category.sfSymbol)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.primary)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(AppTheme.primary.opacity(0.1))
                .cornerRadius(16)

            if lowStockCount > 0 {
                Label("\(lowStockCount) low stock", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.warning)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(AppTheme.warning.opacity(0.1))
                    .cornerRadius(16)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var inventoryEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: category.sfSymbol)
                .font(.system(size: 48))
                .foregroundColor(AppTheme.primary.opacity(0.3))
            Text("No \(category.displayName) Added")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            Text("Tap + to add your first item")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
        }
    }

    private func loadItems() async {
        isLoading = true
        do {
            let fetched = try await InventoryRepository.shared.fetchInventory(category: category)
            await MainActor.run {
                items = fetched.sorted { $0.name < $1.name }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Inventory Item Row
struct InventoryItemRow: View {
    let item: InventoryItem
    private var isLowStock: Bool { item.quantity < 10 }
    private var stockColor: Color { isLowStock ? AppTheme.warning : AppTheme.success }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: iconForItem)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                HStack(spacing: 6) {
                    if item.category == .medicines, let type = item.medicineType {
                        Text(type.displayName)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.primary)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(AppTheme.primary.opacity(0.1))
                            .cornerRadius(6)
                    }
                    if let dept = item.department {
                        Text(dept)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Text("₹\(String(format: "%.0f", item.unitPrice))/\(item.unit)")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.quantity)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(stockColor)
                Text(item.unit)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                if isLowStock {
                    Text("Low")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppTheme.warning)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(AppTheme.warning.opacity(0.15))
                        .cornerRadius(4)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary.opacity(0.4))
        }
        .padding(14)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    private var iconForItem: String {
        switch item.category {
        case .beds:        return "bed.double.fill"
        case .medicines:   return item.medicineType?.sfSymbol ?? "pills.fill"
        case .additionals: return "cross.case.fill"
        }
    }
}

// MARK: - Inventory Item Form Sheet (Add / Edit)
struct InventoryItemFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: InventoryCategory
    let editingItem: InventoryItem?
    let onSave: (InventoryItem) -> Void

    // Fields
    @State private var name: String = ""
    @State private var medicineType: MedicineType = .tablet
    @State private var department: String = ""
    @State private var quantity: Int = 0
    @State private var unitPrice: Double = 0
    @State private var unit: String = ""
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String? = nil

    private let departments = ["Cardiology", "Neurology", "Orthopedics", "Dermatology",
                                "Pediatrics", "General Medicine", "Oncology", "Radiology",
                                "Psychiatry", "ENT", "Ophthalmology", "Gynecology"]

    private let additionalUnits = ["bag", "unit", "cylinder", "bottle", "pack"]
    private let bedUnits = ["bed"]
    private let medicineUnits = ["tablet", "ml", "capsule", "mg"]

    private var isEditing: Bool { editingItem != nil }
    private var title: String { isEditing ? "Edit \(category.displayName)" : "Add \(category.displayName)" }

    var body: some View {
        NavigationStack {
            Form {
                // Name
                Section(header: Text("Item Name")) {
                    TextField("e.g. ICU Bed, Paracetamol, Saline Bag", text: $name)
                }

                // Medicine-specific fields
                if category == .medicines {
                    Section(header: Text("Medicine Details")) {
                        Picker("Type", selection: $medicineType) {
                            ForEach(MedicineType.allCases, id: \.self) { t in
                                Label(t.displayName, systemImage: t.sfSymbol).tag(t)
                            }
                        }
                        Picker("Department", selection: $department) {
                            Text("All Departments").tag("")
                            ForEach(departments, id: \.self) { d in
                                Text(d).tag(d)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }

                // Stock
                Section(header: Text("Stock & Pricing")) {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        HStack(spacing: 16) {
                            Button { if quantity > 0 { quantity -= 1 } } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(AppTheme.warning)
                            }
                            .buttonStyle(.plain)
                            Text("\(quantity)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .frame(minWidth: 36)
                            Button { quantity += 1 } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(AppTheme.success)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        Text("Unit Price (₹)")
                        Spacer()
                        TextField("0.00", value: $unitPrice, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    Picker("Unit", selection: $unit) {
                        ForEach(unitOptions, id: \.self) { u in Text(u).tag(u) }
                    }
                    .pickerStyle(.menu)
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red).font(.system(size: 13))
                    }
                }

                // Delete (edit mode only)
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete Item", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSaving ? "" : "Save") {
                        Task { await saveItem() }
                    }
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.primary)
                    .disabled(name.isEmpty || unit.isEmpty || isSaving)
                    .overlay { if isSaving { ProgressView().tint(AppTheme.primary) } }
                }
            }
            .confirmationDialog("Delete this item?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task { await deleteItem() }
                }
            }
            .onAppear { prefill() }
        }
    }

    private var unitOptions: [String] {
        switch category {
        case .beds:        return bedUnits
        case .medicines:   return medicineUnits
        case .additionals: return additionalUnits
        }
    }

    private func prefill() {
        guard let item = editingItem else {
            // Sensible defaults
            switch category {
            case .beds:        unit = "bed"
            case .medicines:   unit = "tablet"
            case .additionals: unit = "unit"
            }
            return
        }
        name = item.name
        medicineType = item.medicineType ?? .tablet
        department = item.department ?? ""
        quantity = item.quantity
        unitPrice = item.unitPrice
        unit = item.unit
    }

    private func saveItem() async {
        isSaving = true
        errorMessage = nil
        let item = InventoryItem(
            id: editingItem?.id,
            name: name,
            category: category,
            medicineType: category == .medicines ? medicineType : nil,
            department: category == .medicines && !department.isEmpty ? department : nil,
            quantity: quantity,
            unitPrice: unitPrice,
            unit: unit,
            isActive: true,
            createdAt: editingItem?.createdAt ?? Date(),
            updatedAt: Date()
        )
        do {
            if isEditing {
                try await InventoryRepository.shared.updateInventoryItem(item)
            } else {
                try await InventoryRepository.shared.addInventoryItem(item)
            }
            await MainActor.run {
                onSave(item)
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    private func deleteItem() async {
        guard let id = editingItem?.id else { return }
        do {
            try await InventoryRepository.shared.deleteInventoryItem(id: id)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}
