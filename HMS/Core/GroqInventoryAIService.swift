import Foundation

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
            "max_tokens": 4096
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
            throw NSError(domain: "GroqError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errString)"])
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
        
        // Extract JSON from response (handle cases where model wraps in code blocks)
        var jsonString = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if let startRange = jsonString.range(of: "{"),
           let endRange = jsonString.range(of: "}", options: .backwards),
           startRange.lowerBound < endRange.upperBound {
            jsonString = String(jsonString[startRange.lowerBound..<endRange.upperBound])
        }
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "GroqError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response encoding"])
        }
        
        return try JSONDecoder().decode(GroqInventoryResponse.self, from: jsonData)
    }
}
