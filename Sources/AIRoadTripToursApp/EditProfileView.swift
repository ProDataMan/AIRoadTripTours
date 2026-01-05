import SwiftUI
import AIRoadTripToursCore

/// View for editing user profile information.
public struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let user: User
    let onSave: (User) -> Void

    @State private var displayName: String
    @State private var selectedInterests: Set<UserInterest>
    @State private var showInterestPicker = false

    public init(user: User, onSave: @escaping (User) -> Void) {
        self.user = user
        self.onSave = onSave
        _displayName = State(initialValue: user.displayName)
        _selectedInterests = State(initialValue: user.interests)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display Name", text: $displayName)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                } header: {
                    Text("Display Name")
                }

                Section {
                    ForEach(Array(selectedInterests).sorted(by: { $0.name < $1.name }), id: \.self) { interest in
                        HStack {
                            InterestRow(interest: interest)
                            Spacer()
                            Button {
                                selectedInterests.remove(interest)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    Button {
                        showInterestPicker = true
                    } label: {
                        Label("Add Interest", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Interests")
                } footer: {
                    Text("Select your interests to personalize tour recommendations.")
                }

                Section {
                    LabeledContent("Email", value: user.email)
                    LabeledContent("Account Created") {
                        Text(user.createdAt, style: .date)
                    }
                } header: {
                    Text("Account Information")
                } footer: {
                    Text("Email cannot be changed.")
                }
            }
            .navigationTitle("Edit Profile")
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
                        saveProfile()
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showInterestPicker) {
                InterestPickerView(selectedInterests: $selectedInterests)
            }
        }
    }

    private func saveProfile() {
        var updatedUser = user
        updatedUser.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedUser.interests = selectedInterests
        updatedUser.updatedAt = Date()

        // Persist to storage
        let storage = OnboardingStorage()
        storage.saveUser(updatedUser)

        onSave(updatedUser)
    }
}

/// Interest row view.
struct InterestRow: View {
    let interest: UserInterest

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: categoryIcon(interest.category))
                .foregroundStyle(categoryColor(interest.category))
            Text(interest.name)
        }
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

/// Interest picker sheet.
struct InterestPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedInterests: Set<UserInterest>

    @State private var searchText = ""

    // Predefined interests by category
    private let availableInterests: [InterestCategory: [UserInterest]] = [
        .nature: [
            UserInterest(name: "National Parks", category: .nature),
            UserInterest(name: "Forests", category: .nature),
            UserInterest(name: "Lakes", category: .nature),
            UserInterest(name: "Mountains", category: .nature),
            UserInterest(name: "Beaches", category: .nature)
        ],
        .food: [
            UserInterest(name: "Local Cuisine", category: .food),
            UserInterest(name: "Fine Dining", category: .food),
            UserInterest(name: "Food Trucks", category: .food),
            UserInterest(name: "Breweries", category: .food),
            UserInterest(name: "Wineries", category: .food),
            UserInterest(name: "Farmers Markets", category: .food)
        ],
        .history: [
            UserInterest(name: "Historical Sites", category: .history),
            UserInterest(name: "Museums", category: .history),
            UserInterest(name: "Architecture", category: .history),
            UserInterest(name: "Landmarks", category: .history)
        ],
        .entertainment: [
            UserInterest(name: "Live Music", category: .entertainment),
            UserInterest(name: "Theaters", category: .entertainment),
            UserInterest(name: "Festivals", category: .entertainment),
            UserInterest(name: "Art Galleries", category: .entertainment)
        ],
        .adventure: [
            UserInterest(name: "Hiking", category: .adventure),
            UserInterest(name: "Rock Climbing", category: .adventure),
            UserInterest(name: "Water Sports", category: .adventure),
            UserInterest(name: "Skiing", category: .adventure),
            UserInterest(name: "Mountain Biking", category: .adventure)
        ],
        .culture: [
            UserInterest(name: "Art", category: .culture),
            UserInterest(name: "Music", category: .culture),
            UserInterest(name: "Local Crafts", category: .culture),
            UserInterest(name: "Street Art", category: .culture)
        ],
        .shopping: [
            UserInterest(name: "Antiques", category: .shopping),
            UserInterest(name: "Boutiques", category: .shopping),
            UserInterest(name: "Malls", category: .shopping),
            UserInterest(name: "Outlet Stores", category: .shopping)
        ],
        .relaxation: [
            UserInterest(name: "Spas", category: .relaxation),
            UserInterest(name: "Yoga Studios", category: .relaxation),
            UserInterest(name: "Hot Springs", category: .relaxation),
            UserInterest(name: "Meditation Centers", category: .relaxation)
        ],
        .scenic: [
            UserInterest(name: "Scenic Drives", category: .scenic),
            UserInterest(name: "Viewpoints", category: .scenic),
            UserInterest(name: "Sunsets", category: .scenic),
            UserInterest(name: "Photography Spots", category: .scenic)
        ],
        .wildlife: [
            UserInterest(name: "Wildlife Watching", category: .wildlife),
            UserInterest(name: "Zoos", category: .wildlife),
            UserInterest(name: "Aquariums", category: .wildlife),
            UserInterest(name: "Bird Watching", category: .wildlife),
            UserInterest(name: "Safari Parks", category: .wildlife)
        ]
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(InterestCategory.allCases, id: \.self) { category in
                    if let interests = availableInterests[category] {
                        Section(category.rawValue.capitalized) {
                            ForEach(interests, id: \.name) { interest in
                                InterestPickerRow(
                                    interest: interest,
                                    isSelected: selectedInterests.contains(interest)
                                ) {
                                    toggleInterest(interest)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Interests")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search interests")
        }
    }

    private func toggleInterest(_ interest: UserInterest) {
        if selectedInterests.contains(interest) {
            selectedInterests.remove(interest)
        } else {
            selectedInterests.insert(interest)
        }
    }
}

/// Interest picker row.
struct InterestPickerRow: View {
    let interest: UserInterest
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack {
                InterestRow(interest: interest)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}
