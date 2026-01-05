import Foundation
import AIRoadTripToursCore

/// Orchestrates downloading and preparing offline tour packages.
///
/// Coordinates:
/// - Audio narration generation and caching
/// - Map tile downloading
/// - Package bundling and storage
/// - Progress tracking
@MainActor
public final class OfflineTourDownloadManager: ObservableObject {
    @Published public private(set) var activeDownloads: [UUID: DownloadProgress] = [:]

    private let audioCache: AudioCacheStorage
    private let packageStorage: OfflineTourPackageStorage
    private let networkMonitor: NetworkConnectivityMonitor

    /// Progress information for an active download.
    public struct DownloadProgress {
        public let tourId: UUID
        public let tourName: String
        public var overallProgress: Double // 0.0 to 1.0
        public var currentPhase: DownloadPhase
        public var audioProgress: Double
        public var mapProgress: Double
        public var downloadedSize: Int64
        public var totalSize: Int64
        public var error: Error?

        public init(
            tourId: UUID,
            tourName: String,
            overallProgress: Double = 0.0,
            currentPhase: DownloadPhase = .preparing,
            audioProgress: Double = 0.0,
            mapProgress: Double = 0.0,
            downloadedSize: Int64 = 0,
            totalSize: Int64 = 0,
            error: Error? = nil
        ) {
            self.tourId = tourId
            self.tourName = tourName
            self.overallProgress = overallProgress
            self.currentPhase = currentPhase
            self.audioProgress = audioProgress
            self.mapProgress = mapProgress
            self.downloadedSize = downloadedSize
            self.totalSize = totalSize
            self.error = error
        }
    }

    /// Phases of offline package download.
    public enum DownloadPhase: String {
        case preparing = "Preparing"
        case downloadingAudio = "Downloading Audio"
        case downloadingMaps = "Downloading Maps"
        case bundling = "Bundling Package"
        case completed = "Completed"
        case failed = "Failed"
    }

    public init(
        audioCache: AudioCacheStorage,
        packageStorage: OfflineTourPackageStorage,
        networkMonitor: NetworkConnectivityMonitor
    ) {
        self.audioCache = audioCache
        self.packageStorage = packageStorage
        self.networkMonitor = networkMonitor
    }

    // MARK: - Download Management

    /// Starts downloading offline tour package.
    ///
    /// - Parameters:
    ///   - route: Tour route to download
    ///   - requireWifi: Only download on WiFi connection
    /// - Throws: OfflineDownloadError if download cannot start
    public func downloadTourPackage(
        route: AudioTourRoute,
        requireWifi: Bool = true
    ) async throws {
        // Check network availability
        guard networkMonitor.isSuitableForDownloading(requireWifi: requireWifi) else {
            throw OfflineDownloadError.networkUnavailable
        }

        // Check if already downloading
        guard activeDownloads[route.id] == nil else {
            throw OfflineDownloadError.alreadyDownloading
        }

        // Check if already downloaded
        if packageStorage.isDownloaded(tourId: route.id) {
            throw OfflineDownloadError.alreadyDownloaded
        }

        // Initialize progress tracking
        let tourName = "\(route.origin.address ?? "Start") → \(route.destination.address ?? "End")"
        var progress = DownloadProgress(
            tourId: route.id,
            tourName: tourName
        )
        activeDownloads[route.id] = progress

        // Update metadata
        packageStorage.updateMetadata(OfflinePackageMetadata(
            tourId: route.id,
            tourName: tourName,
            status: .downloading
        ))

        do {
            // Phase 1: Download audio files
            progress.currentPhase = .downloadingAudio
            activeDownloads[route.id] = progress

            let audioFiles = try await downloadAudioFiles(route: route) { audioProgress in
                Task { @MainActor in
                    self.activeDownloads[route.id]?.audioProgress = audioProgress
                    self.activeDownloads[route.id]?.overallProgress = audioProgress * 0.7 // 70% of total
                }
            }

            // Phase 2: Download map tiles
            progress.currentPhase = .downloadingMaps
            activeDownloads[route.id] = progress

            let mapTiles = try await downloadMapTiles(route: route) { mapProgress in
                Task { @MainActor in
                    self.activeDownloads[route.id]?.mapProgress = mapProgress
                    self.activeDownloads[route.id]?.overallProgress = 0.7 + (mapProgress * 0.25) // 25% of total
                }
            }

            // Phase 3: Bundle package
            progress.currentPhase = .bundling
            activeDownloads[route.id] = progress

            let packageSize = audioFiles.reduce(Int64(0)) { $0 + $1.fileSize } + mapTiles.totalSize
            let package = OfflineTourPackage(
                route: route,
                audioFiles: audioFiles,
                mapTiles: mapTiles,
                packageSize: packageSize,
                expiresAt: Calendar.current.date(byAdding: .day, value: 90, to: Date())
            )

            try packageStorage.savePackage(package)

            // Phase 4: Complete
            progress.currentPhase = .completed
            progress.overallProgress = 1.0
            activeDownloads[route.id] = progress

            // Update metadata
            packageStorage.updateMetadata(OfflinePackageMetadata(
                tourId: route.id,
                tourName: tourName,
                status: .downloaded,
                downloadProgress: 1.0,
                totalSize: packageSize
            ))

            // Clean up active downloads
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.activeDownloads.removeValue(forKey: route.id)
            }

        } catch {
            // Handle failure
            progress.currentPhase = .failed
            progress.error = error
            activeDownloads[route.id] = progress

            packageStorage.updateMetadata(OfflinePackageMetadata(
                tourId: route.id,
                tourName: tourName,
                status: .failed,
                errorMessage: error.localizedDescription
            ))

            throw error
        }
    }

    /// Cancels active download for tour.
    public func cancelDownload(tourId: UUID) {
        activeDownloads.removeValue(forKey: tourId)

        if let metadata = packageStorage.getMetadata(tourId: tourId) {
            var updated = metadata
            updated.status = .notDownloaded
            updated.downloadProgress = 0.0
            packageStorage.updateMetadata(updated)
        }
    }

    /// Deletes downloaded offline package.
    public func deleteOfflinePackage(tourId: UUID) throws {
        try packageStorage.deletePackageForTour(tourId: tourId)
        try audioCache.deleteTourCache(tourId: tourId)
    }

    // MARK: - Private Methods

    /// Downloads audio files for all POIs in route.
    private func downloadAudioFiles(
        route: AudioTourRoute,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> [AudioFile] {
        var audioFiles: [AudioFile] = []
        let pois = route.pois
        let totalNarrations = pois.count * 3 // teaser, detailed, guidedTour per POI

        var completed = 0

        for poi in pois {
            // Generate narrations for each phase
            let phases: [NarrationPhase] = [.approaching, .detailed, .guidedTour]

            for phase in phases {
                // Placeholder: In real implementation, call TTS service
                // For now, simulate with delay
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

                // Create mock audio data (would come from TTS service)
                let mockAudioData = Data(repeating: 0, count: 50_000) // ~50KB

                // Cache audio
                let audioFile = try audioCache.cacheAudio(
                    mockAudioData,
                    tourId: route.id,
                    poiId: poi.poi.id,
                    phase: phase
                )

                audioFiles.append(audioFile)

                completed += 1
                progressHandler(Double(completed) / Double(totalNarrations))
            }
        }

        return audioFiles
    }

    /// Downloads map tiles for route.
    private func downloadMapTiles(
        route: AudioTourRoute,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> MapTileSet {
        // Calculate bounding box with buffer
        let boundingBox = GeoBoundingBox.fromRoute(route, bufferMiles: 5.0)

        // Zoom levels for road trips (12-16)
        let zoomLevels = [12, 13, 14, 15, 16]

        // Estimate tile count (rough approximation)
        let tileCount = estimateTileCount(boundingBox: boundingBox, zoomLevels: zoomLevels)

        // Simulate download progress
        for i in 0..<10 {
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            progressHandler(Double(i + 1) / 10.0)
        }

        // Placeholder: In real implementation, download actual tiles
        // For now, return mock data
        return MapTileSet(
            boundingBox: boundingBox,
            zoomLevels: zoomLevels,
            tileCount: tileCount,
            totalSize: Int64(tileCount * 15_000) // ~15KB per tile
        )
    }

    /// Estimates number of map tiles needed.
    private func estimateTileCount(boundingBox: GeoBoundingBox, zoomLevels: [Int]) -> Int {
        var total = 0

        for zoom in zoomLevels {
            let tilesPerDegree = pow(2.0, Double(zoom)) / 360.0
            let latSpan = boundingBox.northeast.latitude - boundingBox.southwest.latitude
            let lonSpan = boundingBox.northeast.longitude - boundingBox.southwest.longitude

            let tilesWide = Int(ceil(lonSpan * tilesPerDegree))
            let tilesHigh = Int(ceil(latSpan * tilesPerDegree))

            total += tilesWide * tilesHigh
        }

        return total
    }
}

// MARK: - Errors

/// Errors that can occur during offline package downloads.
public enum OfflineDownloadError: Error, LocalizedError {
    case networkUnavailable
    case alreadyDownloading
    case alreadyDownloaded
    case audioGenerationFailed(String)
    case mapDownloadFailed(String)
    case storageFailed(String)

    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network connection unavailable. Connect to WiFi to download offline packages."
        case .alreadyDownloading:
            return "This tour is already being downloaded."
        case .alreadyDownloaded:
            return "This tour has already been downloaded for offline use."
        case .audioGenerationFailed(let message):
            return "Audio generation failed: \(message)"
        case .mapDownloadFailed(let message):
            return "Map download failed: \(message)"
        case .storageFailed(let message):
            return "Storage failed: \(message)"
        }
    }
}
