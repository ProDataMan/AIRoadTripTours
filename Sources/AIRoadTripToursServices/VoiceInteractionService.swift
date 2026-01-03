import Foundation
@preconcurrency import Speech
#if os(iOS)
import AVFoundation
#endif
import AIRoadTripToursCore

#if os(iOS)

/// Service for handling voice interactions during audio tours.
/// iOS-only due to AVAudioSession requirements.
@available(iOS 17.0, *)
public actor VoiceInteractionService {

    private nonisolated(unsafe) let speechRecognizer: SFSpeechRecognizer?
    private nonisolated(unsafe) let audioEngine = AVAudioEngine()
    private nonisolated(unsafe) var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private nonisolated(unsafe) var recognitionTask: SFSpeechRecognitionTask?

    /// Patterns for affirmative responses
    private let affirmativePatterns = [
        "yes", "yeah", "yep", "sure",
        "okay", "ok", "alright",
        "tell me more", "continue", "go ahead",
        "i'd like to hear more", "i would like to hear more",
        "sounds interesting", "interested"
    ]

    /// Patterns for negative responses
    private let negativePatterns = [
        "no", "nope", "nah",
        "skip", "next", "pass",
        "not interested", "no thanks",
        "maybe later"
    ]

    public init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    /// Requests authorization for speech recognition and microphone access.
    public func requestAuthorization() async -> Bool {
        // Request speech recognition authorization
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechStatus else {
            return false
        }

        // Request microphone authorization
        let micStatus = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        return micStatus
    }

    /// Listens for user response with a timeout.
    /// - Parameters:
    ///   - timeout: Time to wait for response in seconds (default: 5.0)
    /// - Returns: UserResponse indicating yes, no, or no response
    public func listenForResponse(timeout: TimeInterval = 5.0) async -> UserResponse {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            return .noResponse
        }

        do {
            let transcription = try await startListening(timeout: timeout)
            return interpretResponse(transcription)
        } catch {
            return .noResponse
        }
    }

    // MARK: - Private

    private func startListening(timeout: TimeInterval) async throws -> String {
        // Cancel any ongoing recognition
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest = request
        request.shouldReportPartialResults = true

        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition with timeout
        return try await withThrowingTaskGroup(of: String.self) { group in
            // Recognition task
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    guard let recognizer = self.speechRecognizer else {
                        continuation.resume(throwing: VoiceError.recognizerUnavailable)
                        return
                    }

                    self.recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }

                        if let result = result, result.isFinal {
                            continuation.resume(returning: result.bestTranscription.formattedString)
                        }
                    }
                }
            }

            // Timeout task
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw VoiceError.timeout
            }

            // Return first result (either transcription or timeout)
            defer {
                group.cancelAll()
                self.stopListening()
            }

            do {
                if let result = try await group.next() {
                    return result
                }
            } catch is VoiceError {
                // Timeout or recognizer error
                return ""
            }

            return ""
        }
    }

    public nonisolated func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil
    }

    private func interpretResponse(_ transcription: String) -> UserResponse {
        let normalized = transcription.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for affirmative patterns
        for pattern in affirmativePatterns {
            if normalized.contains(pattern) {
                return .yes
            }
        }

        // Check for negative patterns
        for pattern in negativePatterns {
            if normalized.contains(pattern) {
                return .no
            }
        }

        // No clear response detected
        return .noResponse
    }
}

#endif

/// Errors that can occur during voice interaction
public enum VoiceError: Error, LocalizedError {
    case recognizerUnavailable
    case timeout
    case authorizationDenied

    public var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is not available"
        case .timeout:
            return "Voice recognition timed out"
        case .authorizationDenied:
            return "Speech recognition or microphone access denied"
        }
    }
}
