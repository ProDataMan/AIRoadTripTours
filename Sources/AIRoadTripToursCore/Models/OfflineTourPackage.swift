import Foundation

/// Offline tour package containing all data needed for mountain touring without cell service.
///
/// This package bundles tour route data, enriched POI information, pre-generated audio narrations,
/// and map tiles for complete offline functionality.
public struct OfflineTourPackage: Codable, Sendable, Identifiable {
    public let id: UUID
    public let route: AudioTourRoute
    public let audioFiles: [AudioFile]
    public let mapTiles: MapTileSet
    public let packageSize: Int64 // bytes
    public let createdAt: Date
    public let expiresAt: Date? // for automatic cleanup of stale packages

    public init(
        id: UUID = UUID(),
        route: AudioTourRoute,
        audioFiles: [AudioFile],
        mapTiles: MapTileSet,
        packageSize: Int64,
        createdAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.route = route
        self.audioFiles = audioFiles
        self.mapTiles = mapTiles
        self.packageSize = packageSize
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    /// Returns true if package has expired and should be refreshed.
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    /// Returns formatted package size string (e.g., "45.2 MB").
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: packageSize)
    }
}

/// Represents a pre-generated audio narration file.
public struct AudioFile: Codable, Sendable, Identifiable {
    public let id: UUID
    public let poiId: UUID
    public let phase: NarrationPhase
    public let localURL: URL // file:// URL to cached audio
    public let duration: TimeInterval
    public let fileSize: Int64
    public let format: AudioFormat

    public init(
        id: UUID = UUID(),
        poiId: UUID,
        phase: NarrationPhase,
        localURL: URL,
        duration: TimeInterval,
        fileSize: Int64,
        format: AudioFormat = .aac
    ) {
        self.id = id
        self.poiId = poiId
        self.phase = phase
        self.localURL = localURL
        self.duration = duration
        self.fileSize = fileSize
        self.format = format
    }
}

/// Audio file formats supported for offline caching.
public enum AudioFormat: String, Codable, Sendable {
    case aac = "aac"
    case mp3 = "mp3"
    case opus = "opus"

    /// File extension for this format.
    public var fileExtension: String {
        switch self {
        case .aac: return "m4a"
        case .mp3: return "mp3"
        case .opus: return "opus"
        }
    }
}

/// Metadata for cached map tiles covering a tour route.
public struct MapTileSet: Codable, Sendable {
    /// Bounding box covering the tour route with buffer.
    public let boundingBox: GeoBoundingBox

    /// Zoom levels cached (typically 12-16 for road trips).
    public let zoomLevels: [Int]

    /// Total number of tiles cached.
    public let tileCount: Int

    /// Total size of all cached tiles.
    public let totalSize: Int64

    /// When tiles were downloaded.
    public let cachedAt: Date

    public init(
        boundingBox: GeoBoundingBox,
        zoomLevels: [Int],
        tileCount: Int,
        totalSize: Int64,
        cachedAt: Date = Date()
    ) {
        self.boundingBox = boundingBox
        self.zoomLevels = zoomLevels
        self.tileCount = tileCount
        self.totalSize = totalSize
        self.cachedAt = cachedAt
    }
}

/// Geographic bounding box defined by southwest and northeast corners.
public struct GeoBoundingBox: Codable, Sendable {
    public let southwest: GeoLocation
    public let northeast: GeoLocation

    public init(southwest: GeoLocation, northeast: GeoLocation) {
        self.southwest = southwest
        self.northeast = northeast
    }

    /// Creates bounding box from route with specified buffer in miles.
    public static func fromRoute(_ route: AudioTourRoute, bufferMiles: Double = 5.0) -> GeoBoundingBox {
        let allLocations = [route.origin, route.destination] + route.waypoints

        var minLat = allLocations[0].latitude
        var maxLat = allLocations[0].latitude
        var minLon = allLocations[0].longitude
        var maxLon = allLocations[0].longitude

        for location in allLocations {
            minLat = min(minLat, location.latitude)
            maxLat = max(maxLat, location.latitude)
            minLon = min(minLon, location.longitude)
            maxLon = max(maxLon, location.longitude)
        }

        // Add buffer (approximate: 1 degree ≈ 69 miles)
        let latBuffer = bufferMiles / 69.0
        let lonBuffer = bufferMiles / 69.0

        return GeoBoundingBox(
            southwest: GeoLocation(
                latitude: minLat - latBuffer,
                longitude: minLon - lonBuffer
            ),
            northeast: GeoLocation(
                latitude: maxLat + latBuffer,
                longitude: maxLon + lonBuffer
            )
        )
    }

    /// Returns true if location is within bounding box.
    public func contains(_ location: GeoLocation) -> Bool {
        return location.latitude >= southwest.latitude &&
               location.latitude <= northeast.latitude &&
               location.longitude >= southwest.longitude &&
               location.longitude <= northeast.longitude
    }
}

/// Download status for offline tour package.
public enum OfflinePackageStatus: String, Codable, Sendable {
    case notDownloaded = "Not Downloaded"
    case downloading = "Downloading"
    case downloaded = "Downloaded"
    case failed = "Failed"
    case expired = "Expired"
}

/// Metadata tracking offline package download progress.
public struct OfflinePackageMetadata: Codable, Sendable, Identifiable {
    public let id: UUID
    public let tourId: UUID
    public let tourName: String
    public var status: OfflinePackageStatus
    public var downloadProgress: Double // 0.0 to 1.0
    public var downloadedSize: Int64
    public var totalSize: Int64
    public var errorMessage: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        tourId: UUID,
        tourName: String,
        status: OfflinePackageStatus = .notDownloaded,
        downloadProgress: Double = 0.0,
        downloadedSize: Int64 = 0,
        totalSize: Int64 = 0,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.tourId = tourId
        self.tourName = tourName
        self.status = status
        self.downloadProgress = downloadProgress
        self.downloadedSize = downloadedSize
        self.totalSize = totalSize
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
