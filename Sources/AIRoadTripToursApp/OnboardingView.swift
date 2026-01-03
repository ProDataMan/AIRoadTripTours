import SwiftUI
import AIRoadTripToursCore

public struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep = 0
    @State private var email = ""
    @State private var displayName = ""
    @State private var selectedCategories = Set<InterestCategory>()
    @State private var vehicleMake = ""
    @State private var vehicleModel = ""
    @State private var batteryCapacityKWh = ""
    @State private var rangeEstimateMiles = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<3) { step in
                        Circle()
                            .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.top)

                TabView(selection: $currentStep) {
                    welcomeStep.tag(0)
                    userInfoStep.tag(1)
                    vehicleInfoStep.tag(2)
                }
            }
            .navigationTitle("Welcome")
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "road.lanes")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            VStack(spacing: 16) {
                Text("AI Road Trip Tours")
                    .font(.largeTitle)
                    .bold()

                Text("Discover amazing destinations with AI-generated narrations tailored to your interests")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                withAnimation {
                    currentStep = 1
                }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }

    private var userInfoStep: some View {
        VStack(spacing: 24) {
            Text("Tell us about yourself")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("your@email.com", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Display Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Your name", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Interests (select all that apply)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(InterestCategory.allCases, id: \.self) { category in
                        Button {
                            if selectedCategories.contains(category) {
                                selectedCategories.remove(category)
                            } else {
                                selectedCategories.insert(category)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedCategories.contains(category) ? "checkmark.circle.fill" : "circle")
                                Text(category.rawValue.capitalized)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(selectedCategories.contains(category) ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .foregroundStyle(selectedCategories.contains(category) ? .blue : .primary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 16) {
                Button {
                    withAnimation {
                        currentStep = 0
                    }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                }

                Button {
                    withAnimation {
                        currentStep = 2
                    }
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isUserInfoValid ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .disabled(!isUserInfoValid)
            }
        }
        .padding()
    }

    private var vehicleInfoStep: some View {
        VStack(spacing: 24) {
            Text("Add your EV")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("Make")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Tesla", text: $vehicleMake)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Model 3", text: $vehicleModel)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Battery Capacity (kWh)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("75", text: $batteryCapacityKWh)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Range (miles)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("300", text: $rangeEstimateMiles)
                    .textFieldStyle(.roundedBorder)
            }

            Text("Quick presets:")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(vehiclePresets, id: \.make) { preset in
                    Button {
                        applyPreset(preset)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(preset.make)
                                .font(.caption)
                                .bold()
                            Text(preset.model)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .foregroundStyle(.primary)
                }
            }

            Spacer()

            HStack(spacing: 16) {
                Button {
                    withAnimation {
                        currentStep = 1
                    }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                }

                Button {
                    completeOnboarding()
                } label: {
                    Text("Get Started")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isVehicleInfoValid ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .disabled(!isVehicleInfoValid)
            }
        }
        .padding()
    }

    private var isUserInfoValid: Bool {
        !email.isEmpty && email.contains("@") && !displayName.isEmpty && !selectedCategories.isEmpty
    }

    private var isVehicleInfoValid: Bool {
        !vehicleMake.isEmpty &&
        !vehicleModel.isEmpty &&
        Double(batteryCapacityKWh) != nil &&
        Double(rangeEstimateMiles) != nil
    }

    private func completeOnboarding() {
        guard let capacity = Double(batteryCapacityKWh),
              let range = Double(rangeEstimateMiles) else {
            return
        }

        // Convert selected categories to UserInterest objects
        let interests = Set(selectedCategories.map { category in
            UserInterest(name: category.rawValue.capitalized, category: category)
        })

        let user = User(
            email: email,
            displayName: displayName,
            interests: interests
        )

        let vehicle = EVProfile(
            make: vehicleMake,
            model: vehicleModel,
            year: Calendar.current.component(.year, from: Date()),
            batteryCapacityKWh: capacity,
            chargingPorts: [.tesla],
            estimatedRangeMiles: range,
            consumptionRateKWhPerMile: capacity / range
        )

        appState.completeOnboarding(user: user, vehicle: vehicle)
    }

    private func applyPreset(_ preset: VehiclePreset) {
        vehicleMake = preset.make
        vehicleModel = preset.model
        batteryCapacityKWh = String(format: "%.0f", preset.batteryCapacityKWh)
        rangeEstimateMiles = String(format: "%.0f", preset.estimatedRangeMiles)
    }
}

struct VehiclePreset {
    let make: String
    let model: String
    let batteryCapacityKWh: Double
    let estimatedRangeMiles: Double
}

private let vehiclePresets = [
    VehiclePreset(make: "Tesla", model: "Model 3", batteryCapacityKWh: 75, estimatedRangeMiles: 310),
    VehiclePreset(make: "Ford", model: "Mustang Mach-E", batteryCapacityKWh: 88, estimatedRangeMiles: 290),
    VehiclePreset(make: "Chevrolet", model: "Bolt EV", batteryCapacityKWh: 66, estimatedRangeMiles: 259),
    VehiclePreset(make: "Nissan", model: "Leaf", batteryCapacityKWh: 62, estimatedRangeMiles: 226),
]

#Preview {
    OnboardingView()
        .environment(AppState())
}
