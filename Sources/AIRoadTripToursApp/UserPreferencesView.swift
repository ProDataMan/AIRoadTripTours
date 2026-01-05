import SwiftUI
import AIRoadTripToursCore

/// User preferences and app settings.
public struct UserPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("downloadRequiresWifi") private var downloadRequiresWifi = true
    @AppStorage("audioNarrationEnabled") private var audioNarrationEnabled = true
    @AppStorage("audioSpeed") private var audioSpeed = 1.0
    @AppStorage("audioPitch") private var audioPitch = 0.0
    @AppStorage("voiceGender") private var voiceGender = "female"
    @AppStorage("mapShowsTraffic") private var mapShowsTraffic = true
    @AppStorage("mapShowsPOIs") private var mapShowsPOIs = true
    @AppStorage("mapDarkMode") private var mapDarkMode = false
    @AppStorage("tourDefaultDistance") private var tourDefaultDistance = 100.0
    @AppStorage("tourPOIDensity") private var tourPOIDensity = "medium"
    @AppStorage("tourIncludeChargingStops") private var tourIncludeChargingStops = true
    @AppStorage("privacyShareUsageData") private var privacyShareUsageData = false
    @AppStorage("privacyLocationWhenInUse") private var privacyLocationWhenInUse = true

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                // Download Preferences
                Section {
                    Toggle("Require WiFi for Downloads", isOn: $downloadRequiresWifi)
                } header: {
                    Text("Downloads")
                } footer: {
                    Text("When enabled, offline tour downloads only occur over WiFi to avoid cellular data charges.")
                }

                // Audio Narration
                Section {
                    Toggle("Enable Audio Narration", isOn: $audioNarrationEnabled)

                    if audioNarrationEnabled {
                        Picker("Voice", selection: $voiceGender) {
                            Text("Female").tag("female")
                            Text("Male").tag("male")
                            Text("Neutral").tag("neutral")
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Speed")
                                Spacer()
                                Text(String(format: "%.1fx", audioSpeed))
                                    .foregroundStyle(.secondary)
                            }

                            Slider(value: $audioSpeed, in: 0.5...2.0, step: 0.1)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Pitch")
                                Spacer()
                                Text(String(format: "%.0f", audioPitch))
                                    .foregroundStyle(.secondary)
                            }

                            Slider(value: $audioPitch, in: -10.0...10.0, step: 1.0)
                        }
                    }
                } header: {
                    Text("Audio Narration")
                } footer: {
                    Text("Customize the voice and playback settings for tour narrations.")
                }

                // Map Display
                Section {
                    Toggle("Show Traffic", isOn: $mapShowsTraffic)
                    Toggle("Show Points of Interest", isOn: $mapShowsPOIs)
                    Toggle("Dark Mode Maps", isOn: $mapDarkMode)
                } header: {
                    Text("Map Display")
                } footer: {
                    Text("Control what information is displayed on the map during tours.")
                }

                // Tour Defaults
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Default Distance")
                            Spacer()
                            Text("\(Int(tourDefaultDistance)) miles")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $tourDefaultDistance, in: 25...500, step: 25)
                    }

                    Picker("POI Density", selection: $tourPOIDensity) {
                        Text("Low (Fewer stops)").tag("low")
                        Text("Medium").tag("medium")
                        Text("High (Many stops)").tag("high")
                    }

                    Toggle("Include Charging Stops", isOn: $tourIncludeChargingStops)
                } header: {
                    Text("Tour Planning")
                } footer: {
                    Text("Default settings for new tour plans. Higher POI density means more stops along the route.")
                }

                // Privacy
                Section {
                    Toggle("Share Anonymous Usage Data", isOn: $privacyShareUsageData)
                    Toggle("Location When In Use", isOn: $privacyLocationWhenInUse)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Usage data helps improve the app. Location access is required for turn-by-turn navigation.")
                }

                // Reset Section
                Section {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                } footer: {
                    Text("Restore all preferences to their default values.")
                }
            }
            .navigationTitle("Preferences")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private func resetToDefaults() {
        downloadRequiresWifi = true
        audioNarrationEnabled = true
        audioSpeed = 1.0
        audioPitch = 0.0
        voiceGender = "female"
        mapShowsTraffic = true
        mapShowsPOIs = true
        mapDarkMode = false
        tourDefaultDistance = 100.0
        tourPOIDensity = "medium"
        tourIncludeChargingStops = true
        privacyShareUsageData = false
        privacyLocationWhenInUse = true
    }
}

#Preview {
    UserPreferencesView()
}
