import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices

/// View for managing offline tour downloads for mountain touring without cell service.
public struct OfflineDownloadsView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var downloadManager: OfflineTourDownloadManager
    @StateObject private var networkMonitor: NetworkConnectivityMonitor
    @State private var showingStorageStats = false
    @State private var downloadError: Error?
    @State private var showingError = false

    public init(
        downloadManager: OfflineTourDownloadManager,
        networkMonitor: NetworkConnectivityMonitor
    ) {
        _downloadManager = StateObject(wrappedValue: downloadManager)
        _networkMonitor = StateObject(wrappedValue: networkMonitor)
    }

    public var body: some View {
        List {
            // Network status section
            Section {
                HStack {
                    Image(systemName: networkMonitor.isConnected ? "wifi" : "wifi.slash")
                        .foregroundStyle(networkMonitor.isConnected ? .green : .red)

                    VStack(alignment: .leading) {
                        Text(networkMonitor.isConnected ? "Online" : "Offline")
                            .font(.headline)

                        if networkMonitor.isConnected {
                            Text(connectionTypeText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if networkMonitor.isConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            } header: {
                Text("Network Status")
            }

            // Storage statistics
            Section {
                Button {
                    showingStorageStats = true
                } label: {
                    HStack {
                        Label("Storage Usage", systemImage: "internaldrive")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Active downloads
            if !downloadManager.activeDownloads.isEmpty {
                Section {
                    ForEach(Array(downloadManager.activeDownloads.values), id: \.tourId) { progress in
                        DownloadProgressCard(progress: progress) {
                            downloadManager.cancelDownload(tourId: progress.tourId)
                        }
                    }
                } header: {
                    Text("Active Downloads")
                }
            }

            // Available tours to download
            Section {
                if appState.savedTours.isEmpty {
                    ContentUnavailableView(
                        "No Tours Available",
                        systemImage: "map",
                        description: Text("Create a tour to download it for offline use")
                    )
                } else {
                    ForEach(appState.savedTours, id: \.id) { tour in
                        OfflineTourRow(
                            tour: tour,
                            isDownloaded: isDownloaded(tour.id),
                            isDownloading: downloadManager.activeDownloads[tour.id] != nil,
                            networkAvailable: networkMonitor.isSuitableForDownloading()
                        ) {
                            // Download action
                            Task {
                                do {
                                    // Convert Tour to AudioTourRoute
                                    let route = await convertToAudioTourRoute(tour)
                                    try await downloadManager.downloadTourPackage(route: route)
                                } catch {
                                    downloadError = error
                                    showingError = true
                                }
                            }
                        } deleteAction: {
                            // Delete action
                            Task {
                                do {
                                    try downloadManager.deleteOfflinePackage(tourId: tour.id)
                                } catch {
                                    downloadError = error
                                    showingError = true
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Available Tours")
            } footer: {
                Text("Download tours for offline use in areas without cell service. Audio narrations and maps are cached locally.")
            }
        }
        .navigationTitle("Offline Downloads")
        .sheet(isPresented: $showingStorageStats) {
            StorageStatisticsView(packageStorage: appState.offlinePackageStorage)
        }
        .alert("Download Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            if let error = downloadError {
                Text(error.localizedDescription)
            }
        }
    }

    private var connectionTypeText: String {
        switch networkMonitor.connectionType {
        case .wifi: return "WiFi - Ready for downloads"
        case .cellular: return "Cellular - Connect to WiFi for downloads"
        case .wired: return "Wired - Ready for downloads"
        case .unavailable: return "No connection"
        }
    }

    private func isDownloaded(_ tourId: UUID) -> Bool {
        return appState.offlinePackageStorage.isDownloaded(tourId: tourId)
    }

    private func convertToAudioTourRoute(_ tour: Tour) async -> AudioTourRoute {
        // Placeholder: Convert Tour to AudioTourRoute
        // In real implementation, enrich POIs and build route segments
        return AudioTourRoute(
            origin: GeoLocation(latitude: 0, longitude: 0),
            destination: GeoLocation(latitude: 0, longitude: 0),
            waypoints: [],
            segments: [],
            totalDistance: 0,
            estimatedDuration: 0,
            pois: []
        )
    }
}

/// Card showing download progress.
struct DownloadProgressCard: View {
    let progress: OfflineTourDownloadManager.DownloadProgress
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(progress.tourName)
                        .font(.headline)

                    Text(progress.currentPhase.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: progress.overallProgress) {
                Text("\(Int(progress.overallProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Audio: \(Int(progress.audioProgress * 100))%", systemImage: "waveform")
                Spacer()
                Label("Maps: \(Int(progress.mapProgress * 100))%", systemImage: "map")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding()
        #if os(iOS)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Row for offline tour with download/delete actions.
struct OfflineTourRow: View {
    let tour: Tour
    let isDownloaded: Bool
    let isDownloading: Bool
    let networkAvailable: Bool
    let downloadAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(tour.name)
                    .font(.headline)

                if let description = tour.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if isDownloaded {
                Button {
                    deleteAction()
                } label: {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.red)
                }
            } else if isDownloading {
                ProgressView()
            } else {
                Button {
                    downloadAction()
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                        .labelStyle(.iconOnly)
                }
                .disabled(!networkAvailable)
            }
        }
    }
}

/// View showing storage statistics.
struct StorageStatisticsView: View {
    let packageStorage: OfflineTourPackageStorage
    @Environment(\.dismiss) private var dismiss
    @State private var stats: OfflineTourPackageStorage.StorageStatistics?

    var body: some View {
        NavigationStack {
            List {
                if let stats = stats {
                    Section {
                        LabeledContent("Total Packages", value: "\(stats.totalPackages)")
                        LabeledContent("Total Size", value: stats.formattedSize)
                        LabeledContent("Downloaded", value: "\(stats.downloadedPackages)")
                        LabeledContent("Failed", value: "\(stats.failedPackages)")
                        LabeledContent("Expired", value: "\(stats.expiredPackages)")
                    } header: {
                        Text("Storage Statistics")
                    }

                    Section {
                        Button("Clear Expired Packages") {
                            Task {
                                try? packageStorage.cleanupExpiredPackages()
                                loadStats()
                            }
                        }

                        Button("Clear All Offline Data", role: .destructive) {
                            Task {
                                try? packageStorage.clearAll()
                                loadStats()
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Storage")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                loadStats()
            }
        }
    }

    private func loadStats() {
        Task {
            stats = try? packageStorage.getStatistics()
        }
    }
}
