import Foundation
import AIRoadTripToursCore

/// Manages persistent storage of offline tour packages and metadata.
///
/// Stores complete tour packages in the Documents directory for permanent persistence.
/// All data survives app restarts and system reboots.
@MainActor
public final class OfflineTourPackageStorage {
    private let fileManager: FileManager
    private let packagesDirectory: URL
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let offlinePackages = "offlinePackages"
        static let packageMetadata = "offlinePackageMetadata"
    }

    public init(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard
    ) throws {
        self.fileManager = fileManager
        self.userDefaults = userDefaults

        // Use Documents directory for persistent storage
        let documentsDir = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        self.packagesDirectory = documentsDir.appendingPathComponent("OfflineTours", isDirectory: true)

        // Create directory if needed
        if !fileManager.fileExists(atPath: packagesDirectory.path) {
            try fileManager.createDirectory(
                at: packagesDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Package Management

    /// Saves offline tour package to persistent storage.
    public func savePackage(_ package: OfflineTourPackage) throws {
        // Create package subdirectory
        let packageDir = packagesDirectory.appendingPathComponent(package.id.uuidString, isDirectory: true)
        if !fileManager.fileExists(atPath: packageDir.path) {
            try fileManager.createDirectory(at: packageDir, withIntermediateDirectories: true)
        }

        // Save package metadata
        let metadataURL = packageDir.appendingPathComponent("package.json")
        let data = try encoder.encode(package)
        try data.write(to: metadataURL, options: .atomic)

        // Update metadata index
        var allMetadata = loadAllMetadata()
        if let index = allMetadata.firstIndex(where: { $0.tourId == package.route.id }) {
            allMetadata[index].status = .downloaded
            allMetadata[index].downloadProgress = 1.0
            allMetadata[index].updatedAt = Date()
        } else {
            allMetadata.append(OfflinePackageMetadata(
                tourId: package.route.id,
                tourName: "\(package.route.origin.address ?? "Start") → \(package.route.destination.address ?? "End")",
                status: .downloaded,
                downloadProgress: 1.0,
                downloadedSize: package.packageSize,
                totalSize: package.packageSize
            ))
        }
        saveAllMetadata(allMetadata)
    }

    /// Loads offline tour package from storage.
    public func loadPackage(id: UUID) throws -> OfflineTourPackage? {
        let packageDir = packagesDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        let metadataURL = packageDir.appendingPathComponent("package.json")

        guard fileManager.fileExists(atPath: metadataURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: metadataURL)
        return try decoder.decode(OfflineTourPackage.self, from: data)
    }

    /// Loads package by tour ID.
    public func loadPackageForTour(tourId: UUID) throws -> OfflineTourPackage? {
        let packages = try loadAllPackages()
        return packages.first { $0.route.id == tourId }
    }

    /// Loads all offline tour packages.
    public func loadAllPackages() throws -> [OfflineTourPackage] {
        let contents = try fileManager.contentsOfDirectory(
            at: packagesDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )

        var packages: [OfflineTourPackage] = []

        for packageDir in contents where packageDir.hasDirectoryPath {
            if let packageId = UUID(uuidString: packageDir.lastPathComponent),
               let package = try loadPackage(id: packageId) {
                packages.append(package)
            }
        }

        return packages
    }

    /// Deletes offline tour package.
    public func deletePackage(id: UUID) throws {
        let packageDir = packagesDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        if fileManager.fileExists(atPath: packageDir.path) {
            try fileManager.removeItem(at: packageDir)
        }

        // Update metadata
        var allMetadata = loadAllMetadata()
        allMetadata.removeAll { metadata in
            guard let package = try? loadPackage(id: id) else { return false }
            return metadata.tourId == package.route.id
        }
        saveAllMetadata(allMetadata)
    }

    /// Deletes package by tour ID.
    public func deletePackageForTour(tourId: UUID) throws {
        let packages = try loadAllPackages()
        if let package = packages.first(where: { $0.route.id == tourId }) {
            try deletePackage(id: package.id)
        }
    }

    /// Checks if package is downloaded for tour.
    public func isDownloaded(tourId: UUID) -> Bool {
        let packages = (try? loadAllPackages()) ?? []
        return packages.contains { $0.route.id == tourId }
    }

    // MARK: - Metadata Management

    /// Loads all offline package metadata.
    public func loadAllMetadata() -> [OfflinePackageMetadata] {
        guard let data = userDefaults.data(forKey: Keys.packageMetadata) else {
            return []
        }

        do {
            return try decoder.decode([OfflinePackageMetadata].self, from: data)
        } catch {
            print("Error loading offline package metadata: \(error)")
            return []
        }
    }

    /// Saves all offline package metadata.
    public func saveAllMetadata(_ metadata: [OfflinePackageMetadata]) {
        do {
            let data = try encoder.encode(metadata)
            userDefaults.set(data, forKey: Keys.packageMetadata)
        } catch {
            print("Error saving offline package metadata: \(error)")
        }
    }

    /// Updates metadata for specific tour.
    public func updateMetadata(_ metadata: OfflinePackageMetadata) {
        var allMetadata = loadAllMetadata()
        if let index = allMetadata.firstIndex(where: { $0.tourId == metadata.tourId }) {
            allMetadata[index] = metadata
        } else {
            allMetadata.append(metadata)
        }
        saveAllMetadata(allMetadata)
    }

    /// Gets metadata for specific tour.
    public func getMetadata(tourId: UUID) -> OfflinePackageMetadata? {
        return loadAllMetadata().first { $0.tourId == tourId }
    }

    // MARK: - Storage Management

    /// Calculates total storage used by offline packages.
    public func calculateTotalStorage() throws -> Int64 {
        let contents = try fileManager.contentsOfDirectory(
            at: packagesDirectory,
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

    /// Cleans up expired packages.
    public func cleanupExpiredPackages() throws {
        let packages = try loadAllPackages()
        for package in packages where package.isExpired {
            try deletePackage(id: package.id)
        }
    }

    /// Deletes all offline packages.
    public func clearAll() throws {
        if fileManager.fileExists(atPath: packagesDirectory.path) {
            try fileManager.removeItem(at: packagesDirectory)
            try fileManager.createDirectory(at: packagesDirectory, withIntermediateDirectories: true)
        }

        // Clear metadata
        userDefaults.removeObject(forKey: Keys.packageMetadata)
    }

    // MARK: - Statistics

    /// Gets storage statistics for offline packages.
    public struct StorageStatistics {
        public let totalPackages: Int
        public let totalSize: Int64
        public let downloadedPackages: Int
        public let failedPackages: Int
        public let expiredPackages: Int

        public var formattedSize: String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useGB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: totalSize)
        }
    }

    /// Computes storage statistics.
    public func getStatistics() throws -> StorageStatistics {
        let packages = try loadAllPackages()
        let metadata = loadAllMetadata()
        let totalSize = try calculateTotalStorage()

        return StorageStatistics(
            totalPackages: packages.count,
            totalSize: totalSize,
            downloadedPackages: metadata.filter { $0.status == .downloaded }.count,
            failedPackages: metadata.filter { $0.status == .failed }.count,
            expiredPackages: packages.filter { $0.isExpired }.count
        )
    }
}
