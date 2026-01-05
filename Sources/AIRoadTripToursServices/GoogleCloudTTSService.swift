import Foundation
import AIRoadTripToursCore

/// Google Cloud Text-to-Speech service for generating high-quality narration audio.
///
/// Free tier: 1 million characters/month (WaveNet voices)
/// API documentation: https://cloud.google.com/text-to-speech/docs
///
/// **Setup Required**:
/// 1. Create Google Cloud project
/// 2. Enable Text-to-Speech API
/// 3. Create API key or service account
/// 4. Set API_KEY environment variable or pass to initializer
public final class GoogleCloudTTSService {
    private let apiKey: String
    private let session: URLSession
    private let endpoint = "https://texttospeech.googleapis.com/v1/text:synthesize"

    /// Voice configuration for synthesis.
    public struct VoiceConfig: Sendable {
        public let languageCode: String
        public let name: String
        public let gender: Gender

        public enum Gender: String, Sendable {
            case male = "MALE"
            case female = "FEMALE"
            case neutral = "NEUTRAL"
        }

        /// US English female voice (WaveNet, high quality).
        public static let defaultVoice = VoiceConfig(
            languageCode: "en-US",
            name: "en-US-Neural2-F",
            gender: .female
        )

        /// US English male voice (WaveNet, high quality).
        public static let maleVoice = VoiceConfig(
            languageCode: "en-US",
            name: "en-US-Neural2-D",
            gender: .male
        )

        public init(languageCode: String, name: String, gender: Gender) {
            self.languageCode = languageCode
            self.name = name
            self.gender = gender
        }
    }

    /// Audio encoding formats.
    public enum AudioEncoding: String {
        case mp3 = "MP3"
        case linear16 = "LINEAR16"
        case oggOpus = "OGG_OPUS"
    }

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    /// Generates audio from text using Google Cloud TTS.
    ///
    /// - Parameters:
    ///   - text: Text to synthesize (max 5000 characters)
    ///   - voice: Voice configuration
    ///   - encoding: Output audio encoding
    ///   - speakingRate: Speaking rate (0.25 to 4.0, default 1.0)
    ///   - pitch: Voice pitch (-20.0 to 20.0, default 0.0)
    /// - Returns: Audio data in specified encoding
    public func synthesize(
        text: String,
        voice: VoiceConfig = .defaultVoice,
        encoding: AudioEncoding = .mp3,
        speakingRate: Double = 1.0,
        pitch: Double = 0.0
    ) async throws -> Data {
        guard text.count <= 5000 else {
            throw TTSError.textTooLong
        }

        // Build request body
        let requestBody: [String: Any] = [
            "input": ["text": text],
            "voice": [
                "languageCode": voice.languageCode,
                "name": voice.name,
                "ssmlGender": voice.gender.rawValue
            ],
            "audioConfig": [
                "audioEncoding": encoding.rawValue,
                "speakingRate": speakingRate,
                "pitch": pitch
            ]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        // Create request
        var request = URLRequest(url: URL(string: "\(endpoint)?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        // Execute request
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TTSError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let audioContent = json["audioContent"] as? String,
              let audioData = Data(base64Encoded: audioContent) else {
            throw TTSError.invalidResponse
        }

        return audioData
    }

    /// Generates audio for narration with automatic text chunking if needed.
    ///
    /// - Parameters:
    ///   - narration: Narration to synthesize
    ///   - voice: Voice configuration
    /// - Returns: Audio data
    public func synthesizeNarration(
        _ narration: Narration,
        voice: VoiceConfig = .defaultVoice
    ) async throws -> Data {
        let text = narration.content

        // If text is short enough, synthesize directly
        if text.count <= 5000 {
            return try await synthesize(text: text, voice: voice)
        }

        // Otherwise, chunk and concatenate
        let chunks = chunkText(text, maxLength: 4500) // Leave buffer for safety

        var audioChunks: [Data] = []

        for chunk in chunks {
            let audioData = try await synthesize(text: chunk, voice: voice)
            audioChunks.append(audioData)
        }

        // Concatenate MP3 chunks (simple concatenation works for MP3)
        return audioChunks.reduce(Data(), +)
    }

    // MARK: - Private Methods

    /// Chunks text at sentence boundaries.
    private func chunkText(_ text: String, maxLength: Int) -> [String] {
        var chunks: [String] = []
        var currentChunk = ""

        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))

        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let sentenceWithPunctuation = trimmed + "."

            if currentChunk.count + sentenceWithPunctuation.count > maxLength {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
                currentChunk = sentenceWithPunctuation
            } else {
                currentChunk += (currentChunk.isEmpty ? "" : " ") + sentenceWithPunctuation
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks
    }
}

// MARK: - Errors

/// Errors that can occur during TTS synthesis.
public enum TTSError: Error, LocalizedError {
    case textTooLong
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .textTooLong:
            return "Text exceeds maximum length of 5000 characters"
        case .invalidResponse:
            return "Invalid response from TTS service"
        case .apiError(let statusCode, let message):
            return "TTS API error \(statusCode): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
