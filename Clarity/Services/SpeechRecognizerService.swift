import Foundation
import Combine
#if canImport(Speech) && os(iOS)
import Speech
import AVFoundation
#endif

/// Live speech-to-text for the assistant's chat input. Platform-guarded the
/// same way HealthKitManager is — the app still works with the keyboard
/// alone anywhere this isn't available.
@MainActor
final class SpeechRecognizerService: ObservableObject {
    static let shared = SpeechRecognizerService()

    @Published var isListening = false
    @Published var transcript = ""

    private init() {}

    var isAvailable: Bool {
        #if canImport(Speech) && os(iOS)
        return true
        #else
        return false
        #endif
    }

    #if canImport(Speech) && os(iOS)

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }

        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startListening() {
        guard !isListening, let recognizer, recognizer.isAvailable else { return }
        transcript = ""

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        request = recognitionRequest

        let inputNode = audioEngine.inputNode
        task = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.transcript = result.bestTranscription.formattedString
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stopListening()
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()
        isListening = true
    }

    func stopListening() {
        guard isListening else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isListening = false
    }

    #else

    func requestAuthorization() async -> Bool { false }
    func startListening() {}
    func stopListening() {}

    #endif
}
