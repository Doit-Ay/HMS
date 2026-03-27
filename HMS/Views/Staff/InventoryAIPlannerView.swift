import SwiftUI

struct InventoryAIPlannerView: View {
    @State private var insights: GroqInventoryResponse?
    @State private var allItems: [InventoryItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedSection: PlannerSection = .overview
    @State private var expandedInsightId: String?
    
    // NEW: Improvements
    @State private var animate = false
    @State private var healthRingProgress: CGFloat = 0
    @State private var analyzedAt: Date?
    @State private var searchText = ""
    @State private var activeFilter: StatusFilter = .all
    @State private var expandAll = false
    @State private var isLocalFallback = false
    
    enum PlannerSection: String, CaseIterable {
        case overview = "Overview"
        case items = "All Items"
        case risks = "Risks"
        case plan = "Action Plan"
    }
    
    enum StatusFilter: String, CaseIterable {
        case all = "All"
        case critical = "Critical"
        case low = "Low"
        case overstock = "Overstock"
        case healthy = "Healthy"
    }
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let data = insights {
                VStack(spacing: 0) {
                    // Section Picker
                    sectionPicker
                    
                    // Analyzed timestamp
                    if let time = analyzedAt {
                        HStack(spacing: 5) {
                            Image(systemName: isLocalFallback ? "cpu" : "sparkles")
                                .font(.system(size: 10, weight: .semibold))
                            Text(isLocalFallback
                                 ? "Local analysis at \(time.formatted(date: .omitted, time: .shortened))"
                                 : "AI analyzed at \(time.formatted(date: .omitted, time: .shortened))")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(isLocalFallback ? AppTheme.warning.opacity(0.8) : AppTheme.textSecondary.opacity(0.6))
                        .padding(.bottom, 6)
                    }
                    
                    // Content
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            switch selectedSection {
                            case .overview:  overviewSection(data)
                            case .items:     allItemsSection(data)
                            case .risks:     risksSection(data)
                            case .plan:      actionPlanSection(data)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .padding(.bottom, 30)
                    }
                    .refreshable {
                        await refreshAnalysis()
                    }
                }
            }
        }
        .navigationTitle("AI Planner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isLoading = true
                    errorMessage = nil
                    animate = false
                    healthRingProgress = 0
                    isLocalFallback = false
                    Task { await fetchAndAnalyze() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.primary)
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                }
                .disabled(isLoading)
            }
        }
        .task { await fetchAndAnalyze() }
    }
    
    // MARK: - Section Picker
    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PlannerSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedSection = section }
                    } label: {
                        Text(section.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(
                                selectedSection == section
                                ? AnyShapeStyle(LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDark], startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(AppTheme.cardSurface)
                            )
                            .foregroundColor(selectedSection == section ? .white : AppTheme.textSecondary)
                            .cornerRadius(20)
                            .shadow(color: selectedSection == section ? AppTheme.primary.opacity(0.25) : .clear, radius: 6, x: 0, y: 3)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
    
    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(AppTheme.primary.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                ProgressView().scaleEffect(1.5).tint(AppTheme.primary)
            }
            Text("AI is analyzing your inventory...")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
            Text("Evaluating stock levels, costs & risks")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(AppTheme.textSecondary.opacity(0.6))
        }
    }
    
    // MARK: - Error
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40)).foregroundColor(AppTheme.warning)
            Text("Analysis Failed").font(.headline).foregroundColor(AppTheme.textPrimary)
            Text(error)
                .font(.subheadline).foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 30)
            Button("Retry") {
                isLoading = true; errorMessage = nil
                Task { await fetchAndAnalyze() }
            }
            .padding(.horizontal, 24).padding(.vertical, 10)
            .background(AppTheme.primary).foregroundColor(.white)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .cornerRadius(12)
        }
    }
    
    // MARK: - 1. Overview Section
    private func overviewSection(_ data: GroqInventoryResponse) -> some View {
        VStack(spacing: 16) {
            // Health Score Ring (animated)
            healthScoreCard(data)
                .offset(y: animate ? 0 : 20)
                .opacity(animate ? 1 : 0)
            
            // Cost Card
            costCard(data)
                .offset(y: animate ? 0 : 25)
                .opacity(animate ? 1 : 0)
            
            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                PlannerStatCard(title: "Total Items", value: "\(allItems.count)", icon: "shippingbox.fill", color: AppTheme.primary)
                PlannerStatCard(title: "Urgent Restock", value: "\(data.highPriorityRestockCount)", icon: "exclamationmark.circle.fill", color: .red)
                PlannerStatCard(title: "Healthy Items", value: "\(data.healthyStockCount)", icon: "checkmark.shield.fill", color: AppTheme.primary)
                PlannerStatCard(title: "Health Score", value: "\(data.overallHealthScore)%", icon: "heart.fill", color: data.overallHealthScore > 70 ? AppTheme.primary : data.overallHealthScore > 40 ? AppTheme.warning : .red)
            }
            .offset(y: animate ? 0 : 30)
            .opacity(animate ? 1 : 0)
            
            // AI Summary
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").foregroundColor(AppTheme.primary)
                    Text("AI Summary").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(AppTheme.textPrimary)
                }
                Text(data.summary)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineSpacing(4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardSurface)
            .cornerRadius(16)
            .offset(y: animate ? 0 : 35)
            .opacity(animate ? 1 : 0)
            
            // Category Breakdown
            if !data.categoryBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Category Breakdown")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    ForEach(data.categoryBreakdown) { cat in
                        categoryRow(cat)
                    }
                }
                .padding(18)
                .background(AppTheme.cardSurface)
                .cornerRadius(16)
                .offset(y: animate ? 0 : 40)
                .opacity(animate ? 1 : 0)
            }
        }
    }
    
    private func healthScoreCard(_ data: GroqInventoryResponse) -> some View {
        let scoreColor: Color = data.overallHealthScore > 70 ? AppTheme.primary : data.overallHealthScore > 40 ? AppTheme.warning : .red
        return HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.15), lineWidth: 10)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: healthRingProgress)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(healthRingProgress * 100))")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Inventory Health")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Text(data.overallHealthScore > 70 ? "Your inventory is in great shape" : data.overallHealthScore > 40 ? "Some items need attention" : "Critical — immediate action required")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(20)
        .background(AppTheme.cardSurface)
        .cornerRadius(18)
    }
    
    private func costCard(_ data: GroqInventoryResponse) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Predicted Restock Cost")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                Text(formatCurrency(data.totalEstimatedRestockCost))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text("\(data.actionableInsights.filter { $0.recommendedOrder > 0 }.count) items need restocking")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            ZStack {
                Circle().fill(Color.white.opacity(0.2)).frame(width: 52, height: 52)
                Image(systemName: "cart.fill.badge.plus").font(.system(size: 22)).foregroundColor(.white)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [AppTheme.dashboardCardGradientStart, AppTheme.dashboardCardGradientEnd],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(18)
        .shadow(color: AppTheme.primary.opacity(0.25), radius: 10, x: 0, y: 5)
    }
    
    private func categoryRow(_ cat: GroqCategoryBreakdown) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: cat.categoryName == "beds" ? "bed.double.fill" : cat.categoryName == "medicines" ? "pills.fill" : "cross.case.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.primary)
                Text(cat.categoryName.capitalized)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("\(cat.totalItems) items")
                    .font(.system(size: 12, design: .rounded)).foregroundColor(AppTheme.textSecondary)
            }
            
            // Mini bar
            HStack(spacing: 4) {
                if cat.criticalCount > 0 {
                    miniTag("\(cat.criticalCount) Critical", .red)
                }
                if cat.lowStockCount > 0 {
                    miniTag("\(cat.lowStockCount) Low", AppTheme.warning)
                }
                if cat.overstockCount > 0 {
                    miniTag("\(cat.overstockCount) Overstock", .orange)
                }
                miniTag("\(cat.healthyCount) OK", AppTheme.primary)
                Spacer()
            }
            
            // Stock bar
            GeometryReader { geo in
                let total = max(cat.totalItems, 1)
                HStack(spacing: 0) {
                    if cat.criticalCount > 0 {
                        Rectangle().fill(Color.red)
                            .frame(width: geo.size.width * CGFloat(cat.criticalCount) / CGFloat(total))
                    }
                    if cat.lowStockCount > 0 {
                        Rectangle().fill(AppTheme.warning)
                            .frame(width: geo.size.width * CGFloat(cat.lowStockCount) / CGFloat(total))
                    }
                    if cat.overstockCount > 0 {
                        Rectangle().fill(Color.orange)
                            .frame(width: geo.size.width * CGFloat(cat.overstockCount) / CGFloat(total))
                    }
                    Rectangle().fill(AppTheme.primary)
                }
            }
            .frame(height: 6)
            .cornerRadius(3)
        }
        .padding(14)
        .background(AppTheme.background)
        .cornerRadius(14)
    }
    
    private func miniTag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .cornerRadius(6)
    }
    
    // MARK: - 2. All Items Section
    private func allItemsSection(_ data: GroqInventoryResponse) -> some View {
        let sortedInsights = data.actionableInsights.sorted { urgencyRank($0.urgency) < urgencyRank($1.urgency) }
        let filteredInsights = sortedInsights.filter { insight in
            let matchesSearch = searchText.isEmpty || insight.itemName.localizedCaseInsensitiveContains(searchText) || insight.category.localizedCaseInsensitiveContains(searchText)
            let matchesFilter: Bool
            switch activeFilter {
            case .all: matchesFilter = true
            case .critical: matchesFilter = insight.status.lowercased() == "critical"
            case .low: matchesFilter = insight.status.lowercased() == "low"
            case .overstock: matchesFilter = insight.status.lowercased() == "overstock"
            case .healthy: matchesFilter = insight.status.lowercased() == "healthy"
            }
            return matchesSearch && matchesFilter
        }
        
        return VStack(alignment: .leading, spacing: 14) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                TextField("Search items...", text: $searchText)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                    }
                }
            }
            .padding(12)
            .background(AppTheme.cardSurface)
            .cornerRadius(14)
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StatusFilter.allCases, id: \.self) { filter in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { activeFilter = filter }
                        } label: {
                            HStack(spacing: 4) {
                                if filter != .all {
                                    Circle()
                                        .fill(filterColor(filter))
                                        .frame(width: 6, height: 6)
                                }
                                Text(filter.rawValue)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(activeFilter == filter ? filterColor(filter).opacity(0.15) : AppTheme.cardSurface)
                            .foregroundColor(activeFilter == filter ? filterColor(filter) : AppTheme.textSecondary)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(activeFilter == filter ? filterColor(filter).opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
            }
            
            // Expand/Collapse toggle + count
            HStack {
                Text("\(filteredInsights.count) items")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        expandAll.toggle()
                        if expandAll {
                            // expand all won't set individual IDs, handled in card
                        } else {
                            expandedInsightId = nil
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: expandAll ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                            .font(.system(size: 11, weight: .semibold))
                        Text(expandAll ? "Collapse All" : "Expand All")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(AppTheme.primary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(AppTheme.primary.opacity(0.08))
                    .cornerRadius(8)
                }
            }
            
            if filteredInsights.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 30))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.3))
                    Text("No items match your filter")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(Array(filteredInsights.enumerated()), id: \.element.id) { index, item in
                    itemDetailCard(item)
                        .offset(y: animate ? 0 : 20)
                        .opacity(animate ? 1 : 0)
                        .animation(
                            .spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.03),
                            value: animate
                        )
                }
            }
        }
    }
    
    private func itemDetailCard(_ insight: GroqInventoryInsight) -> some View {
        let statusColor = colorFor(insight.status)
        let isExpanded = expandAll || expandedInsightId == insight.id
        
        return VStack(alignment: .leading, spacing: 0) {
            // Header - always visible, tappable
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if expandAll {
                        expandAll = false
                        expandedInsightId = insight.id
                    } else {
                        expandedInsightId = (expandedInsightId == insight.id) ? nil : insight.id
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.itemName)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        Text(insight.category.capitalized)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                    Text(insight.status.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(statusColor.opacity(0.12))
                        .foregroundColor(statusColor)
                        .cornerRadius(8)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            
            // Expanded detail
            if isExpanded {
                VStack(spacing: 14) {
                    Divider()
                    
                    // Quantity row
                    HStack(spacing: 0) {
                        quantityBox(title: "Current", value: "\(insight.currentQuantity)", color: statusColor)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.textSecondary.opacity(0.4))
                        Spacer()
                        quantityBox(title: "Optimal", value: "\(insight.optimalQuantity)", color: AppTheme.primary)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.textSecondary.opacity(0.4))
                        Spacer()
                        quantityBox(title: "Order", value: insight.recommendedOrder > 0 ? "+\(insight.recommendedOrder)" : "—", color: AppTheme.primary)
                    }
                    
                    // Cost and Urgency
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Est. Cost")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                            Text(insight.estimatedCost > 0 ? formatCurrency(insight.estimatedCost) : "₹0")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundColor(AppTheme.primary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("Urgency")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                            Text(insight.urgency)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(urgencyColor(insight.urgency).opacity(0.12))
                                .foregroundColor(urgencyColor(insight.urgency))
                                .cornerRadius(8)
                        }
                    }
                    
                    // Reason
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(statusColor.opacity(0.7))
                            .font(.system(size: 14))
                        Text(insight.reason)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(isExpanded ? 0.5 : 0.2), lineWidth: 1)
        )
    }
    
    private func quantityBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(color)
        }
        .frame(width: 70)
        .padding(.vertical, 10)
        .background(color.opacity(0.06))
        .cornerRadius(12)
    }
    
    // MARK: - 3. Risks Section
    private func risksSection(_ data: GroqInventoryResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top Risks
            if data.topRisks.isEmpty {
                // Success empty state
                successCard(
                    icon: "shield.checkmark.fill",
                    title: "No Risks Detected",
                    subtitle: "Your inventory is well-managed with no active risk alerts.",
                    color: AppTheme.primary
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "shield.trianglebadge.exclamationmark.fill")
                            .foregroundColor(.red)
                        Text("Top Risks")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    ForEach(Array(data.topRisks.enumerated()), id: \.offset) { idx, risk in
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle().fill(Color.red.opacity(0.12)).frame(width: 28, height: 28)
                                Text("\(idx + 1)")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundColor(.red)
                            }
                            Text(risk)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardSurface)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.2), lineWidth: 1))
                .offset(y: animate ? 0 : 20)
                .opacity(animate ? 1 : 0)
            }
            
            // Critical Items fast view
            let criticals = data.actionableInsights
                .filter { $0.status.lowercased() == "critical" }
                .sorted { urgencyRank($0.urgency) < urgencyRank($1.urgency) }
            if !criticals.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("🚨 Critical Stock Items")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                    ForEach(criticals) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.itemName)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("Only \(item.currentQuantity) left — needs \(item.recommendedOrder) ASAP")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            Spacer()
                            Text(formatCurrency(item.estimatedCost))
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundColor(.red)
                        }
                        .padding(14)
                        .background(Color.red.opacity(0.06))
                        .cornerRadius(12)
                    }
                }
                .padding(18)
                .background(AppTheme.cardSurface)
                .cornerRadius(16)
                .offset(y: animate ? 0 : 25)
                .opacity(animate ? 1 : 0)
            } else {
                successCard(
                    icon: "checkmark.seal.fill",
                    title: "No Critical Items",
                    subtitle: "All items are above critical stock levels.",
                    color: AppTheme.primary
                )
                .offset(y: animate ? 0 : 25)
                .opacity(animate ? 1 : 0)
            }
            
            // Overstock Items
            let overstocked = data.actionableInsights.filter { $0.status.lowercased() == "overstock" }
            if !overstocked.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("📦 Overstocked Items")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    ForEach(overstocked) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.itemName)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("Qty: \(item.currentQuantity) (optimal: \(item.optimalQuantity))")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            Spacer()
                            Text("EXCESS")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.orange.opacity(0.12))
                                .foregroundColor(.orange)
                                .cornerRadius(6)
                        }
                        .padding(14)
                        .background(Color.orange.opacity(0.04))
                        .cornerRadius(12)
                    }
                }
                .padding(18)
                .background(AppTheme.cardSurface)
                .cornerRadius(16)
                .offset(y: animate ? 0 : 30)
                .opacity(animate ? 1 : 0)
            }
        }
    }
    
    // MARK: - Success Card
    private func successCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            Text(subtitle)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
    }
    
    // MARK: - 4. Action Plan Section
    private func actionPlanSection(_ data: GroqInventoryResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Strategic Recommendations
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill").foregroundColor(AppTheme.warning)
                    Text("Strategic Recommendations")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
                ForEach(Array(data.recommendations.enumerated()), id: \.offset) { idx, rec in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle().fill(AppTheme.primary.opacity(0.12)).frame(width: 28, height: 28)
                            Text("\(idx + 1)")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.primary)
                        }
                        Text(rec)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardSurface)
            .cornerRadius(16)
            .offset(y: animate ? 0 : 20)
            .opacity(animate ? 1 : 0)
            
            // Restock Order Summary
            let restockItems = data.actionableInsights
                .filter { $0.recommendedOrder > 0 }
                .sorted { urgencyRank($0.urgency) < urgencyRank($1.urgency) }
            if !restockItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.clipboard.fill").foregroundColor(AppTheme.primary)
                        Text("Restock Order Plan")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    
                    // Table Header
                    HStack {
                        Text("Item").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Qty").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(AppTheme.textSecondary)
                            .frame(width: 45, alignment: .center)
                        Text("Order").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(AppTheme.textSecondary)
                            .frame(width: 45, alignment: .center)
                        Text("Cost").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(AppTheme.textSecondary)
                            .frame(width: 70, alignment: .trailing)
                    }
                    .padding(.horizontal, 4)
                    
                    Divider()
                    
                    ForEach(restockItems) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.itemName)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .lineLimit(1)
                                Text(item.urgency)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(urgencyColor(item.urgency))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(item.currentQuantity)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(colorFor(item.status))
                                .frame(width: 45, alignment: .center)
                            Text("+\(item.recommendedOrder)")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 45, alignment: .center)
                            Text(formatCurrency(item.estimatedCost))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                                .frame(width: 70, alignment: .trailing)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 4)
                        Divider()
                    }
                    
                    // Total
                    HStack {
                        Spacer()
                        Text("Total:")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        Text(formatCurrency(data.totalEstimatedRestockCost))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.primary)
                    }
                    .padding(.top, 4)
                }
                .padding(18)
                .background(AppTheme.cardSurface)
                .cornerRadius(16)
                .offset(y: animate ? 0 : 25)
                .opacity(animate ? 1 : 0)
            }
        }
    }
    
    // MARK: - Helpers
    private func colorFor(_ status: String) -> Color {
        switch status.lowercased() {
        case "critical": return .red
        case "low": return AppTheme.warning
        case "overstock": return .orange
        default: return AppTheme.primary
        }
    }
    
    private func filterColor(_ filter: StatusFilter) -> Color {
        switch filter {
        case .all: return AppTheme.primary
        case .critical: return .red
        case .low: return AppTheme.warning
        case .overstock: return .orange
        case .healthy: return AppTheme.primary
        }
    }
    
    private func urgencyColor(_ urgency: String) -> Color {
        switch urgency.lowercased() {
        case "immediate": return .red
        case "this week": return AppTheme.warning
        default: return AppTheme.primary
        }
    }
    
    private func urgencyRank(_ urgency: String) -> Int {
        switch urgency.lowercased() {
        case "immediate": return 0
        case "this week": return 1
        case "next week": return 2
        default: return 3
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencySymbol = "₹"
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }
    
    private func refreshAnalysis() async {
        animate = false
        healthRingProgress = 0
        await fetchAndAnalyze()
    }
    
    private func fetchAndAnalyze() async {
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let beds = try await InventoryRepository.shared.fetchInventory(category: .beds)
                let meds = try await InventoryRepository.shared.fetchInventory(category: .medicines)
                let adds = try await InventoryRepository.shared.fetchInventory(category: .additionals)
                let total = beds + meds + adds
                
                var result = try await GroqInventoryAIService.shared.generateInsights(from: total)
                
                // MATH CORRECTION: LLMs are notoriously bad at math.
                // We intercept the response and strictly calculate costs client-side using accurate unit prices.
                var exactTotalCost: Double = 0
                
                for i in 0..<result.actionableInsights.count {
                    let insight = result.actionableInsights[i]
                    let accuratePrice = total.first(where: { $0.name == insight.itemName })?.unitPrice ?? 0
                    let calculatedCost = Double(insight.recommendedOrder) * accuratePrice
                    result.actionableInsights[i].estimatedCost = calculatedCost
                    exactTotalCost += calculatedCost
                }
                
                result.totalEstimatedRestockCost = exactTotalCost
                
                await MainActor.run {
                    self.allItems = total
                    self.insights = result
                    self.analyzedAt = Date()
                    self.isLoading = false
                    
                    // Trigger entrance animations
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                        animate = true
                    }
                    // Animate health ring
                    withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                        healthRingProgress = CGFloat(result.overallHealthScore) / 100.0
                    }
                }
                return // Success — exit immediately
            } catch {
                lastError = error
                
                // Don't retry on rate limit errors — retrying just wastes tokens
                let nsError = error as NSError
                if nsError.code == 429 || nsError.userInfo["isRateLimit"] as? Bool == true {
                    break
                }
                
                // If not the last attempt, wait before retrying (exponential backoff: 1s, 2s)
                if attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                }
            }
        }
        
        // All API retries exhausted — fall back to local analysis
        #if DEBUG
        print("⚠️ AI API failed after retries. Using local fallback. Last error: \(lastError?.localizedDescription ?? "unknown")")
        #endif
        
        // Fetch inventory locally if we don't have it yet
        var total: [InventoryItem] = []
        do {
            let beds = try await InventoryRepository.shared.fetchInventory(category: .beds)
            let meds = try await InventoryRepository.shared.fetchInventory(category: .medicines)
            let adds = try await InventoryRepository.shared.fetchInventory(category: .additionals)
            total = beds + meds + adds
        } catch {
            // Even inventory fetch failed — show error
            await MainActor.run {
                self.errorMessage = "Unable to load inventory data. Check your connection."
                self.isLoading = false
            }
            return
        }
        
        let result = LocalInventoryAnalyzer.analyze(total)
        
        await MainActor.run {
            self.allItems = total
            self.insights = result
            self.analyzedAt = Date()
            self.isLocalFallback = true
            self.isLoading = false
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animate = true
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                healthRingProgress = CGFloat(result.overallHealthScore) / 100.0
            }
        }
    }
}

// MARK: - Stat Card
fileprivate struct PlannerStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundColor(color)
            }
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
    }
}
