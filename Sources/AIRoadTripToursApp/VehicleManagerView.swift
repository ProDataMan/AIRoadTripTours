import SwiftUI
import AIRoadTripToursCore

/// View for managing user's EV fleet.
public struct VehicleManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var showAddVehicle = false
    @State private var editingVehicle: EVProfile?
    @State private var showDeleteConfirmation = false
    @State private var vehicleToDelete: EVProfile?

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                if let user = appState.currentUser {
                    if user.vehicles.isEmpty {
                        ContentUnavailableView(
                            "No Vehicles",
                            systemImage: "car.fill",
                            description: Text("Add your first electric vehicle to get started")
                        )
                    } else {
                        Section {
                            ForEach(user.vehicles, id: \.id) { vehicle in
                                VehicleRow(
                                    vehicle: vehicle,
                                    isActive: vehicle.id == user.activeVehicleId,
                                    onSelect: {
                                        setActiveVehicle(vehicle)
                                    },
                                    onEdit: {
                                        editingVehicle = vehicle
                                    },
                                    onDelete: {
                                        vehicleToDelete = vehicle
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                        } header: {
                            Text("Your Vehicles")
                        } footer: {
                            Text("Tap a vehicle to make it active for tour planning.")
                        }
                    }
                }
            }
            .navigationTitle("Manage Vehicles")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddVehicle = true
                    } label: {
                        Label("Add Vehicle", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddVehicle) {
                AddEditVehicleView(mode: .add, onSave: { vehicle in
                    addVehicle(vehicle)
                    showAddVehicle = false
                })
            }
            .sheet(item: $editingVehicle) { vehicle in
                AddEditVehicleView(mode: .edit(vehicle), onSave: { updatedVehicle in
                    updateVehicle(updatedVehicle)
                    editingVehicle = nil
                })
            }
            .confirmationDialog(
                "Delete Vehicle?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let vehicle = vehicleToDelete {
                        deleteVehicle(vehicle)
                    }
                }
                Button("Cancel", role: .cancel) {
                    vehicleToDelete = nil
                }
            } message: {
                if let vehicle = vehicleToDelete {
                    Text("Are you sure you want to delete \(vehicle.year) \(vehicle.make) \(vehicle.model)?")
                }
            }
        }
    }

    private func addVehicle(_ vehicle: EVProfile) {
        guard var user = appState.currentUser else { return }

        user.vehicles.append(vehicle)

        // If this is the first vehicle, make it active
        if user.vehicles.count == 1 {
            user.activeVehicleId = vehicle.id
            appState.currentVehicle = vehicle
        }

        user.updatedAt = Date()

        // Persist changes
        let storage = OnboardingStorage()
        storage.saveUser(user)
        if user.activeVehicleId == vehicle.id {
            storage.saveVehicle(vehicle)
        }

        appState.currentUser = user
    }

    private func updateVehicle(_ vehicle: EVProfile) {
        guard var user = appState.currentUser else { return }

        if let index = user.vehicles.firstIndex(where: { $0.id == vehicle.id }) {
            user.vehicles[index] = vehicle
            user.updatedAt = Date()

            // If this is the active vehicle, update AppState
            if user.activeVehicleId == vehicle.id {
                appState.currentVehicle = vehicle
            }

            // Persist changes
            let storage = OnboardingStorage()
            storage.saveUser(user)
            if user.activeVehicleId == vehicle.id {
                storage.saveVehicle(vehicle)
            }

            appState.currentUser = user
        }
    }

    private func deleteVehicle(_ vehicle: EVProfile) {
        guard var user = appState.currentUser else { return }

        // Can't delete the only vehicle if it's active
        if user.vehicles.count == 1 {
            return
        }

        user.vehicles.removeAll { $0.id == vehicle.id }

        // If this was the active vehicle, activate the first remaining vehicle
        if user.activeVehicleId == vehicle.id {
            if let firstVehicle = user.vehicles.first {
                user.activeVehicleId = firstVehicle.id
                appState.currentVehicle = firstVehicle

                let storage = OnboardingStorage()
                storage.saveVehicle(firstVehicle)
            } else {
                user.activeVehicleId = nil
                appState.currentVehicle = nil
            }
        }

        user.updatedAt = Date()

        // Persist changes
        let storage = OnboardingStorage()
        storage.saveUser(user)

        appState.currentUser = user
        vehicleToDelete = nil
    }

    private func setActiveVehicle(_ vehicle: EVProfile) {
        guard var user = appState.currentUser else { return }

        user.activeVehicleId = vehicle.id
        user.updatedAt = Date()

        // Update AppState
        appState.currentVehicle = vehicle

        // Persist changes
        let storage = OnboardingStorage()
        storage.saveUser(user)
        storage.saveVehicle(vehicle)

        appState.currentUser = user
    }
}

/// Row displaying a vehicle with action buttons.
struct VehicleRow: View {
    let vehicle: EVProfile
    let isActive: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                        .font(.headline)

                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                HStack(spacing: 12) {
                    Label("\(Int(vehicle.batteryCapacityKWh)) kWh", systemImage: "battery.100")
                    Label("\(Int(vehicle.estimatedRangeMiles)) mi", systemImage: "road.lanes")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                // Charging ports
                HStack(spacing: 4) {
                    ForEach(Array(vehicle.chargingPorts).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { port in
                        Text(port.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            Menu {
                if !isActive {
                    Button {
                        onSelect()
                    } label: {
                        Label("Make Active", systemImage: "checkmark.circle")
                    }
                }

                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isActive {
                onSelect()
            }
        }
    }
}

/// Mode for add/edit vehicle view.
enum VehicleEditMode: Identifiable {
    case add
    case edit(EVProfile)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let vehicle): return vehicle.id.uuidString
        }
    }
}

/// View for adding or editing a vehicle.
struct AddEditVehicleView: View {
    @Environment(\.dismiss) private var dismiss
    let mode: VehicleEditMode
    let onSave: (EVProfile) -> Void

    @State private var make: String
    @State private var model: String
    @State private var year: Int
    @State private var batteryCapacity: Double
    @State private var estimatedRange: Double
    @State private var selectedPorts: Set<ChargingPortType>

    init(mode: VehicleEditMode, onSave: @escaping (EVProfile) -> Void) {
        self.mode = mode
        self.onSave = onSave

        switch mode {
        case .add:
            _make = State(initialValue: "")
            _model = State(initialValue: "")
            _year = State(initialValue: Calendar.current.component(.year, from: Date()))
            _batteryCapacity = State(initialValue: 75.0)
            _estimatedRange = State(initialValue: 300.0)
            _selectedPorts = State(initialValue: [.ccs])
        case .edit(let vehicle):
            _make = State(initialValue: vehicle.make)
            _model = State(initialValue: vehicle.model)
            _year = State(initialValue: vehicle.year)
            _batteryCapacity = State(initialValue: vehicle.batteryCapacityKWh)
            _estimatedRange = State(initialValue: vehicle.estimatedRangeMiles)
            _selectedPorts = State(initialValue: vehicle.chargingPorts)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle Information") {
                    TextField("Make", text: $make)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif

                    TextField("Model", text: $model)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif

                    Picker("Year", selection: $year) {
                        ForEach((2015...Calendar.current.component(.year, from: Date()) + 1).reversed(), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                }

                Section("Battery & Range") {
                    HStack {
                        Text("Battery Capacity")
                        Spacer()
                        TextField("kWh", value: $batteryCapacity, format: .number)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kWh")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Estimated Range")
                        Spacer()
                        TextField("miles", value: $estimatedRange, format: .number)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("mi")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach(ChargingPortType.allCases, id: \.self) { port in
                        Toggle(port.rawValue, isOn: Binding(
                            get: { selectedPorts.contains(port) },
                            set: { isSelected in
                                if isSelected {
                                    selectedPorts.insert(port)
                                } else {
                                    selectedPorts.remove(port)
                                }
                            }
                        ))
                    }
                } header: {
                    Text("Charging Ports")
                } footer: {
                    Text("Select all charging port types your vehicle supports.")
                }
            }
            .navigationTitle(mode.isAdd ? "Add Vehicle" : "Edit Vehicle")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveVehicle()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        batteryCapacity > 0 &&
        estimatedRange > 0 &&
        !selectedPorts.isEmpty
    }

    private func saveVehicle() {
        let consumptionRate = batteryCapacity / estimatedRange

        let vehicle: EVProfile
        switch mode {
        case .add:
            vehicle = EVProfile(
                make: make.trimmingCharacters(in: .whitespacesAndNewlines),
                model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                year: year,
                batteryCapacityKWh: batteryCapacity,
                chargingPorts: selectedPorts,
                estimatedRangeMiles: estimatedRange,
                consumptionRateKWhPerMile: consumptionRate
            )
        case .edit(let existing):
            vehicle = EVProfile(
                id: existing.id,
                make: make.trimmingCharacters(in: .whitespacesAndNewlines),
                model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                year: year,
                batteryCapacityKWh: batteryCapacity,
                chargingPorts: selectedPorts,
                estimatedRangeMiles: estimatedRange,
                consumptionRateKWhPerMile: consumptionRate
            )
        }

        onSave(vehicle)
        dismiss()
    }
}

extension VehicleEditMode {
    var isAdd: Bool {
        if case .add = self {
            return true
        }
        return false
    }
}

#Preview("Vehicle Manager") {
    VehicleManagerView()
        .environment(AppState())
}
