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
            return fallback()
        }

        let deptList = supportedDepartments.joined(separator: ", ")
        let prompt = """
        You are an expert medical triage system for a hospital management app.
        A patient has entered the following text: "\(symptoms.trimmingCharacters(in: .whitespacesAndNewlines))"

        IMPORTANT RULES:
        - If the text does NOT describe any medical symptoms (e.g., greetings like "hi", "hello", random gibberish, questions, or non-medical text), return exactly this JSON:
          {
            "department": "NONE",
            "reason": "Please describe your medical symptoms for accurate analysis.",
            "urgencyLevel": "Routine",
            "possibleConditions": [],
            "homeCare": ""
          }
        - Only if the text clearly describes medical symptoms, return exactly a JSON object with these keys:
          - "department": the single most relevant department from this list: \(deptList)
          - "reason": brief reason for department, max 15 words
          - "urgencyLevel": "Emergency", "Urgent", or "Routine" based on symptom severity
          - "possibleConditions": array of 2-3 potential string conditions
          - "homeCare": brief first-aid or home care advice, max 20 words

        Respond ONLY with the raw JSON object. Do not include markdown formatting or extra text.
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
            "response_format": ["type": "json_object"],
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
        guard let data = text.data(using: .utf8) else { return nil }
        do {
            let result = try JSONDecoder().decode(TriageResult.self, from: data)
            if result.department.uppercased() == "NONE" {
                return nil
            }
            
            var finalResult = result
            if !supportedDepartments.contains(result.department) {
                // If hallucinates a department, fallback to general
                finalResult = TriageResult(
                    department: "General Medicine",
                    reason: result.reason,
                    urgencyLevel: result.urgencyLevel,
                    possibleConditions: result.possibleConditions,
                    homeCare: result.homeCare
                )
            }
            return finalResult
        } catch {
            print("Failed to decode JSON from Groq: \(error)")
            return nil
        }
    }
    
    private func fallback() -> TriageResult {
        return TriageResult(
            department: "General Medicine",
            reason: "Could not analyze symptoms. Please consult a general physician.",
            urgencyLevel: "Routine",
            possibleConditions: [],
            homeCare: "Please seek medical evaluation if symptoms worsen."
        )
    }

}

// MARK: - Triage Result
struct TriageResult: Codable {
    let department: String
    let reason: String
    let urgencyLevel: String
    let possibleConditions: [String]
    let homeCare: String
}
