import SwiftUI
import AIRoadTripToursCore

public struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showResetConfirmation = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                if let user = appState.currentUser {
                    Section("User Information") {
                        LabeledContent("Email", value: user.email)
                        LabeledContent("Display Name", value: user.displayName)

                        LabeledContent("Account Created") {
                            Text(user.createdAt, style: .date)
                        }

                        LabeledContent("Account Status") {
                            HStack {
                                if user.isTrialActive {
                                    Label("Trial Active", systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else if user.hasActiveSubscription {
                                    Label("Premium", systemImage: "star.fill")
                                        .foregroundStyle(.blue)
                                } else {
                                    Label("Trial Expired", systemImage: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }

                    Section("Interests") {
                        ForEach(user.interests.sorted(by: { $0.name < $1.name }), id: \.self) { interest in
                            Label(interest.name, systemImage: "star")
                        }
                    }
                }

                if let vehicle = appState.currentVehicle {
                    Section("Current Vehicle") {
                        LabeledContent("Make", value: vehicle.make)
                        LabeledContent("Model", value: vehicle.model)
                        LabeledContent("Year", value: String(vehicle.year))
                        LabeledContent("Battery", value: "\(Int(vehicle.batteryCapacityKWh)) kWh")
                        LabeledContent("Range", value: "\(Int(vehicle.estimatedRangeMiles)) miles")

                        LabeledContent("Charging Ports") {
                            HStack(spacing: 4) {
                                ForEach(vehicle.chargingPorts.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { port in
                                    Text(port.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Reset all onboarding data to start fresh. This will clear your profile and vehicle information.")
                        .font(.caption)
                }
            }
            .navigationTitle("Profile")
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
                Text("This will clear all your profile and vehicle data. You'll need to complete onboarding again.")
            }
        }
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
