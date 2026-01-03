import Foundation
#if canImport(UIKit)
import AVFoundation
import UIKit
import MediaPlayer
#else
import AVFoundation
#endif
import AIRoadTripToursCore

#if canImport(UIKit)
/// AVSpeechSynthesizer-based narration audio service.
///
/// Uses Apple's built-in text-to-speech engine for offline audio synthesis.
/// Supports high-quality neural voices on iOS 16+.
@MainActor
public final class AVSpeechNarrationAudioService: NSObject, NarrationAudioService {
    private let synthesizer: AVSpeechSynthesizer
    private var currentUtterance: AVSpeechUtterance?
    private var _currentNarration: Narration?
    private var _playbackState: NarrationPlaybackState = .idle

    /// Voice to use for synthesis (defaults to system default).
    public var voice: AVSpeechSynthesisVoice?

    /// Speech rate (0.0 = slowest, 1.0 = fastest, default 0.5).
    public var rate: Float = AVSpeechUtteranceDefaultSpeechRate

    /// Pitch multiplier (0.5 = lower, 2.0 = higher, default 1.0).
    public var pitchMultiplier: Float = 1.0

    /// Volume (0.0 = silent, 1.0 = maximum, default 1.0).
    public var volume: Float = 1.0

    public override init() {
        self.synthesizer = AVSpeechSynthesizer()
        super.init()
        self.synthesizer.delegate = self
        setupRemoteCommands()
    }

    public func prepare(_ narration: Narration) async throws {
        guard _playbackState != .playing else {
            throw NarrationAudioError.playbackFailure("Cannot prepare while playing")
        }

        _playbackState = .preparing
        _currentNarration = narration
        currentUtterance = createUtterance(for: narration)
        _playbackState = .idle
    }

    public func play(_ narration: Narration) async throws {
        // Stop any current playback
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Configure audio session for background playback
        try configureAudioSession()

        // Create and speak utterance
        _currentNarration = narration
        let utterance = createUtterance(for: narration)
        currentUtterance = utterance

        // Update lock screen / control center
        updateNowPlayingInfo(for: narration)

        _playbackState = .playing
        synthesizer.speak(utterance)
    }

    public func pause() async {
        guard _playbackState == .playing else { return }
        synthesizer.pauseSpeaking(at: .word)
        _playbackState = .paused
    }

    public func resume() async {
        guard _playbackState == .paused else { return }
        synthesizer.continueSpeaking()
        _playbackState = .playing
    }

    public func stop() async {
        synthesizer.stopSpeaking(at: .immediate)
        _playbackState = .idle
        _currentNarration = nil
        currentUtterance = nil
    }

    public var playbackState: NarrationPlaybackState {
        get async { _playbackState }
    }

    public var currentNarration: Narration? {
        get async { _currentNarration }
    }

    // MARK: - Private Methods

    private func createUtterance(for narration: Narration) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: narration.content)
        utterance.voice = voice ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate
        utterance.pitchMultiplier = pitchMultiplier
        utterance.volume = volume
        return utterance
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            // Use .playback category to enable background audio
            // .mixWithOthers allows other audio to play alongside
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            throw NarrationAudioError.audioSessionFailure(error.localizedDescription)
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play command
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.resume()
            }
            return .success
        }

        // Pause command
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pause()
            }
            return .success
        }

        // Stop command
        commandCenter.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.stop()
            }
            return .success
        }

        // Enable the commands
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.stopCommand.isEnabled = true
    }

    private func updateNowPlayingInfo(for narration: Narration) {
        var nowPlayingInfo = [String: Any]()

        nowPlayingInfo[MPMediaItemPropertyTitle] = narration.poiName
        nowPlayingInfo[MPMediaItemPropertyArtist] = "AI Road Trip Tours"
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = false

        // Estimated duration (based on word count and speech rate)
        let wordCount = narration.content.split(separator: " ").count
        let estimatedDuration = Double(wordCount) / 150.0 * 60.0 // ~150 words per minute
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = estimatedDuration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AVSpeechNarrationAudioService: AVSpeechSynthesizerDelegate {
    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            _playbackState = .playing
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            _playbackState = .completed
            _currentNarration = nil
            currentUtterance = nil
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didPause utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            _playbackState = .paused
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didContinue utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            _playbackState = .playing
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            _playbackState = .idle
            _currentNarration = nil
            currentUtterance = nil
        }
    }
}
#endif
