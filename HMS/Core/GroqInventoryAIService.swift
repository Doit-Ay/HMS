import Foundation

// MARK: - Flexible Decoding Helpers (LLMs sometimes return numbers as strings)

private func flexibleInt<K: CodingKey>(from container: KeyedDecodingContainer<K>, key: K) -> Int {
    if let val = try? container.decode(Int.self, forKey: key) { return val }
    if let str = try? container.decode(String.self, forKey: key), let val = Int(str) { return val }
    if let dbl = try? container.decode(Double.self, forKey: key) { return Int(dbl) }
    return 0
}

private func flexibleDouble<K: CodingKey>(from container: KeyedDecodingContainer<K>, key: K) -> Double {
    if let val = try? container.decode(Double.self, forKey: key) { return val }
    if let str = try? container.decode(String.self, forKey: key), let val = Double(str) { return val }
    if let intVal = try? container.decode(Int.self, forKey: key) { return Double(intVal) }
    return 0
}

// MARK: - AI Response Models

struct GroqInventoryInsight: Codable, Identifiable {
    var id: String { itemName }
    let itemName: String
    let category: String
    let status: String          // "Critical", "Low", "Overstock", "Healthy"
    let currentQuantity: Int
    let optimalQuantity: Int
    let recommendedOrder: Int
    var estimatedCost: Double
    let urgency: String         // "Immediate", "This Week", "Next Month"
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case itemName, category, status, currentQuantity, optimalQuantity
        case recommendedOrder, estimatedCost, urgency, reason
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        itemName = (try? c.decode(String.self, forKey: .itemName)) ?? "Unknown"
        category = (try? c.decode(String.self, forKey: .category)) ?? "unknown"
        status = (try? c.decode(String.self, forKey: .status)) ?? "Healthy"
        currentQuantity = flexibleInt(from: c, key: CodingKeys.currentQuantity)
        optimalQuantity = flexibleInt(from: c, key: CodingKeys.optimalQuantity)
        recommendedOrder = flexibleInt(from: c, key: CodingKeys.recommendedOrder)
        estimatedCost = flexibleDouble(from: c, key: CodingKeys.estimatedCost)
        urgency = (try? c.decode(String.self, forKey: .urgency)) ?? "Next Month"
        reason = (try? c.decode(String.self, forKey: .reason)) ?? ""
    }
    
    init(itemName: String, category: String, status: String, currentQuantity: Int, optimalQuantity: Int, recommendedOrder: Int, estimatedCost: Double, urgency: String, reason: String) {
        self.itemName = itemName
        self.category = category
        self.status = status
        self.currentQuantity = currentQuantity
        self.optimalQuantity = optimalQuantity
        self.recommendedOrder = recommendedOrder
        self.estimatedCost = estimatedCost
        self.urgency = urgency
        self.reason = reason
    }
}

struct GroqCategoryBreakdown: Codable, Identifiable {
    var id: String { categoryName }
    let categoryName: String
    let totalItems: Int
    let healthyCount: Int
    let lowStockCount: Int
    let criticalCount: Int
    let overstockCount: Int
    let totalValue: Double
    
    enum CodingKeys: String, CodingKey {
        case categoryName, totalItems, healthyCount, lowStockCount
        case criticalCount, overstockCount, totalValue
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categoryName = (try? c.decode(String.self, forKey: .categoryName)) ?? "unknown"
        totalItems = flexibleInt(from: c, key: CodingKeys.totalItems)
        healthyCount = flexibleInt(from: c, key: CodingKeys.healthyCount)
        lowStockCount = flexibleInt(from: c, key: CodingKeys.lowStockCount)
        criticalCount = flexibleInt(from: c, key: CodingKeys.criticalCount)
        overstockCount = flexibleInt(from: c, key: CodingKeys.overstockCount)
        totalValue = flexibleDouble(from: c, key: CodingKeys.totalValue)
    }
    
    init(categoryName: String, totalItems: Int, healthyCount: Int, lowStockCount: Int, criticalCount: Int, overstockCount: Int, totalValue: Double) {
        self.categoryName = categoryName
        self.totalItems = totalItems
        self.healthyCount = healthyCount
        self.lowStockCount = lowStockCount
        self.criticalCount = criticalCount
        self.overstockCount = overstockCount
        self.totalValue = totalValue
    }
}

struct GroqInventoryResponse: Codable {
    let summary: String
    let overallHealthScore: Int
    var actionableInsights: [GroqInventoryInsight]
    let categoryBreakdown: [GroqCategoryBreakdown]
    let highPriorityRestockCount: Int
    let healthyStockCount: Int
    var totalEstimatedRestockCost: Double
    let topRisks: [String]
    let recommendations: [String]
    
    enum CodingKeys: String, CodingKey {
        case summary, overallHealthScore, actionableInsights, categoryBreakdown
        case highPriorityRestockCount, healthyStockCount, totalEstimatedRestockCost
        case topRisks, recommendations
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = (try? c.decode(String.self, forKey: .summary)) ?? "Analysis complete."
        overallHealthScore = flexibleInt(from: c, key: CodingKeys.overallHealthScore)
        actionableInsights = (try? c.decode([GroqInventoryInsight].self, forKey: .actionableInsights)) ?? []
        categoryBreakdown = (try? c.decode([GroqCategoryBreakdown].self, forKey: .categoryBreakdown)) ?? []
        highPriorityRestockCount = flexibleInt(from: c, key: CodingKeys.highPriorityRestockCount)
        healthyStockCount = flexibleInt(from: c, key: CodingKeys.healthyStockCount)
        totalEstimatedRestockCost = flexibleDouble(from: c, key: CodingKeys.totalEstimatedRestockCost)
        topRisks = (try? c.decode([String].self, forKey: .topRisks)) ?? []
        recommendations = (try? c.decode([String].self, forKey: .recommendations)) ?? []
    }
    
    init(summary: String, overallHealthScore: Int, actionableInsights: [GroqInventoryInsight], categoryBreakdown: [GroqCategoryBreakdown], highPriorityRestockCount: Int, healthyStockCount: Int, totalEstimatedRestockCost: Double, topRisks: [String], recommendations: [String]) {
        self.summary = summary
        self.overallHealthScore = overallHealthScore
        self.actionableInsights = actionableInsights
        self.categoryBreakdown = categoryBreakdown
        self.highPriorityRestockCount = highPriorityRestockCount
        self.healthyStockCount = healthyStockCount
        self.totalEstimatedRestockCost = totalEstimatedRestockCost
        self.topRisks = topRisks
        self.recommendations = recommendations
    }
}

class GroqInventoryAIService {
    static let shared = GroqInventoryAIService()
    
    private var apiKey: String {
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let key = dict["GROQ_INVENTORY_API_KEY"] as? String {
            return key
        }
        #if DEBUG
        print("⚠️ Missing GROQ_INVENTORY_API_KEY in Secrets.plist")
        #endif
        return "YOUR_GROQ_INVENTORY_API_KEY_HERE"
    }
    
    func generateInsights(from inventory: [InventoryItem]) async throws -> GroqInventoryResponse {
        let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        
        let inventoryData = inventory.map { 
            "Item: \($0.name) | Category: \($0.category.rawValue) | Qty: \($0.quantity) | UnitPrice: ₹\($0.unitPrice) | Unit: \($0.unit)" 
        }.joined(separator: "\n")
        
        let systemPrompt = """
        You are an expert Hospital Inventory Manager AI. Analyze the provided hospital inventory data.
        Return ONLY a valid JSON object (no code blocks, no markdown, no extra text).
        Schema:
        {
          "summary": "<3-4 sentence analysis>",
          "overallHealthScore": <int 0-100>,
          "highPriorityRestockCount": <int>,
          "healthyStockCount": <int>,
          "totalEstimatedRestockCost": <double>,
          "topRisks": ["<risk1>", "<risk2>", "<risk3>"],
          "recommendations": ["<rec1>", "<rec2>", "<rec3>"],
          "categoryBreakdown": [{"categoryName":"<beds|medicines|additionals>","totalItems":<int>,"healthyCount":<int>,"lowStockCount":<int>,"criticalCount":<int>,"overstockCount":<int>,"totalValue":<double>}],
          "actionableInsights": [{"itemName":"<string>","category":"<beds|medicines|additionals>","status":"Critical"|"Low"|"Overstock"|"Healthy","currentQuantity":<int>,"optimalQuantity":<int>,"recommendedOrder":<int>,"estimatedCost":<double>,"urgency":"Immediate"|"This Week"|"Next Month","reason":"<short>"}]
        }
        Rules: 
        - Dynamically determine the status (Critical, Low, Overstock, Healthy) based on clinical importance and category.
        - E.g., 5 ICU Beds is Healthy, but 5 Paracetamol is Critical. 200 Paracetamol is Healthy, but 90 ICU Beds is Overstock.
        - LOGICAL CONSTRAINT: If currentQuantity >= optimalQuantity, it CANNOT be "Critical" or "Low". If currentQuantity is significantly higher than optimalQuantity, it is "Overstock".
        - IMPORTANT: Only include items that are Critical, Low, or Overstock in actionableInsights. Do NOT include Healthy items.
        Sort by urgency: Immediate first.
        """
        
        let messages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": "Analyze this hospital inventory:\n\(inventoryData)"]
        ]
        
        let requestBody: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": messages,
            "temperature": 0.2,
            "max_tokens": 4096,
            "response_format": ["type": "json_object"]
        ]
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errString = String(data: data, encoding: .utf8) ?? ""
            
            // Rate limit (429) — provide a clean user-facing message
            if httpResponse.statusCode == 429 {
                // Try to extract wait time from the error message
                var waitMessage = "Please wait a moment and try again."
                if let range = errString.range(of: #"try again in (\d+m[\d.]+s)"#, options: .regularExpression) {
                    let timeStr = errString[range].replacingOccurrences(of: "try again in ", with: "")
                    waitMessage = "Please try again in \(timeStr)."
                }
                throw NSError(domain: "GroqError", code: 429, userInfo: [
                    NSLocalizedDescriptionKey: "AI service rate limit reached. \(waitMessage)",
                    "isRateLimit": true
                ])
            }
            
            // Other API errors — show a concise message
            throw NSError(domain: "GroqError", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "AI service error (HTTP \(httpResponse.statusCode)). Please try again later."
            ])
        }
        
        struct GroqChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        let chatResponse = try JSONDecoder().decode(GroqChatResponse.self, from: data)
        guard let rawContent = chatResponse.choices.first?.message.content else {
            throw NSError(domain: "GroqError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty response"])
        }
        
        // Robust JSON extraction & cleaning
        var jsonString = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Strip markdown code fences (```json ... ```)
        if jsonString.hasPrefix("```") {
            // Remove opening fence (```json or ```)
            if let firstNewline = jsonString.firstIndex(of: "\n") {
                jsonString = String(jsonString[jsonString.index(after: firstNewline)...])
            }
            // Remove closing fence
            if jsonString.hasSuffix("```") {
                jsonString = String(jsonString.dropLast(3))
            }
            jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Extract outermost JSON object
        if let startRange = jsonString.range(of: "{"),
           let endRange = jsonString.range(of: "}", options: .backwards),
           startRange.lowerBound < endRange.upperBound {
            jsonString = String(jsonString[startRange.lowerBound..<endRange.upperBound])
        }
        
        // Remove control characters that LLMs sometimes inject
        jsonString = jsonString.unicodeScalars.filter { scalar in
            // Keep printable ASCII + standard whitespace (tab, newline, carriage return)
            scalar == "\t" || scalar == "\n" || scalar == "\r" || (scalar.value >= 0x20 && scalar.value < 0x7F) || scalar.value > 0x7F
        }.map { String($0) }.joined()
        
        // Fix trailing commas before ] or } (common LLM mistake)
        jsonString = jsonString.replacingOccurrences(
            of: #",\s*([}\]])"#,
            with: "$1",
            options: .regularExpression
        )
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "GroqError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response encoding"])
        }
        
        do {
            return try JSONDecoder().decode(GroqInventoryResponse.self, from: jsonData)
        } catch {
            #if DEBUG
            print("❌ AI Planner JSON decode error: \(error)")
            print("📝 Raw LLM response:\n\(rawContent.prefix(2000))")
            #endif
            throw NSError(domain: "GroqError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse AI response. The AI returned an unexpected format. Please retry."])
        }
    }
}
