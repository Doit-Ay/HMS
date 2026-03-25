import SwiftUI
import FirebaseFirestore

// MARK: - Inventory Item Model (for non-medicine items)
struct InventoryItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let totalCount: Int
    let availableCount: Int
    let category: InventoryCategory
    let unit: String
    let isLowStock: Bool

    var usedCount: Int { totalCount - availableCount }
    var usagePercent: Double { totalCount > 0 ? Double(usedCount) / Double(totalCount) : 0 }
}

enum InventoryCategory: String, CaseIterable, Identifiable {
    case medicines      = "Medicines"
    case beds           = "Beds"
    case oxygenSupply   = "Oxygen Supply"
    case equipment      = "Equipment"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .medicines:    return "pills.fill"
        case .beds:         return "bed.double.fill"
        case .oxygenSupply: return "aqi.medium"
        case .equipment:    return "cross.case.fill"
        }
    }

    var color: Color {
        switch self {
        case .medicines:    return Color(hex: "#6366F1")
        case .beds:         return Color(hex: "#0EA5E9")
        case .oxygenSupply: return Color(hex: "#10B981")
        case .equipment:    return Color(hex: "#F59E0B")
        }
    }
}

// MARK: - All inventory data
private let allInventoryItems: [InventoryItem] = [
    // Beds
    InventoryItem(name: "General Ward Beds", icon: "bed.double.fill", totalCount: 120, availableCount: 34, category: .beds, unit: "beds", isLowStock: false),
    InventoryItem(name: "ICU Beds", icon: "bed.double.fill", totalCount: 20, availableCount: 3, category: .beds, unit: "beds", isLowStock: true),
    InventoryItem(name: "Private Room Beds", icon: "bed.double.fill", totalCount: 30, availableCount: 12, category: .beds, unit: "beds", isLowStock: false),
    InventoryItem(name: "Emergency Beds", icon: "bed.double.fill", totalCount: 15, availableCount: 5, category: .beds, unit: "beds", isLowStock: false),

    // Oxygen Supply
    InventoryItem(name: "Oxygen Cylinders (Large)", icon: "aqi.medium", totalCount: 50, availableCount: 18, category: .oxygenSupply, unit: "units", isLowStock: false),
    InventoryItem(name: "Oxygen Cylinders (Small)", icon: "aqi.medium", totalCount: 80, availableCount: 12, category: .oxygenSupply, unit: "units", isLowStock: true),
    InventoryItem(name: "Oxygen Concentrators", icon: "aqi.medium", totalCount: 25, availableCount: 10, category: .oxygenSupply, unit: "units", isLowStock: false),
    InventoryItem(name: "Nasal Cannulas", icon: "aqi.medium", totalCount: 200, availableCount: 85, category: .oxygenSupply, unit: "pieces", isLowStock: false),

    // Equipment
    InventoryItem(name: "Ventilators", icon: "waveform.path.ecg", totalCount: 15, availableCount: 4, category: .equipment, unit: "units", isLowStock: true),
    InventoryItem(name: "Patient Monitors", icon: "waveform.path.ecg.rectangle", totalCount: 40, availableCount: 15, category: .equipment, unit: "units", isLowStock: false),
    InventoryItem(name: "Wheelchairs", icon: "figure.roll", totalCount: 30, availableCount: 22, category: .equipment, unit: "units", isLowStock: false),
    InventoryItem(name: "Defibrillators", icon: "bolt.heart.fill", totalCount: 10, availableCount: 8, category: .equipment, unit: "units", isLowStock: false),
    InventoryItem(name: "Infusion Pumps", icon: "ivfluid.bag.fill", totalCount: 35, availableCount: 6, category: .equipment, unit: "units", isLowStock: true),
]

// Local, unambiguous model used by Inventory screens to avoid type name clashes
struct InventoryMedicine: Identifiable, Codable {
    var id: String = ""
    var name: String
    var uses: String
    var type: String
    var strengths: String
    var category: String
    var quantity: Int

    enum CodingKeys: String, CodingKey {
        case id, name, uses, type, strengths, category, quantity
    }

    init(name: String, uses: String = "", type: String = "", strengths: String = "", category: String = "", quantity: Int = 0) {
        self.name = name
        self.uses = uses
        self.type = type
        self.strengths = strengths
        self.category = category
        self.quantity = quantity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? ""
        self.name = (try? c.decode(String.self, forKey: .name)) ?? "Unknown"
        self.uses = (try? c.decode(String.self, forKey: .uses)) ?? ""
        self.type = (try? c.decode(String.self, forKey: .type)) ?? ""
        self.strengths = (try? c.decode(String.self, forKey: .strengths)) ?? ""
        self.category = (try? c.decode(String.self, forKey: .category)) ?? "Uncategorized"
        self.quantity = (try? c.decode(Int.self, forKey: .quantity)) ?? 0
    }
}

// MARK: - Inventory Management View
struct InventoryManagementView: View {
    @State private var animate = false
    @State private var medicineCount: Int = 0
    @State private var medicineLowStock: Int = 0

    private var lowStockCount: Int {
        allInventoryItems.filter { $0.isLowStock }.count + medicineLowStock
    }

    private var totalItems: Int {
        allInventoryItems.count + medicineCount
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        summaryHeroCard
                            .offset(y: animate ? 0 : -20)
                            .opacity(animate ? 1 : 0)

                        categoryStatsGrid
                            .offset(y: animate ? 0 : 20)
                            .opacity(animate ? 1 : 0)
                    }
                    .padding(.vertical, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: InventoryCategory.self) { category in
                if category == .medicines {
                    MedicineListView()
                } else {
                    InventoryCategoryDetailView(category: category)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    animate = true
                }
            }
            .task {
                await fetchMedicineSummary()
            }
        }
    }

    // MARK: - Summary Hero Card
    private var summaryHeroCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hospital Inventory")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    Text("\(totalItems) Items Tracked")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 64, height: 64)
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                }
            }

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#FCD34D"))
                    Text("\(lowStockCount) Low Stock")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15))
                .cornerRadius(20)

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#34D399"))
                    Text("\(totalItems - lowStockCount) Adequate")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15))
                .cornerRadius(20)

                Spacer()
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [AppTheme.dashboardCardGradientStart, AppTheme.dashboardCardGradientEnd],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }

    // MARK: - Category Stats Grid
    private var categoryStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(InventoryCategory.allCases) { cat in
                NavigationLink(value: cat) {
                    categoryCard(for: cat)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func categoryCard(for cat: InventoryCategory) -> some View {
        if cat == .medicines {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(cat.color.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: cat.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(cat.color)
                    }
                    Spacer()
                    if medicineLowStock > 0 {
                        Text("\(medicineLowStock) low")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.warning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.warning.opacity(0.12))
                            .cornerRadius(8)
                    }
                }

                Text(cat.rawValue)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 4) {
                    Text("\(medicineCount)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(cat.color)
                    Text("items")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }

                HStack(spacing: 4) {
                    Text("View All")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(cat.color.opacity(0.7))
            }
            .padding(16)
            .background(AppTheme.cardSurface)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        } else {
            let catItems = allInventoryItems.filter { $0.category == cat }
            let totalAvailable = catItems.reduce(0) { $0 + $1.availableCount }
            let totalAll = catItems.reduce(0) { $0 + $1.totalCount }
            let lowCount = catItems.filter { $0.isLowStock }.count

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(cat.color.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: cat.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(cat.color)
                    }
                    Spacer()
                    if lowCount > 0 {
                        Text("\(lowCount) low")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.warning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.warning.opacity(0.12))
                            .cornerRadius(8)
                    }
                }

                Text(cat.rawValue)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 4) {
                    Text("\(totalAvailable)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(cat.color)
                    Text("/ \(totalAll)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(cat.color.opacity(0.12))
                            .frame(height: 6)
                        Capsule()
                            .fill(cat.color)
                            .frame(width: totalAll > 0 ? geo.size.width * CGFloat(totalAll - totalAvailable) / CGFloat(totalAll) : 0, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(16)
            .background(AppTheme.cardSurface)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        }
    }

    // MARK: - Fetch Medicine Summary
    private func fetchMedicineSummary() async {
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("medicines").getDocuments()
            let count = snapshot.documents.count
            let lowCount = snapshot.documents.filter { doc in
                (doc.data()["quantity"] as? Int ?? 0) < 50
            }.count
            await MainActor.run {
                medicineCount = count
                medicineLowStock = lowCount
            }
        } catch {
            print("Error fetching medicine summary: \(error)")
        }
    }
}

// MARK: - Inventory Category Detail View (Beds, Oxygen, Equipment)
struct InventoryCategoryDetailView: View {
    let category: InventoryCategory

    private var items: [InventoryItem] {
        allInventoryItems.filter { $0.category == category }
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Summary bar
                    let totalAvailable = items.reduce(0) { $0 + $1.availableCount }
                    let totalAll = items.reduce(0) { $0 + $1.totalCount }
                    let lowCount = items.filter { $0.isLowStock }.count

                    HStack(spacing: 12) {
                        Label("\(items.count) items", systemImage: category.icon)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(category.color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(category.color.opacity(0.1))
                            .cornerRadius(16)

                        Label("\(totalAvailable)/\(totalAll) available", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.success)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AppTheme.success.opacity(0.1))
                            .cornerRadius(16)

                        if lowCount > 0 {
                            Label("\(lowCount) low", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(AppTheme.warning)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(AppTheme.warning.opacity(0.1))
                                .cornerRadius(16)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    // Items list
                    LazyVStack(spacing: 10) {
                        ForEach(items) { item in
                            InventoryItemRow(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Medicine List View (Firestore)
struct MedicineListView: View {
    @State private var medicines: [InventoryMedicine] = []
    @State private var isLoading = true
    @State private var selectedCategory: String? = nil
    @State private var searchText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var editingMedicine: InventoryMedicine? = nil
    @State private var showEditSheet = false

    private let lowStockThreshold = 50

    private var categories: [String] {
        Array(Set(medicines.map { $0.category })).sorted()
    }

    private var filteredMedicines: [InventoryMedicine] {
        var items = medicines
        if let cat = selectedCategory {
            items = items.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText) ||
                $0.uses.localizedCaseInsensitiveContains(searchText)
            }
        }
        return items.sorted { $0.name < $1.name }
    }

    private func colorForCategory(_ cat: String) -> Color {
        let colors: [Color] = [
            Color(hex: "#6366F1"), Color(hex: "#0EA5E9"), Color(hex: "#10B981"),
            Color(hex: "#F59E0B"), Color(hex: "#EF4444"), Color(hex: "#8B5CF6"),
            Color(hex: "#EC4899"), Color(hex: "#14B8A6"), Color(hex: "#F97316"),
            Color(hex: "#06B6D4"), Color(hex: "#84CC16"), Color(hex: "#A855F7"),
        ]
        let index = abs(cat.hashValue) % colors.count
        return colors[index]
    }

    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "tablets", "sublingual tablets":  return "pill.fill"
        case "capsules":                       return "capsule.fill"
        case "injection":                      return "syringe.fill"
        case "inhalation":                     return "wind"
        case "powder":                         return "flask.fill"
        case "eye drops":                      return "drop.fill"
        case "suppository":                    return "circle.bottomhalf.filled"
        default:                               return "cross.vial.fill"
        }
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.3)
                    Text("Loading Medicines…")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Summary badges
                        HStack(spacing: 12) {
                            Label("\(medicines.count) medicines", systemImage: "pills.fill")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: "#6366F1"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color(hex: "#6366F1").opacity(0.1))
                                .cornerRadius(16)

                            let low = medicines.filter { $0.quantity < lowStockThreshold }.count
                            if low > 0 {
                                Label("\(low) low stock", systemImage: "exclamationmark.triangle.fill")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.warning)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(AppTheme.warning.opacity(0.1))
                                    .cornerRadius(16)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)



                        // Medicine list
                        LazyVStack(spacing: 10) {
                            ForEach(filteredMedicines) { med in
                                MedicineRow(
                                    medicine: med,
                                    categoryColor: colorForCategory(med.category),
                                    typeIcon: iconForType(med.type),
                                    isLowStock: med.quantity < lowStockThreshold
                                )
                                .onTapGesture {
                                    editingMedicine = med
                                    showEditSheet = true
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 12)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Medicines")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search medicines…")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        withAnimation { selectedCategory = nil }
                    } label: {
                        Label("All Categories", systemImage: selectedCategory == nil ? "checkmark" : "square.grid.2x2")
                    }
                    Divider()
                    ForEach(categories, id: \.self) { cat in
                        Button {
                            withAnimation { selectedCategory = selectedCategory == cat ? nil : cat }
                        } label: {
                            Label(cat, systemImage: selectedCategory == cat ? "checkmark" : "pills")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle\(selectedCategory != nil ? ".fill" : "")")
                            .font(.system(size: 16, weight: .semibold))
                        if let cat = selectedCategory {
                            Text(cat)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(AppTheme.primary)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            await fetchMedicines()
        }
        .sheet(isPresented: $showEditSheet) {
            if let medicine = editingMedicine {
                MedicineEditSheet(medicine: medicine) { updated in
                    Task {
                        await saveMedicine(updated)
                        await fetchMedicines()
                    }
                }
            }
        }
    }

    private func fetchMedicines() async {
        isLoading = true
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("medicines").getDocuments()
            let fetched: [InventoryMedicine] = snapshot.documents.compactMap { doc in
                do {
                    var medicine = try Firestore.Decoder().decode(InventoryMedicine.self, from: doc.data())
                    medicine.id = doc.documentID
                    return medicine
                } catch {
                    print("Error decoding medicine \(doc.documentID): \(error)")
                    return nil
                }
            }
            await MainActor.run {
                medicines = fetched
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

    private func saveMedicine(_ medicine: InventoryMedicine) async {
        do {
            let db = Firestore.firestore()
            try await db.collection("medicines").document(medicine.id).updateData([
                "name": medicine.name,
                "uses": medicine.uses,
                "type": medicine.type,
                "strengths": medicine.strengths,
                "category": medicine.category,
                "quantity": medicine.quantity
            ])
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Medicine Edit Sheet
struct MedicineEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var uses: String
    @State private var type: String
    @State private var strengths: String
    @State private var category: String
    @State private var quantity: Int
    @State private var isSaving = false

    private let medicineId: String
    private let onSave: (InventoryMedicine) -> Void

    private let typeOptions = ["Tablets", "Capsules", "Injection", "Inhalation", "Powder", "Eye drops", "Suppository", "Sublingual Tablets"]

    init(medicine: InventoryMedicine, onSave: @escaping (InventoryMedicine) -> Void) {
        self.medicineId = medicine.id
        self._name = State(initialValue: medicine.name)
        self._uses = State(initialValue: medicine.uses)
        self._type = State(initialValue: medicine.type)
        self._strengths = State(initialValue: medicine.strengths)
        self._category = State(initialValue: medicine.category)
        self._quantity = State(initialValue: medicine.quantity)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#6366F1").opacity(0.12))
                                .frame(width: 50, height: 50)
                            Image(systemName: "pills.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color(hex: "#6366F1"))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name.isEmpty ? "Medicine" : name)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                            Text(category)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section(header: Text("Basic Info")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                        TextField("Medicine name", text: $name)
                            .font(.system(size: 15, design: .rounded))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Uses")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                        TextField("Usage description", text: $uses, axis: .vertical)
                            .font(.system(size: 15, design: .rounded))
                            .lineLimit(2...4)
                    }
                }

                Section(header: Text("Classification")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                        Picker("Type", selection: $type) {
                            ForEach(typeOptions, id: \.self) { t in
                                Text(t).tag(t)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                        TextField("Category", text: $category)
                            .font(.system(size: 15, design: .rounded))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Strengths")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                        TextField("e.g. 500 mg, 250 mg", text: $strengths)
                            .font(.system(size: 15, design: .rounded))
                    }
                }

                Section(header: Text("Stock")) {
                    HStack {
                        Text("Quantity")
                            .font(.system(size: 15, design: .rounded))
                        Spacer()
                        HStack(spacing: 16) {
                            Button {
                                if quantity > 0 { quantity -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.warning)
                            }
                            .buttonStyle(.plain)

                            Text("\(quantity)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(quantity < 50 ? AppTheme.warning : AppTheme.textPrimary)
                                .frame(minWidth: 40)

                            Button {
                                quantity += 1
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.success)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if quantity < 50 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text("Low stock warning")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(AppTheme.warning)
                    }
                }
            }
            .navigationTitle("Edit Medicine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isSaving = true
                        var updated = InventoryMedicine(
                            name: name,
                            uses: uses,
                            type: type,
                            strengths: strengths,
                            category: category,
                            quantity: quantity
                        )
                        updated.id = medicineId
                        onSave(updated)
                        dismiss()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Medicine Row
struct MedicineRow: View {
    let medicine: InventoryMedicine
    let categoryColor: Color
    let typeIcon: String
    let isLowStock: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: typeIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(categoryColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(medicine.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(isLowStock ? "Low Stock" : "Adequate")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(isLowStock ? AppTheme.warning : AppTheme.success)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background((isLowStock ? AppTheme.warning : AppTheme.success).opacity(0.12))
                            .cornerRadius(6)

                        Text(medicine.type)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(categoryColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(categoryColor.opacity(0.1))
                            .cornerRadius(6)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(medicine.quantity)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(isLowStock ? AppTheme.warning : AppTheme.textPrimary)
                    Text("in stock")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.textSecondary)
                    Text(medicine.strengths)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(medicine.category)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(categoryColor.opacity(0.8))
            }

            Text(medicine.uses)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(2)
        }
        .padding(14)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Category Filter Chip
struct CategoryFilterChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                isSelected
                    ? AnyShapeStyle(color)
                    : AnyShapeStyle(color.opacity(0.1))
            )
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inventory Item Row
struct InventoryItemRow: View {
    let item: InventoryItem

    private var statusColor: Color {
        if item.isLowStock { return AppTheme.warning }
        if item.usagePercent > 0.7 { return Color(hex: "#F97316") }
        return AppTheme.success
    }

    private var statusText: String {
        if item.isLowStock { return "Low Stock" }
        if item.usagePercent > 0.7 { return "Moderate" }
        return "Adequate"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(item.category.color.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(item.category.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(statusText)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.12))
                        .cornerRadius(6)

                    Text(item.category.rawValue)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 2) {
                    Text("\(item.availableCount)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(item.isLowStock ? AppTheme.warning : AppTheme.textPrimary)
                    Text("/ \(item.totalCount)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
                Text(item.unit)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(14)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    InventoryManagementView()
}
