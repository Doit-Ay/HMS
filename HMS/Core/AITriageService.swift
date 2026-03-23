import Foundation

// MARK: - AI Triage Service
// Analyzes patient-entered symptoms using Gemini REST API directly to bypass Firebase restrictions.
final class AITriageService {

    static let shared = AITriageService()

    private let apiKey = "AIzaSyDsE_N_YPZSxgiPEnYShn9HIMX6TWncxVY"
    
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    private let supportedDepartments = [
        "Cardiology", "Orthopaedics", "Pediatrics", "General Medicine",
        "Neurology", "ENT", "Dermatology", "Ophthalmology", "Gynaecology",
        "Psychiatry", "Gastroenterology", "Urology", "Oncology"
    ]

    private init() {}

    /// Sends the patient's symptom text to Gemini via REST API and returns the most appropriate department.
    func analyzeSymptoms(_ symptoms: String) async -> TriageResult {
        if apiKey == "YOUR_API_KEY_HERE" {
            print("API Key missing! Returning fallback.")
            return TriageResult(department: "General Medicine", reason: "API Key missing. Please consult a general physician.")
        }

        let deptList = supportedDepartments.joined(separator: ", ")
        let prompt = """
        You are an expert medical triage system for a hospital management app.
        A patient has described these symptoms: "\(symptoms.trimmingCharacters(in: .whitespacesAndNewlines))"

        Your job is to:
        1. Return the single most relevant department from this list: \(deptList)
        2. Return a brief one-sentence reason (max 15 words) for why you chose that department.

        Respond in this exact format only (no other text):
        DEPARTMENT: <department name>
        REASON: <brief reason>
        """

        // Prepare the request payload for Gemini
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2
            ]
        ]
        
        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else {
            return fallback()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("API Error Response: \(errorJson)")
                } else {
                    print("API HTTP Error: \( (response as? HTTPURLResponse)?.statusCode ?? 0 )")
                }
                return fallback()
            }
            
            // Parse Gemini Response JSON
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let text = firstPart["text"] as? String {
                
                return parseResponse(text)
            } else {
                return fallback()
            }
            
        } catch {
            print("⚠️ AITriageService error: \(error.localizedDescription)")
            return fallback()
        }
    }

    private func parseResponse(_ text: String) -> TriageResult {
        var department = "General Medicine"
        var reason = "Based on your symptoms."

        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("DEPARTMENT:") {
                let raw = line.replacingOccurrences(of: "DEPARTMENT:", with: "").trimmingCharacters(in: .whitespaces)
                if supportedDepartments.contains(raw) {
                    department = raw
                }
            } else if line.hasPrefix("REASON:") {
                reason = line.replacingOccurrences(of: "REASON:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return TriageResult(department: department, reason: reason)
    }
    
    private func fallback() -> TriageResult {
        return TriageResult(department: "General Medicine", reason: "Could not analyze symptoms. Please consult a general physician.")
    }
}

// MARK: - Triage Result
struct TriageResult {
    let department: String
    let reason: String
}
