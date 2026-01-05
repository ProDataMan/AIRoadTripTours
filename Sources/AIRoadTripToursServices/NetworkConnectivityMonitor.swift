import Foundation
import Network

/// Monitors network connectivity status for offline/online mode switching.
///
/// Uses NWPathMonitor to track network availability and type.
/// Provides reactive updates when connectivity changes.
public final class NetworkConnectivityMonitor: ObservableObject, @unchecked Sendable {
    @Published @MainActor public private(set) var isConnected: Bool = false
    @Published @MainActor public private(set) var connectionType: ConnectionType = .unavailable

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.airoadtriptours.networkmonitor")

    /// Types of network connections.
    public enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unavailable

        /// Returns true if connection is metered (cellular).
        public var isMetered: Bool {
            return self == .cellular
        }

        /// Returns true if suitable for large downloads.
        public var isSuitableForDownloads: Bool {
            return self == .wifi || self == .wired
        }
    }

    public init() {
        self.monitor = NWPathMonitor()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    /// Starts monitoring network connectivity.
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                self.isConnected = path.status == .satisfied

                // Determine connection type
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .wired
                } else {
                    self.connectionType = .unavailable
                }
            }
        }

        monitor.start(queue: queue)
    }

    /// Stops monitoring network connectivity.
    public func stopMonitoring() {
        monitor.cancel()
    }

    /// Checks if network is available for downloading offline packages.
    ///
    /// - Parameter requireWifi: If true, only WiFi is considered suitable
    /// - Returns: True if network is suitable for downloading
    @MainActor
    public func isSuitableForDownloading(requireWifi: Bool = true) -> Bool {
        guard isConnected else { return false }

        if requireWifi {
            return connectionType == .wifi || connectionType == .wired
        } else {
            return isConnected
        }
    }
}
