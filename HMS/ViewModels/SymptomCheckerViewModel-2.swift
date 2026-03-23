import SwiftUI
import Combine
import CoreML
import NaturalLanguage

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isBot: Bool
    var chips: [String] = []
}

// MARK: - Chat State

enum ChatState {
    case waitingForSymptoms
    case askingForMore
    case showingResult
}

// MARK: - SymptomCheckerViewModel

@MainActor
final class SymptomCheckerViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var chatState: ChatState = .waitingForSymptoms
    @Published var predictedDepartment: String? = nil
    @Published var collectedSymptoms: [String] = []

    var suggestedSymptoms: [String] {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return [] }
        return SymptomMapper.shared.allSymptoms.filter { s in
            let lower = s.lowercased()
            return lower.contains(trimmed) &&
                   !collectedSymptoms.contains(where: { $0.lowercased() == lower })
        }.prefix(6).map { $0 }
    }

    // MARK: - Round 1 chips
    let openingChips = [
        "Headache", "Fever", "Chest pain", "Back pain",
        "Eye pain", "Ear pain", "Skin rash", "Anxiety",
        "Knee pain", "Cough", "Acne", "Burning urination",
        "Period cramps", "Child fever", "Blurry vision", "Palpitations"
    ]

    // MARK: - Related chips per department (round 2)
    private let relatedChips: [String: [String]] = [
        "Dermatology":      ["Itching", "Hair loss", "Dandruff", "Oily skin", "Dry skin", "Nail infection", "Fungal", "Warts"],
        "Cardiology":       ["Breathlessness", "Swollen ankles", "High BP", "Dizziness", "Sweating", "Fatigue", "Irregular heartbeat"],
        "General Medicine": ["Body ache", "Sore throat", "Runny nose", "Vomiting", "Fatigue", "Weight loss", "Blood sugar"],
        "Orthopedics":      ["Swelling", "Stiffness", "Neck pain", "Hip pain", "Shoulder pain", "Fracture", "Muscle pain"],
        "Neurology":        ["Numbness", "Tingling", "Tremors", "Memory loss", "Seizure", "Balance issues", "Slurred speech"],
        "Ophthalmology":    ["Watery eyes", "Dry eyes", "Floaters", "Double vision", "Eye discharge", "Light sensitivity"],
        "ENT":              ["Blocked nose", "Hearing loss", "Tinnitus", "Hoarse voice", "Sinus pain", "Snoring", "Nosebleed"],
        "Psychiatry":       ["Insomnia", "Panic attacks", "Mood swings", "Depression", "Stress", "OCD", "Burnout"],
        "Gynaecology":      ["Irregular periods", "Discharge", "Pelvic pain", "Hot flashes", "Breast pain", "PCOS", "Pregnancy"],
        "Paediatrics":      ["Baby not feeding", "Child rash", "Vaccination", "Delayed speech", "Wheezing", "Vomiting child"],
        "Urology":          ["Frequent urination", "Blood in urine", "Kidney stone", "Prostate issues", "Weak urine flow", "Testicular pain"]
    ]

    // MARK: - Init

    init() {
        appendBotMessage(
            text: "Hi! I'm here to help you find the right doctor. 👋\nWhat symptoms are you experiencing?",
            chips: openingChips + ["Other"]
        )
    }

    // MARK: - User sends a message

    func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(text: trimmed, isBot: false))
        inputText = ""

        let lower = trimmed.lowercased()
        if lower == "no, that's all" || lower == "done" || lower == "that's all" {
            showResult()
            return
        }

        collectedSymptoms.append(trimmed)

        let combined = collectedSymptoms.joined(separator: " ")
        let prediction = predict(for: combined)
        predictedDepartment = prediction

        chatState = .askingForMore
        let related = (relatedChips[prediction] ?? []).filter {
            !collectedSymptoms.contains($0)
        }
        appendBotMessage(
            text: "Got it. Any other symptoms?",
            chips: related + ["No, that's all"]
        )
    }

    // MARK: - Show final result

    func showResult() {
        chatState = .showingResult
        let dept = predictedDepartment ?? predict(for: collectedSymptoms.joined(separator: " "))
        predictedDepartment = dept
        appendBotMessage(
            text: "Based on your symptoms, I recommend the **\(dept)** department.\n\nHere are the available doctors 👇",
            chips: []
        )
    }

    // MARK: - Reset

    func restart() {
        messages = []
        collectedSymptoms = []
        predictedDepartment = nil
        inputText = ""
        chatState = .waitingForSymptoms
        appendBotMessage(
            text: "Hi again! What symptoms are you experiencing?",
            chips: openingChips + ["Other"]
        )
    }

    // MARK: - Prediction: Core ML first, keyword fallback second

    private func predict(for input: String) -> String {
        if let mlResult = coreMLPredict(input), mlResult.confidence > 0.65 {
            return mlResult.department
        }
        return SymptomMapper.shared.topDepartment(for: input).department
    }

    private func coreMLPredict(_ input: String) -> (department: String, confidence: Double)? {
        guard
            let model = try? SymptomClassifier(configuration: MLModelConfiguration()),
            let nlModel = try? NLModel(mlModel: model.model)
        else { return nil }

        guard let label = nlModel.predictedLabel(for: input) else { return nil }
        let confidence = nlModel.predictedLabelHypotheses(for: input, maximumCount: 1).values.first ?? 0.0
        return (label, confidence)
    }

    // MARK: - Helper

    private func appendBotMessage(text: String, chips: [String]) {
        messages.append(ChatMessage(text: text, isBot: true, chips: chips))
    }
}
