import Foundation
import AVFoundation

/// Enhanced voice configuration with high-quality voice selection.
@available(iOS 17.0, macOS 14.0, *)
public struct VoiceConfiguration {

    /// Available voice quality tiers
    public enum VoiceQuality: String, CaseIterable, Codable {
        case enhanced = "Enhanced"
        case premium = "Premium"
        case standard = "Standard"

        var description: String {
            switch self {
            case .enhanced:
                return "Enhanced Quality (Recommended) - Natural sounding, downloaded voices"
            case .premium:
                return "Premium Quality - Highest quality, larger download"
            case .standard:
                return "Standard - Built-in, no download required"
            }
        }
    }

    /// Get the best available voice for narration
    public static func getBestVoice(language: String = "en-US", quality: VoiceQuality = .enhanced) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()

        // Filter by language
        let languageVoices = voices.filter { $0.language == language }

        switch quality {
        case .premium:
            // Look for premium voices (highest quality)
            let premiumVoices = languageVoices.filter { voice in
                voice.quality == .premium
            }
            if let voice = premiumVoices.first {
                return voice
            }
            fallthrough // Try enhanced if premium not available

        case .enhanced:
            // Look for enhanced voices (very good quality)
            let enhancedVoices = languageVoices.filter { voice in
                voice.quality == .enhanced
            }
            if let voice = enhancedVoices.first {
                return voice
            }
            fallthrough // Try default if enhanced not available

        case .standard:
            // Use default voice
            let defaultVoice = AVSpeechSynthesisVoice(language: language)
            return defaultVoice
        }
    }

    /// Get recommended voices for different regions
    public static func getRecommendedVoice(for language: String) -> (voice: AVSpeechSynthesisVoice?, name: String) {
        let recommendations: [String: String] = [
            "en-US": "Samantha",      // US English - Natural female voice
            "en-GB": "Daniel",        // British English - Natural male voice
            "en-AU": "Karen",         // Australian English - Natural female voice
            "en-IE": "Moira",         // Irish English - Natural female voice
            "es-ES": "Monica",        // Spanish - Natural female voice
            "fr-FR": "Thomas",        // French - Natural male voice
            "de-DE": "Anna",          // German - Natural female voice
            "it-IT": "Alice",         // Italian - Natural female voice
            "ja-JP": "Kyoko",         // Japanese - Natural female voice
            "zh-CN": "Ting-Ting",     // Chinese - Natural female voice
        ]

        let recommendedName = recommendations[language] ?? "Samantha"

        // Try to find the recommended voice
        let voices = AVSpeechSynthesisVoice.speechVoices()
        if let recommendedVoice = voices.first(where: { $0.name == recommendedName && $0.language == language }) {
            return (recommendedVoice, recommendedName)
        }

        // Fallback to best available
        return (getBestVoice(language: language), recommendedName)
    }

    /// List all available voices for a language
    public static func listAvailableVoices(for language: String = "en-US") {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let filtered = voices.filter { $0.language == language }

        print("\n📋 Available voices for \(language):")
        print("=" * 50)

        for voice in filtered {
            let qualityIcon = switch voice.quality {
            case .enhanced: "⭐️⭐️"
            case .premium: "⭐️⭐️⭐️"
            case .default: "⭐️"
            @unknown default: "❓"
            }

            print("\(qualityIcon) \(voice.name)")
            print("   Language: \(voice.language)")
            print("   Quality: \(voice.quality.rawValue)")
            print("   Identifier: \(voice.identifier)")
            print("")
        }

        print("Total: \(filtered.count) voices")
        print("=" * 50)
    }

    /// Instructions for downloading better voices
    public static func getVoiceDownloadInstructions() -> String {
        return """

        HOW TO GET BETTER FREE VOICES ON iOS/macOS:

        🎤 RECOMMENDED: Enhanced Quality Voices (FREE)

        iOS/iPadOS:
        1. Open Settings app
        2. Go to Accessibility → Spoken Content
        3. Tap "Voices"
        4. Select "English (or your language)"
        5. Download "Enhanced Quality" voices:
           - Samantha (US Female) - Most natural ⭐️⭐️
           - Aaron (US Male) - Clear and professional
           - Nicky (US Female) - Younger, energetic
           - Zoe (US Female) - Warm and friendly

        macOS:
        1. Open System Settings
        2. Go to Accessibility → Spoken Content
        3. Click "System Voice" dropdown
        4. Select "Customize..."
        5. Download Enhanced Quality voices (listed above)

        🌟 BEST FREE VOICES (US English):
        1. Samantha (Enhanced) - Natural, conversational
        2. Aaron (Enhanced) - Professional, clear
        3. Nicky (Enhanced) - Friendly, upbeat

        🌍 OTHER LANGUAGES:
        - British: Daniel (Enhanced)
        - Australian: Karen (Enhanced)
        - Irish: Moira (Enhanced)

        💾 DOWNLOAD SIZE:
        - Enhanced Quality: ~150-300 MB per voice
        - Premium Quality: ~500 MB - 1 GB per voice

        ⚡️ PERFORMANCE:
        - Enhanced voices work offline after download
        - No internet required during tour
        - Better pronunciation and intonation
        - More natural pauses and emphasis

        🎯 APP WILL AUTOMATICALLY USE BEST AVAILABLE VOICE
        After downloading, the app will detect and use the
        highest quality voice you have installed.

        """
    }
}

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
