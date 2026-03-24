import Foundation

// MARK: - AI Triage Service
// Analyzes patient-entered symptoms using Groq API (LLaMA model) for fast, accurate medical triage.
final class AITriageService {

    static let shared = AITriageService()

    // API key loaded from Secrets.plist (hidden from Git, like a .env file)
    private var apiKey: String {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["GROQ_API_KEY"] as? String else {
            return "YOUR_GROQ_API_KEY_HERE"
        }
        return key
    }
    
    private let endpoint = "https://api.groq.com/openai/v1/chat/completions"

    private let supportedDepartments = [
        "Cardiology", "Orthopaedics", "Pediatrics", "General Medicine",
        "Neurology", "ENT", "Dermatology", "Ophthalmology", "Gynaecology",
        "Psychiatry", "Gastroenterology", "Urology", "Oncology"
    ]

    private init() {}

    /// Sends the patient's symptom text to Groq API and returns the most appropriate department.
    /// Returns nil if the input is not a valid medical symptom.
    func analyzeSymptoms(_ symptoms: String) async -> TriageResult? {
        if apiKey == "YOUR_GROQ_API_KEY_HERE" {
            print("API Key missing! Returning fallback.")
            return TriageResult(department: "General Medicine", reason: "API Key missing. Please consult a general physician.")
        }

        let deptList = supportedDepartments.joined(separator: ", ")
        let prompt = """
        You are an expert medical triage system for a hospital management app.
        A patient has entered the following text: "\(symptoms.trimmingCharacters(in: .whitespacesAndNewlines))"

        IMPORTANT RULES:
        - If the text does NOT describe any medical symptoms (e.g., greetings like "hi", "hello", random gibberish, questions, or non-medical text), respond with:
          DEPARTMENT: NONE
          REASON: Please describe your medical symptoms for accurate analysis.
        - Only if the text clearly describes medical symptoms, return the single most relevant department from this list: \(deptList)

        Respond in this exact format only (no other text):
        DEPARTMENT: <department name or NONE>
        REASON: <brief reason, max 15 words>
        """

        // Prepare the request payload for Groq (OpenAI-compatible format)
        let requestBody: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.2
        ]
        
        guard let url = URL(string: endpoint) else {
            return fallback()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Groq API Error Response: \(errorJson)")
                } else {
                    print("Groq API HTTP Error: \( (response as? HTTPURLResponse)?.statusCode ?? 0 )")
                }
                return fallback()
            }
            
            // Parse Groq Response JSON (OpenAI-compatible format)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let text = message["content"] as? String {
                
                return parseResponse(text)
            } else {
                return nil
            }
            
        } catch {
            print("⚠️ AITriageService error: \(error.localizedDescription)")
            return nil
        }
    }

    private func parseResponse(_ text: String) -> TriageResult? {
        var department = "General Medicine"
        var reason = "Based on your symptoms."

        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("DEPARTMENT:") {
                let raw = line.replacingOccurrences(of: "DEPARTMENT:", with: "").trimmingCharacters(in: .whitespaces)
                // If the AI says NONE, the input wasn't a valid symptom
                if raw.uppercased() == "NONE" {
                    return nil
                }
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
