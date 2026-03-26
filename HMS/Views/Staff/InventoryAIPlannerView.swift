import SwiftUI

struct InventoryAIPlannerView: View {
    @State private var insights: GroqInventoryResponse?
    @State private var allItems: [InventoryItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedSection: PlannerSection = .overview
    @State private var expandedInsightId: String?
    
    enum PlannerSection: String, CaseIterable {
        case overview = "Overview"
        case items = "All Items"
        case risks = "Risks"
        case plan = "Action Plan"
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(PlannerSection.allCases, id: \.self) { section in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { selectedSection = section }
                                } label: {
                                    Text(section.rawValue)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 16).padding(.vertical, 8)
                                        .background(selectedSection == section ? AppTheme.primary : AppTheme.cardSurface)
                                        .foregroundColor(selectedSection == section ? .white : AppTheme.textSecondary)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
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
                }
            }
        }
        .task { await fetchAndAnalyze() }
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
            // Health Score Ring
            healthScoreCard(data)
            
            // Cost Card
            costCard(data)
            
            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                PlannerStatCard(title: "Total Items", value: "\(allItems.count)", icon: "shippingbox.fill", color: AppTheme.primary)
                PlannerStatCard(title: "Urgent Restock", value: "\(data.highPriorityRestockCount)", icon: "exclamationmark.circle.fill", color: .red)
                PlannerStatCard(title: "Healthy Items", value: "\(data.healthyStockCount)", icon: "checkmark.shield.fill", color: AppTheme.primary)
                PlannerStatCard(title: "Health Score", value: "\(data.overallHealthScore)%", icon: "heart.fill", color: data.overallHealthScore > 70 ? AppTheme.primary : data.overallHealthScore > 40 ? AppTheme.warning : .red)
            }
            
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
                    .trim(from: 0, to: CGFloat(data.overallHealthScore) / 100.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(data.overallHealthScore)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
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
        VStack(alignment: .leading, spacing: 14) {
            // Quick filter legend
            HStack(spacing: 10) {
                miniTag("● Critical", .red)
                miniTag("● Low", AppTheme.warning)
                miniTag("● Overstock", .orange)
                miniTag("● Healthy", AppTheme.primary)
            }
            
            ForEach(data.actionableInsights) { item in
                itemDetailCard(item)
            }
        }
    }
    
    private func itemDetailCard(_ insight: GroqInventoryInsight) -> some View {
        let statusColor = colorFor(insight.status)
        let isExpanded = expandedInsightId == insight.id
        
        return VStack(alignment: .leading, spacing: 0) {
            // Header - always visible, tappable
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedInsightId = isExpanded ? nil : insight.id
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
            
            // Critical Items fast view
            let criticals = data.actionableInsights.filter { $0.status.lowercased() == "critical" }
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
            }
        }
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
            
            // Restock Order Summary
            let restockItems = data.actionableInsights.filter { $0.recommendedOrder > 0 }
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
    
    private func urgencyColor(_ urgency: String) -> Color {
        switch urgency.lowercased() {
        case "immediate": return .red
        case "this week": return AppTheme.warning
        default: return AppTheme.primary
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencySymbol = "₹"
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }
    
    private func fetchAndAnalyze() async {
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
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
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
