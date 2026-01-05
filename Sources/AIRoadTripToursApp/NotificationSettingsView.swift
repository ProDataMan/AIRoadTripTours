import SwiftUI
import UserNotifications

/// iOS notification settings and permissions.
@available(iOS 17.0, *)
public struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled = false
    @State private var tourStartReminders = true
    @State private var approachingPOIAlerts = true
    @State private var chargingReminders = true
    @State private var communityUpdates = false
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingPermissionDeniedAlert = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                // Notification Permission
                Section {
                    if authorizationStatus == .authorized {
                        HStack {
                            Label("Notifications Enabled", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                        }
                    } else if authorizationStatus == .denied {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Notifications Disabled", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)

                            Button("Open Settings") {
                                openAppSettings()
                            }
                            .font(.caption)
                        }
                    } else {
                        Button("Enable Notifications") {
                            requestNotificationPermission()
                        }
                    }
                } header: {
                    Text("Permission")
                } footer: {
                    Text("Allow notifications to receive tour updates and reminders.")
                }

                // Notification Types
                if authorizationStatus == .authorized {
                    Section {
                        Toggle("Tour Start Reminders", isOn: $tourStartReminders)
                        Toggle("Approaching POI Alerts", isOn: $approachingPOIAlerts)
                        Toggle("Charging Reminders", isOn: $chargingReminders)
                        Toggle("Community Updates", isOn: $communityUpdates)
                    } header: {
                        Text("Notification Types")
                    } footer: {
                        Text("Choose which types of notifications you want to receive.")
                    }
                }

                // Notification Settings Info
                Section {
                    LabeledContent("Delivery") {
                        Text("Immediate")
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Sound") {
                        Text("Default")
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Badge") {
                        Text("Enabled")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Delivery Settings")
                } footer: {
                    Text("Modify delivery settings in iOS Settings app.")
                }
            }
            .navigationTitle("Notifications")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task {
                await checkNotificationAuthorization()
            }
            .alert("Permission Denied", isPresented: $showingPermissionDeniedAlert) {
                Button("OK") {}
                Button("Open Settings") {
                    openAppSettings()
                }
            } message: {
                Text("Notification permission was denied. Enable notifications in Settings to receive tour updates.")
            }
        }
    }

    @MainActor
    private func checkNotificationAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        notificationsEnabled = settings.authorizationStatus == .authorized
    }

    @MainActor
    private func requestNotificationPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    authorizationStatus = .authorized
                    notificationsEnabled = true
                } else {
                    authorizationStatus = .denied
                    showingPermissionDeniedAlert = true
                }
            } catch {
                print("Error requesting notification permission: \(error)")
            }
        }
    }

    private func openAppSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

#if os(iOS)
#Preview {
    if #available(iOS 17.0, *) {
        NotificationSettingsView()
    } else {
        Text("iOS 17.0+ required")
    }
}
#endif
