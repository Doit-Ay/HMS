import Foundation

// MARK: - Medicine Model
struct Medicine: Identifiable, Codable {
    var id: String
    let name: String
    let uses: String
    let type: String       // "Tablets", "Injection", "Capsules", etc.
    let strengths: String  // "500 mg", "10 mg/ml", etc.
    let category: String   // "Analgesics", "Antiallergics", etc.
    var quantity: Int       // Stock count

    enum CodingKeys: String, CodingKey {
        case name, uses, type, strengths, category, quantity
    }

    init(name: String, uses: String, type: String, strengths: String, category: String, quantity: Int = 0) {
        self.id = UUID().uuidString
        self.name = name
        self.uses = uses
        self.type = type
        self.strengths = strengths
        self.category = category
        self.quantity = quantity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.name = try c.decode(String.self, forKey: .name)
        self.uses = try c.decode(String.self, forKey: .uses)
        self.type = try c.decode(String.self, forKey: .type)
        self.strengths = try c.decode(String.self, forKey: .strengths)
        self.category = try c.decode(String.self, forKey: .category)
        self.quantity = try c.decode(Int.self, forKey: .quantity)
    }
}
