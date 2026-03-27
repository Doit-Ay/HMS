import Foundation

/// A rule-based, on-device inventory analyzer that produces the same
/// `GroqInventoryResponse` model. Used as an automatic fallback when the
/// Groq AI API is unavailable (rate-limited, offline, etc.).
struct LocalInventoryAnalyzer {
    
    static func analyze(_ items: [InventoryItem]) -> GroqInventoryResponse {
        
        // ── Per-item analysis ──────────────────────────────────────
        
        var insights: [GroqInventoryInsight] = []
        var criticalCount = 0
        var lowCount = 0
        var overstockCount = 0
        var healthyCount = 0
        var totalRestockCost: Double = 0
        var risks: [String] = []
        
        for item in items where item.isActive {
            let optimal = optimalQuantity(for: item)
            let status  = determineStatus(item: item, optimal: optimal)
            let order   = max(0, optimal - item.quantity)
            let cost    = Double(order) * item.unitPrice
            
            switch status {
            case "Critical": criticalCount += 1
            case "Low":      lowCount += 1
            case "Overstock": overstockCount += 1
            default:         healthyCount += 1
            }
            
            // Only include non-healthy items in actionable insights
            if status != "Healthy" {
                let urgency: String
                switch status {
                case "Critical": urgency = "Immediate"
                case "Low":      urgency = "This Week"
                default:         urgency = "Next Month"
                }
                
                insights.append(GroqInventoryInsight(
                    itemName: item.name,
                    category: item.category.rawValue,
                    status: status,
                    currentQuantity: item.quantity,
                    optimalQuantity: optimal,
                    recommendedOrder: order,
                    estimatedCost: cost,
                    urgency: urgency,
                    reason: reasonText(item: item, status: status, optimal: optimal)
                ))
                
                totalRestockCost += cost
            }
        }
        
        // Sort by urgency: Immediate → This Week → Next Month
        insights.sort { urgencyRank($0.urgency) < urgencyRank($1.urgency) }
        
        // ── Category breakdown ─────────────────────────────────────
        
        let categoryBreakdown = InventoryCategory.allCases.compactMap { cat -> GroqCategoryBreakdown? in
            let catItems = items.filter { $0.category == cat && $0.isActive }
            guard !catItems.isEmpty else { return nil }
            
            var cCritical = 0, cLow = 0, cOverstock = 0, cHealthy = 0
            var totalValue: Double = 0
            
            for item in catItems {
                let optimal = optimalQuantity(for: item)
                let status = determineStatus(item: item, optimal: optimal)
                switch status {
                case "Critical": cCritical += 1
                case "Low":      cLow += 1
                case "Overstock": cOverstock += 1
                default:         cHealthy += 1
                }
                totalValue += Double(item.quantity) * item.unitPrice
            }
            
            return GroqCategoryBreakdown(
                categoryName: cat.rawValue,
                totalItems: catItems.count,
                healthyCount: cHealthy,
                lowStockCount: cLow,
                criticalCount: cCritical,
                overstockCount: cOverstock,
                totalValue: totalValue
            )
        }
        
        // ── Health score ───────────────────────────────────────────
        
        let totalActive = max(items.filter(\.isActive).count, 1)
        let healthScore = min(100, max(0, Int((Double(healthyCount) / Double(totalActive)) * 100)))
        
        // ── Risks ──────────────────────────────────────────────────
        
        if criticalCount > 0 {
            risks.append("\(criticalCount) item(s) are at critically low stock and need immediate restocking.")
        }
        if lowCount > 0 {
            risks.append("\(lowCount) item(s) are running low and should be reordered this week.")
        }
        if overstockCount > 0 {
            risks.append("\(overstockCount) item(s) are overstocked, tying up capital and storage space.")
        }
        if risks.isEmpty {
            risks.append("No significant risks detected. Inventory is well-managed.")
        }
        
        // ── Recommendations ────────────────────────────────────────
        
        var recommendations: [String] = []
        if criticalCount > 0 {
            recommendations.append("Immediately reorder critical items to avoid service disruption.")
        }
        if lowCount > 0 {
            recommendations.append("Schedule restocking for low-stock items within this week.")
        }
        if overstockCount > 0 {
            recommendations.append("Review overstocked items — consider reducing next order quantities to free up budget.")
        }
        if healthScore > 70 {
            recommendations.append("Maintain current restocking schedules to keep inventory healthy.")
        } else {
            recommendations.append("Consider implementing automated reorder alerts for critical categories.")
        }
        
        // ── Summary ────────────────────────────────────────────────
        
        let summary: String
        if healthScore > 70 {
            summary = "Inventory is in good shape with \(healthyCount) out of \(totalActive) items at healthy levels. \(criticalCount > 0 ? "\(criticalCount) item(s) need immediate attention." : "No critical shortages detected.") Estimated restocking cost is ₹\(Int(totalRestockCost))."
        } else if healthScore > 40 {
            summary = "Inventory needs attention — \(criticalCount + lowCount) item(s) are below optimal levels. \(criticalCount) critical item(s) require immediate restocking. Overall health is moderate at \(healthScore)%."
        } else {
            summary = "Inventory is in critical condition with only \(healthScore)% health. \(criticalCount) item(s) are critically low and \(lowCount) are running low. Immediate action is required to prevent stockouts."
        }
        
        return GroqInventoryResponse(
            summary: summary,
            overallHealthScore: healthScore,
            actionableInsights: insights,
            categoryBreakdown: categoryBreakdown,
            highPriorityRestockCount: criticalCount,
            healthyStockCount: healthyCount,
            totalEstimatedRestockCost: totalRestockCost,
            topRisks: risks,
            recommendations: recommendations
        )
    }
    
    // MARK: - Helpers
    
    /// Determines optimal quantity based on category and clinical importance
    private static func optimalQuantity(for item: InventoryItem) -> Int {
        switch item.category {
        case .beds:
            // Beds: optimal is moderate — hospitals don't need hundreds
            return max(10, item.quantity > 5 ? item.quantity : 10)
        case .medicines:
            // Medicines: need higher stock levels
            if item.unitPrice < 20 {
                return 200  // cheap essentials (paracetamol, etc.) — keep high stock
            } else if item.unitPrice < 100 {
                return 100  // mid-range meds
            } else {
                return 50   // expensive meds — lower threshold
            }
        case .additionals:
            // Equipment/supplies: moderate levels
            if item.unitPrice < 50 {
                return 100  // consumables (gloves, syringes, etc.)
            } else {
                return 30   // equipment
            }
        }
    }
    
    /// Determines item status based on quantity vs optimal
    private static func determineStatus(item: InventoryItem, optimal: Int) -> String {
        let ratio = Double(item.quantity) / Double(max(optimal, 1))
        
        if ratio >= 1.8 {
            return "Overstock"
        } else if ratio >= 0.6 {
            return "Healthy"
        } else if ratio >= 0.25 {
            return "Low"
        } else {
            return "Critical"
        }
    }
    
    /// Generates a human-readable reason
    private static func reasonText(item: InventoryItem, status: String, optimal: Int) -> String {
        switch status {
        case "Critical":
            return "Only \(item.quantity) \(item.unit)(s) remaining — well below the recommended \(optimal). Immediate restocking needed."
        case "Low":
            return "Stock at \(item.quantity) \(item.unit)(s), below the optimal level of \(optimal). Reorder soon to avoid shortages."
        case "Overstock":
            return "Current stock of \(item.quantity) \(item.unit)(s) significantly exceeds the optimal \(optimal). Consider reducing next order."
        default:
            return "Stock levels are adequate."
        }
    }
    
    private static func urgencyRank(_ urgency: String) -> Int {
        switch urgency.lowercased() {
        case "immediate": return 0
        case "this week": return 1
        default:          return 2
        }
    }
}
