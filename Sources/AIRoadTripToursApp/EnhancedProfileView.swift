import SwiftUI
import AIRoadTripToursCore

/// Enhanced profile view with editing, settings, and statistics.
public struct EnhancedProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showEditProfile = false
    @State private var showVehicleManager = false
    @State private var showPreferences = false
    @State private var showStatistics = false
    @State private var showResetConfirmation = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // User Profile Section
                if let user = appState.currentUser {
                    Section {
                        HStack {
                            // Profile Avatar
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 60, height: 60)
                                .overlay {
                                    Text(user.displayName.prefix(2).uppercased())
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName)
                                    .font(.headline)

                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                // Account Status Badge
                                accountStatusBadge(user)
                            }

                            Spacer()

                            Button {
                                showEditProfile = true
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // Quick Stats
                    Section {
                        NavigationLink {
                            TourStatisticsView()
                        } label: {
                            HStack {
                                Label("Tour Statistics", systemImage: "chart.bar.fill")
                                Spacer()
                                statisticsSummary
                            }
                        }
                    }

                    // Interests
                    Section("Interests") {
                        if user.interests.isEmpty {
                            Text("No interests selected")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ProfileFlowLayout(spacing: 8) {
                                ForEach(user.interests.sorted(by: { $0.name < $1.name }), id: \.self) { interest in
                                    InterestChip(interest: interest)
                                }
                            }
                        }
                    }
                }

                // Vehicle Management
                Section("Vehicles") {
                    if let vehicle = appState.currentVehicle {
                        VehicleCard(vehicle: vehicle, isActive: true)
                    } else {
                        Text("No vehicle configured")
                            .foregroundStyle(.secondary)
                            .italic()
                    }

                    Button {
                        showVehicleManager = true
                    } label: {
                        Label("Manage Vehicles", systemImage: "car.circle")
                    }
                }

                // Settings & Preferences
                Section("Settings") {
                    NavigationLink {
                        UserPreferencesView()
                    } label: {
                        Label("Preferences", systemImage: "slider.horizontal.3")
                    }

                    NavigationLink {
                        OfflineDownloadsView(
                            downloadManager: appState.offlineDownloadManager,
                            networkMonitor: appState.networkMonitor
                        )
                    } label: {
                        Label("Offline Downloads", systemImage: "arrow.down.circle")
                    }

                    #if os(iOS)
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell.fill")
                    }
                    #endif
                }

                // Account Actions
                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Reset all onboarding data to start fresh.")
                }

                // App Info
                Section {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showEditProfile) {
                if let user = appState.currentUser {
                    EditProfileView(user: user, onSave: { updatedUser in
                        appState.currentUser = updatedUser
                        showEditProfile = false
                    })
                }
            }
            .sheet(isPresented: $showVehicleManager) {
                VehicleManagerView()
            }
            .confirmationDialog(
                "Reset Onboarding?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    appState.resetOnboarding()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear all your profile and vehicle data.")
            }
        }
    }

    @ViewBuilder
    private func accountStatusBadge(_ user: User) -> some View {
        HStack(spacing: 4) {
            if user.isTrialActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Trial Active")
            } else if user.hasActiveSubscription {
                Image(systemName: "star.fill")
                    .foregroundStyle(.blue)
                Text("Premium")
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Trial Expired")
            }
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .clipShape(Capsule())
    }

    private var statisticsSummary: some View {
        HStack(spacing: 16) {
            let stats = appState.tourHistoryStorage.computeStatistics()

            ProfileStatBadge(
                value: "\(stats.totalToursCompleted)",
                label: "Tours",
                icon: "map.fill"
            )

            ProfileStatBadge(
                value: "\(Int(stats.totalDistanceMiles))",
                label: "Miles",
                icon: "road.lanes"
            )

            ProfileStatBadge(
                value: "\(stats.totalPOIsVisited)",
                label: "POIs",
                icon: "mappin.circle"
            )
        }
        .font(.caption2)
    }
}

/// Small statistics badge.
private struct ProfileStatBadge: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(value)
                    .font(.caption.bold())
            }
            .foregroundStyle(.blue)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// Interest chip badge.
struct InterestChip: View {
    let interest: UserInterest

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: categoryIcon(interest.category))
                .font(.caption2)
            Text(interest.name)
                .font(.caption)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(categoryColor(interest.category))
        .clipShape(Capsule())
    }

    private func categoryIcon(_ category: InterestCategory) -> String {
        switch category {
        case .nature: return "leaf.fill"
        case .food: return "fork.knife"
        case .history: return "building.columns.fill"
        case .entertainment: return "theatermasks.fill"
        case .adventure: return "figure.hiking"
        case .culture: return "paintpalette.fill"
        case .shopping: return "cart.fill"
        case .relaxation: return "beach.umbrella.fill"
        case .scenic: return "mountain.2.fill"
        case .wildlife: return "pawprint.fill"
        }
    }

    private func categoryColor(_ category: InterestCategory) -> Color {
        switch category {
        case .nature: return .green
        case .food: return .orange
        case .history: return .brown
        case .entertainment: return .purple
        case .adventure: return .red
        case .culture: return .blue
        case .shopping: return .pink
        case .relaxation: return .cyan
        case .scenic: return .indigo
        case .wildlife: return .mint
        }
    }
}

/// Compact vehicle card.
struct VehicleCard: View {
    let vehicle: EVProfile
    let isActive: Bool

    var body: some View {
        HStack {
            Image(systemName: "ev.charger.fill")
                .font(.title2)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("\(Int(vehicle.batteryCapacityKWh)) kWh", systemImage: "battery.100")
                    Label("\(Int(vehicle.estimatedRangeMiles)) mi", systemImage: "road.lanes")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

/// Flow layout for interests.
private struct ProfileFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(rows.count - 1) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var point = bounds.origin
        let rows = computeRows(proposal: proposal, subviews: subviews)

        for row in rows {
            var x = point.x
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: point.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            point.y += row.height + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [(indices: [Int], height: CGFloat)] {
        var rows: [(indices: [Int], height: CGFloat)] = []
        var currentRow: [Int] = []
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        let maxWidth = proposal.width ?? 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            if currentRowWidth + size.width > maxWidth && !currentRow.isEmpty {
                rows.append((indices: currentRow, height: currentRowHeight))
                currentRow = []
                currentRowWidth = 0
                currentRowHeight = 0
            }

            currentRow.append(index)
            currentRowWidth += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }

        if !currentRow.isEmpty {
            rows.append((indices: currentRow, height: currentRowHeight))
        }

        return rows
    }
}

#Preview {
    EnhancedProfileView()
        .environment(AppState())
}
