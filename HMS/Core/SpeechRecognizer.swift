import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
class SpeechRecognizer: ObservableObject {
    
    @Published var isRecording: Bool = false
    @Published var transcript: String = ""
    
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer()
    
    init() {
        Self.requestAuthorization()
    }
    
    static func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            // Handle if needed
            print("Speech Recognition Status: \(status.rawValue)")
        }
    }
    
    func startTranscribing() {
        // Reset properties
        self.transcript = ""
        self.stopTranscribing() // Ensure previous runs are stopped gracefully
        
        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("Speech recognizer is not available")
            return
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let request = SFSpeechAudioBufferRecognitionRequest()
            self.request = request
            request.shouldReportPartialResults = true
            
            let audioEngine = AVAudioEngine()
            self.audioEngine = audioEngine
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            self.isRecording = true
            
            self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    Task { @MainActor in
                        self.transcript = result.bestTranscription.formattedString
                    }
                }
                
                if error != nil || result?.isFinal == true {
                    self.stopTranscribing()
                }
            }
        } catch {
            print("Error starting speech recognition: \(error)")
            stopTranscribing()
        }
    }
    
    func stopTranscribing() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        
        audioEngine = nil
        request = nil
        task = nil
        
        Task { @MainActor in
            self.isRecording = false
        }
    }
}
