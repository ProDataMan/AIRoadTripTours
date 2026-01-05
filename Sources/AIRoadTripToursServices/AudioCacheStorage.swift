import Foundation
import AIRoadTripToursCore

/// Manages caching and retrieval of pre-generated audio narration files for offline playback.
///
/// Audio files are stored in the app's cache directory with organized subdirectories per tour.
/// This service handles:
/// - Downloading audio from TTS service
/// - Caching to local storage
/// - Retrieving cached audio
/// - Cleanup of expired/unused audio files
@MainActor
public final class AudioCacheStorage {
    private let fileManager: FileManager
    private let cacheDirectory: URL

    /// Maximum cache size in bytes (500 MB default).
    public var maxCacheSize: Int64 = 500 * 1024 * 1024

    public init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager

        // Use Documents directory for persistent storage (won't be purged by system)
        let documentsDir = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        self.cacheDirectory = documentsDir.appendingPathComponent("AudioCache", isDirectory: true)

        // Create audio cache directory if needed
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try fileManager.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    // MARK: - Caching

    /// Caches audio data for a specific POI narration.
    ///
    /// - Parameters:
    ///   - audioData: Raw audio file data
    ///   - tourId: Tour identifier
    ///   - poiId: POI identifier
    ///   - phase: Narration phase
    ///   - format: Audio format
    /// - Returns: AudioFile metadata for cached file
    public func cacheAudio(
        _ audioData: Data,
        tourId: UUID,
        poiId: UUID,
        phase: NarrationPhase,
        format: AudioFormat = .aac
    ) throws -> AudioFile {
        // Create tour subdirectory
        let tourDir = cacheDirectory.appendingPathComponent(tourId.uuidString, isDirectory: true)
        if !fileManager.fileExists(atPath: tourDir.path) {
            try fileManager.createDirectory(at: tourDir, withIntermediateDirectories: true)
        }

        // Generate filename: {poiId}_{phase}.{extension}
        let filename = "\(poiId.uuidString)_\(phase.rawValue).\(format.fileExtension)"
        let fileURL = tourDir.appendingPathComponent(filename)

        // Write audio data
        try audioData.write(to: fileURL, options: .atomic)

        // Get audio duration (basic estimation based on format)
        let duration = estimateAudioDuration(audioData, format: format)

        return AudioFile(
            poiId: poiId,
            phase: phase,
            localURL: fileURL,
            duration: duration,
            fileSize: Int64(audioData.count),
            format: format
        )
    }

    /// Retrieves cached audio file for POI narration.
    ///
    /// - Parameters:
    ///   - tourId: Tour identifier
    ///   - poiId: POI identifier
    ///   - phase: Narration phase
    /// - Returns: AudioFile if cached, nil otherwise
    public func getCachedAudio(
        tourId: UUID,
        poiId: UUID,
        phase: NarrationPhase
    ) -> AudioFile? {
        let tourDir = cacheDirectory.appendingPathComponent(tourId.uuidString, isDirectory: true)

        // Try each format
        for format in [AudioFormat.aac, .mp3, .opus] {
            let filename = "\(poiId.uuidString)_\(phase.rawValue).\(format.fileExtension)"
            let fileURL = tourDir.appendingPathComponent(filename)

            if fileManager.fileExists(atPath: fileURL.path) {
                // Get file attributes
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let fileSize = attributes[.size] as? Int64 {

                    let duration = estimateAudioDuration(fileSize: fileSize, format: format)

                    return AudioFile(
                        poiId: poiId,
                        phase: phase,
                        localURL: fileURL,
                        duration: duration,
                        fileSize: fileSize,
                        format: format
                    )
                }
            }
        }

        return nil
    }

    /// Checks if audio is cached for specific narration.
    public func isCached(tourId: UUID, poiId: UUID, phase: NarrationPhase) -> Bool {
        return getCachedAudio(tourId: tourId, poiId: poiId, phase: phase) != nil
    }

    // MARK: - Cleanup

    /// Deletes all cached audio for a specific tour.
    public func deleteTourCache(tourId: UUID) throws {
        let tourDir = cacheDirectory.appendingPathComponent(tourId.uuidString, isDirectory: true)
        if fileManager.fileExists(atPath: tourDir.path) {
            try fileManager.removeItem(at: tourDir)
        }
    }

    /// Deletes all cached audio files.
    public func clearAllCache() throws {
        if fileManager.fileExists(atPath: cacheDirectory.path) {
            try fileManager.removeItem(at: cacheDirectory)
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    /// Removes expired cached audio to free space.
    ///
    /// - Parameter maxAge: Maximum age in days (default 30)
    public func cleanupExpiredCache(maxAge: Int = 30) throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -maxAge, to: Date())!

        let contents = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )

        for tourDir in contents where tourDir.hasDirectoryPath {
            if let attributes = try? fileManager.attributesOfItem(atPath: tourDir.path),
               let modDate = attributes[.modificationDate] as? Date,
               modDate < cutoffDate {
                try fileManager.removeItem(at: tourDir)
            }
        }
    }

    /// Enforces maximum cache size by deleting oldest files.
    public func enforceCacheLimit() throws {
        let currentSize = try calculateCacheSize()

        guard currentSize > maxCacheSize else { return }

        // Get all tour directories with modification dates
        let contents = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .totalFileSizeKey],
            options: .skipsHiddenFiles
        )

        // Sort by modification date (oldest first)
        let sorted = contents.sorted { url1, url2 in
            guard let date1 = try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                  let date2 = try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                return false
            }
            return date1 < date2
        }

        var sizeFreed: Int64 = 0
        for url in sorted {
            if let size = try? url.resourceValues(forKeys: [.totalFileSizeKey]).totalFileSize {
                try fileManager.removeItem(at: url)
                sizeFreed += Int64(size)

                if currentSize - sizeFreed <= maxCacheSize {
                    break
                }
            }
        }
    }

    // MARK: - Utilities

    /// Calculates total size of audio cache in bytes.
    public func calculateCacheSize() throws -> Int64 {
        let contents = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.totalFileSizeKey],
            options: .skipsHiddenFiles
        )

        var totalSize: Int64 = 0
        for url in contents {
            if let size = try? url.resourceValues(forKeys: [.totalFileSizeKey]).totalFileSize {
                totalSize += Int64(size)
            }
        }

        return totalSize
    }

    /// Gets all cached tours with file counts.
    public func getCachedTours() -> [(tourId: UUID, fileCount: Int, totalSize: Int64)] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.totalFileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        var result: [(UUID, Int, Int64)] = []

        for tourDir in contents where tourDir.hasDirectoryPath {
            if let tourId = UUID(uuidString: tourDir.lastPathComponent) {
                let files = (try? fileManager.contentsOfDirectory(at: tourDir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
                let fileCount = files.count
                let totalSize = files.reduce(Int64(0)) { sum, url in
                    let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    return sum + Int64(size)
                }
                result.append((tourId, fileCount, totalSize))
            }
        }

        return result
    }

    // MARK: - Private Methods

    /// Estimates audio duration based on file size and format.
    private func estimateAudioDuration(fileSize: Int64, format: AudioFormat) -> TimeInterval {
        // Approximate bitrates (kbps)
        let bitrate: Double = switch format {
        case .aac: 128
        case .mp3: 192
        case .opus: 96
        }

        // Duration = (fileSize in bits) / (bitrate * 1000)
        let fileSizeInBits = Double(fileSize) * 8.0
        return fileSizeInBits / (bitrate * 1000.0)
    }

    /// Estimates audio duration from audio data.
    private func estimateAudioDuration(_ audioData: Data, format: AudioFormat) -> TimeInterval {
        return estimateAudioDuration(fileSize: Int64(audioData.count), format: format)
    }
}
