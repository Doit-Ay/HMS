import SwiftUI
import FirebaseFirestore

// MARK: - Inventory Management View (Root)
struct InventoryManagementView: View {
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segmented Picker
                    Picker("Category", selection: $selectedTab) {
                        Text("Beds").tag(0)
                        Text("Medicines").tag(1)
                        Text("Additionals").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    // Conditional rendering (no TabView page-style swipe conflicts)
                    Group {
                        switch selectedTab {
                        case 0: InventoryCategoryListView(category: .beds)
                        case 1: InventoryCategoryListView(category: .medicines)
                        case 2: InventoryCategoryListView(category: .additionals)
                        default: EmptyView()
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
                    
                    // Super Prominent AI Planner Button
                    NavigationLink {
                        InventoryAIPlannerView()
                            .navigationTitle("AI Planner")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .bold))
                            Text("AI Inventory Planner")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.primary, AppTheme.primary.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: AppTheme.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppTheme.background.ignoresSafeArea(edges: .bottom))
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
    @State private var showError = false
    @State private var animate = false

    private var filtered: [InventoryItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var lowStockCount: Int { items.filter { $0.quantity < 10 }.count }
    private var totalValue: Double { items.reduce(0) { $0 + (Double($1.quantity) * $1.unitPrice) } }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.1)
                        .tint(AppTheme.primary)
                    Text("Loading \(category.displayName)…")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            } else if items.isEmpty {
                inventoryEmptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Dashboard Stat Cards
                        statCardsSection
                            .offset(y: animate ? 0 : 15)
                            .opacity(animate ? 1 : 0)

                        // Items List
                        VStack(spacing: 10) {
                            ForEach(filtered) { item in
                                InventoryItemRow(item: item)
                                    .onTapGesture { editingItem = item }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            Task { await deleteItem(item) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .offset(y: animate ? 0 : 20)
                        .opacity(animate ? 1 : 0)
                    }
                    .padding(.vertical, 12)
                    .padding(.bottom, 30)
                }
                .refreshable { await loadItems() }
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
        .sheet(isPresented: $showAddSheet, onDismiss: { Task { await loadItems() } }) {
            InventoryItemFormSheet(category: category, editingItem: nil) { _ in }
        }
        .sheet(item: $editingItem, onDismiss: { Task { await loadItems() } }) { item in
            InventoryItemFormSheet(category: category, editingItem: item) { _ in }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
        .task {
            await loadItems()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animate = true
            }
        }
    }

    // MARK: - Stat Cards
    private var statCardsSection: some View {
        HStack(spacing: 10) {
            InventoryStatCard(
                icon: "shippingbox.fill",
                title: "Total",
                value: "\(items.count)",
                color: AppTheme.primary
            )

            InventoryStatCard(
                icon: "exclamationmark.triangle.fill",
                title: "Low Stock",
                value: "\(lowStockCount)",
                color: lowStockCount > 0 ? AppTheme.warning : AppTheme.success
            )
        }
        .padding(.horizontal, 16)
    }

    private func formatCurrency(_ value: Double) -> String {
        if value >= 100000 {
            return "₹\(String(format: "%.1f", value / 100000))L"
        } else if value >= 1000 {
            return "₹\(String(format: "%.1f", value / 1000))K"
        } else {
            return "₹\(String(format: "%.0f", value))"
        }
    }

    // MARK: - Empty State
    private var inventoryEmptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.08))
                    .frame(width: 100, height: 100)
                Image(systemName: category.sfSymbol)
                    .font(.system(size: 40))
                    .foregroundColor(AppTheme.primary.opacity(0.4))
            }
            Text("No \(category.displayName) Added")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            Text("Tap + to add your first item")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
        }
    }

    // MARK: - Data
    private func loadItems() async {
        do {
            let fetched = try await InventoryRepository.shared.fetchInventory(category: category)
            await MainActor.run {
                items = fetched.sorted { $0.name < $1.name }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }

    private func deleteItem(_ item: InventoryItem) async {
        guard let id = item.id else { return }
        do {
            try await InventoryRepository.shared.deleteInventoryItem(id: id)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    items.removeAll { $0.id == id }
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Stat Card
struct InventoryStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
            }

            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Inventory Item Row
struct InventoryItemRow: View {
    let item: InventoryItem

    private var isLowStock: Bool { item.quantity < 10 }
    private var stockColor: Color {
        if item.quantity == 0 { return .red }
        if isLowStock { return AppTheme.warning }
        return AppTheme.success
    }
    private var stockLabel: String {
        if item.quantity == 0 { return "Out" }
        if isLowStock { return "Low" }
        return "OK"
    }

    var body: some View {
        HStack(spacing: 14) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: iconForItem)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if item.category == .medicines, let type = item.medicineType {
                        Text(type.displayName)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(AppTheme.primary.opacity(0.8))
                            .cornerRadius(6)
                    }
                    if let dept = item.department, !dept.isEmpty {
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

            // Stock indicator
            Text("\(item.quantity)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(stockColor)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary.opacity(0.3))
        }
        .padding(14)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    private var iconForItem: String {
        switch item.category {
        case .beds:        return "bed.double.fill"
        case .medicines:   return item.medicineType?.sfSymbol ?? "pills.fill"
        case .additionals: return "cross.case.fill"
        }
    }

    private var iconColor: Color {
        switch item.category {
        case .beds:        return Color(hex: "#8B5CF6")
        case .medicines:   return AppTheme.primary
        case .additionals: return Color(hex: "#F59E0B")
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
