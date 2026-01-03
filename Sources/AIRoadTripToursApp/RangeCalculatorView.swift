import SwiftUI
import AIRoadTripToursCore

public struct RangeCalculatorView: View {
    @Environment(AppState.self) private var appState
    @State private var distanceMiles = ""
    @State private var temperatureF = "70"
    @State private var elevationGainFeet = "0"
    @State private var estimatedRange: Double?

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Distance (miles)", text: $distanceMiles)

                    TextField("Temperature (°F)", text: $temperatureF)

                    TextField("Elevation Gain (feet)", text: $elevationGainFeet)
                }

                Section("Vehicle Information") {
                    if let vehicle = appState.currentVehicle {
                        LabeledContent("Make", value: vehicle.make)
                        LabeledContent("Model", value: vehicle.model)
                        LabeledContent("Battery", value: "\(Int(vehicle.batteryCapacityKWh)) kWh")
                        LabeledContent("Range", value: "\(Int(vehicle.estimatedRangeMiles)) mi")
                    } else {
                        Text("No vehicle configured")
                            .foregroundStyle(.secondary)
                    }
                }

                if let range = estimatedRange {
                    Section("Estimated Range") {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(.yellow)
                            Text("\(Int(range)) miles")
                                .font(.title2)
                                .bold()
                        }

                        if let distance = Double(distanceMiles),
                           distance <= range {
                            Label("Trip is within range", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else if let distance = Double(distanceMiles) {
                            Label("Trip exceeds range by \(Int(distance - range)) miles", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section {
                    Button {
                        calculateRange()
                    } label: {
                        Text("Calculate Range")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(appState.currentVehicle == nil || distanceMiles.isEmpty)
                }
            }
            .navigationTitle("Range Calculator")
        }
    }

    private func calculateRange() {
        guard let vehicle = appState.currentVehicle,
              let temp = Double(temperatureF),
              let elevation = Double(elevationGainFeet) else {
            return
        }

        let conditions = DrivingConditions(
            temperatureFahrenheit: temp,
            elevationChangeFeet: elevation,
            averageSpeedMph: 60.0
        )

        let result = appState.rangeEstimator.estimateRange(
            for: vehicle,
            currentBatteryPercent: 100.0,
            conditions: conditions
        )

        estimatedRange = result
    }
}

#Preview {
    RangeCalculatorView()
        .environment(AppState())
}
