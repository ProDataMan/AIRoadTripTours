# AI Road Trip Tours - iOS MVP Setup Guide

This guide walks through creating an iOS app for MVP testing of AI Road Trip Tours.

## Prerequisites

- Xcode 15.0+ installed.
- macOS 14.0+ (Sonoma).
- This Swift package repository cloned locally.

## Step 1: Create iOS App in Xcode

1. Open Xcode.
2. Select **File > New > Project**.
3. Choose **iOS > App** template.
4. Configure the project:
   - Product Name: `AIRoadTripToursApp`
   - Team: Select your development team.
   - Organization Identifier: com.yourname (or your preference).
   - Interface: **SwiftUI**.
   - Language: **Swift**.
   - Storage: None (we'll handle persistence later).
5. Save the project **outside** this repository (for example, in a sibling directory).

## Step 2: Add Local Package Dependency

1. In Xcode, select your project in the navigator.
2. Select the `AIRoadTripToursApp` target.
3. Navigate to **General** tab.
4. Scroll to **Frameworks, Libraries, and Embedded Content**.
5. Click the **+** button.
6. Click **Add Other... > Add Package Dependency...**.
7. Click **Add Local...** at the bottom.
8. Navigate to this repository folder (`AIRoadTripTours`).
9. Select the folder and click **Add Package**.
10. In the dialog, select `AIRoadTripToursCore` library and click **Add Package**.

## Step 3: Configure Info.plist for Location Services

1. Select `Info.plist` in the project navigator (or add keys in Info tab of target).
2. Add these keys:
   - **Privacy - Location When In Use Usage Description**:
     Value: "AI Road Trip Tours uses your location to find nearby attractions and plan routes."
   - **Privacy - Location Always and When In Use Usage Description**:
     Value: "AI Road Trip Tours uses your location to provide turn-by-turn navigation and real-time tour narration."

## Step 4: Add SwiftUI Views

Create the following files in your Xcode project:

### 1. Models/AppState.swift

```swift
import Foundation
import AIRoadTripToursCore

@Observable
class AppState {
    var currentUser: User?
    var selectedVehicle: EVProfile?
    var nearbyPOIs: [POI] = []
    var currentTour: Tour?
    var isLoading = false
    var errorMessage: String?

    let poiRepository = InMemoryPOIRepository(initialPOIs: SampleData.samplePOIs)
    let tourPlanner = StandardTourPlanner()
    let rangeEstimator = SimpleRangeEstimator()

    func createUser(email: String, name: String) {
        currentUser = User(email: email, displayName: name)
    }

    func addVehicle(_ vehicle: EVProfile) {
        currentUser?.vehicles.append(vehicle)
        if currentUser?.activeVehicleId == nil {
            currentUser?.activeVehicleId = vehicle.id
            selectedVehicle = vehicle
        }
    }

    func selectVehicle(_ vehicleId: UUID) {
        currentUser?.activeVehicleId = vehicleId
        selectedVehicle = currentUser?.vehicles.first { $0.id == vehicleId }
    }
}
```

### 2. Models/SampleData.swift

```swift
import Foundation
import AIRoadTripToursCore

enum SampleData {
    static let samplePOIs: [POI] = [
        POI(
            name: "Multnomah Falls",
            description: "A spectacular 620-foot waterfall in the Columbia River Gorge.",
            category: .waterfall,
            location: GeoLocation(
                latitude: 45.5762,
                longitude: -122.1153,
                address: "Multnomah Falls Lodge, Bridal Veil, OR 97010"
            ),
            hours: POIHours(description: "Open 24 hours", isOpenNow: true),
            rating: POIRating(averageRating: 4.8, totalRatings: 5000, priceLevel: 1),
            tags: ["scenic", "nature", "waterfall", "hiking"]
        ),
        POI(
            name: "Portland Japanese Garden",
            description: "Traditional Japanese garden in Portland hills.",
            category: .park,
            location: GeoLocation(
                latitude: 45.5195,
                longitude: -122.7057,
                address: "611 SW Kingston Ave, Portland, OR 97205"
            ),
            contact: POIContact(phone: "+1-503-223-1321", website: "https://japanesegarden.org"),
            hours: POIHours(description: "Mon-Sun 10am-7pm", isOpenNow: true),
            rating: POIRating(averageRating: 4.7, totalRatings: 2000, priceLevel: 2),
            tags: ["garden", "peaceful", "cultural"]
        ),
        POI(
            name: "Voodoo Doughnut",
            description: "Famous Portland doughnut shop.",
            category: .restaurant,
            location: GeoLocation(
                latitude: 45.5228,
                longitude: -122.6731,
                address: "22 SW 3rd Ave, Portland, OR 97204"
            ),
            contact: POIContact(phone: "+1-503-241-4704", website: "https://voodoodoughnut.com"),
            hours: POIHours(description: "Open 24 hours", isOpenNow: true),
            rating: POIRating(averageRating: 4.2, totalRatings: 10000, priceLevel: 1),
            tags: ["famous", "dessert", "quirky"]
        )
    ]

    static let sampleVehicles: [EVProfile] = [
        EVProfile(
            make: "Tesla",
            model: "Model 3",
            year: 2024,
            batteryCapacityKWh: 75.0,
            chargingPorts: [.nacs, .ccs],
            estimatedRangeMiles: 272.0,
            consumptionRateKWhPerMile: 0.276
        ),
        EVProfile(
            make: "Ford",
            model: "Mustang Mach-E",
            year: 2024,
            batteryCapacityKWh: 91.0,
            chargingPorts: [.ccs, .j1772],
            estimatedRangeMiles: 312.0,
            consumptionRateKWhPerMile: 0.291
        )
    ]
}
```

### 3. Views/OnboardingView.swift

```swift
import SwiftUI
import AIRoadTripToursCore

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var email = ""
    @State private var name = ""
    @State private var selectedVehicle: EVProfile?
    @State private var selectedInterests: Set<UserInterest> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    TextField("Name", text: $name)
                        .textContentType(.name)
                }

                Section("Select Your Vehicle") {
                    ForEach(SampleData.sampleVehicles) { vehicle in
                        Button {
                            selectedVehicle = vehicle
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                                        .font(.headline)
                                    Text("\(Int(vehicle.estimatedRangeMiles)) mi range")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedVehicle?.id == vehicle.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                Section("Your Interests") {
                    InterestSelectionView(selectedInterests: $selectedInterests)
                }
            }
            .navigationTitle("Welcome")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Get Started") {
                        createProfile()
                    }
                    .disabled(!canProceed)
                }
            }
        }
    }

    private var canProceed: Bool {
        !email.isEmpty && !name.isEmpty && selectedVehicle != nil
    }

    private func createProfile() {
        appState.createUser(email: email, name: name)
        if let vehicle = selectedVehicle {
            appState.addVehicle(vehicle)
        }
        appState.currentUser?.interests = selectedInterests
    }
}

struct InterestSelectionView: View {
    @Binding var selectedInterests: Set<UserInterest>

    let interests: [(String, InterestCategory)] = [
        ("Hiking", .adventure),
        ("Local Food", .food),
        ("Historic Sites", .history),
        ("Scenic Views", .scenic),
        ("Wildlife", .wildlife),
        ("Museums", .culture),
        ("Beach Activities", .relaxation),
        ("Shopping", .shopping)
    ]

    var body: some View {
        ForEach(interests, id: \.0) { name, category in
            let interest = UserInterest(name: name, category: category)
            Toggle(name, isOn: Binding(
                get: { selectedInterests.contains(interest) },
                set: { isOn in
                    if isOn {
                        selectedInterests.insert(interest)
                    } else {
                        selectedInterests.remove(interest)
                    }
                }
            ))
        }
    }
}
```

### 4. Views/MainTabView.swift

```swift
import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "map")
                }

            ToursView()
                .tabItem {
                    Label("Tours", systemImage: "map.fill")
                }

            RangeCalculatorView()
                .tabItem {
                    Label("Range", systemImage: "bolt.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
    }
}
```

### 5. Views/DiscoverView.swift

```swift
import SwiftUI
import AIRoadTripToursCore
import MapKit

struct DiscoverView: View {
    @Environment(AppState.self) private var appState
    @State private var searchRadius: Double = 25.0
    @State private var pois: [POI] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Search Radius")
                        Spacer()
                        Text("\(Int(searchRadius)) miles")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $searchRadius, in: 5...100, step: 5)
                }

                Section("Nearby Attractions") {
                    if pois.isEmpty {
                        ContentUnavailableView(
                            "No POIs Found",
                            systemImage: "map",
                            description: Text("Try adjusting your search radius")
                        )
                    } else {
                        ForEach(pois) { poi in
                            NavigationLink(destination: POIDetailView(poi: poi)) {
                                POIRow(poi: poi)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Discover")
            .task {
                await loadPOIs()
            }
            .onChange(of: searchRadius) {
                Task {
                    await loadPOIs()
                }
            }
        }
    }

    private func loadPOIs() async {
        do {
            // In real app, would use user's location
            let portland = GeoLocation(latitude: 45.5152, longitude: -122.6784)
            pois = try await appState.poiRepository.findNearby(
                location: portland,
                radiusMiles: searchRadius,
                categories: nil
            )
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}

struct POIRow: View {
    let poi: POI

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(poi.name)
                .font(.headline)

            HStack {
                Text(poi.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let rating = poi.rating {
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption2)
                        Text(String(format: "%.1f", rating.averageRating))
                            .font(.caption)
                    }
                }
            }
        }
    }
}
```

### 6. Views/POIDetailView.swift

```swift
import SwiftUI
import AIRoadTripToursCore

struct POIDetailView: View {
    let poi: POI

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(poi.name)
                        .font(.title2)
                        .bold()

                    if let description = poi.description {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let rating = poi.rating {
                Section("Rating") {
                    HStack {
                        Text("Rating")
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating.averageRating) ? "star.fill" : "star")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                            }
                            Text("(\(rating.totalRatings) reviews)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let priceLevel = rating.priceLevel {
                        HStack {
                            Text("Price")
                            Spacer()
                            Text(String(repeating: "$", count: priceLevel))
                                .foregroundStyle(.green)
                        }
                    }
                }
            }

            if let contact = poi.contact {
                Section("Contact") {
                    if let phone = contact.phone {
                        Link(destination: URL(string: "tel:\(phone.filter { $0.isNumber })")!) {
                            HStack {
                                Label("Call", systemImage: "phone.fill")
                                Spacer()
                                Text(phone)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let website = contact.website, let url = URL(string: website) {
                        Link(destination: url) {
                            Label("Website", systemImage: "safari")
                        }
                    }
                }
            }

            if let hours = poi.hours {
                Section("Hours") {
                    HStack {
                        Text(hours.description)
                        Spacer()
                        if let isOpen = hours.isOpenNow {
                            Text(isOpen ? "Open Now" : "Closed")
                                .foregroundStyle(isOpen ? .green : .red)
                                .bold()
                        }
                    }
                }
            }

            if !poi.tags.isEmpty {
                Section("Tags") {
                    FlowLayout {
                        ForEach(Array(poi.tags.sorted()), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .navigationTitle(poi.category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FlowLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var point = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if point.x + size.width > bounds.maxX && point.x > bounds.origin.x {
                point.x = bounds.origin.x
                point.y += rowHeight + 8
                rowHeight = 0
            }

            subview.place(at: point, proposal: .unspecified)
            point.x += size.width + 8
            rowHeight = max(rowHeight, size.height)
        }
    }
}
```

### 7. Views/ToursView.swift, RangeCalculatorView.swift, ProfileView.swift

Create placeholder views for now:

```swift
import SwiftUI

struct ToursView: View {
    var body: some View {
        NavigationStack {
            Text("Tours - Coming Soon")
                .navigationTitle("Tours")
        }
    }
}

struct RangeCalculatorView: View {
    var body: some View {
        NavigationStack {
            Text("Range Calculator - Coming Soon")
                .navigationTitle("Range")
        }
    }
}

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            Text("Profile - Coming Soon")
                .navigationTitle("Profile")
        }
    }
}
```

### 8. Update App Entry Point (AIRoadTripToursApp.swift)

```swift
import SwiftUI

@main
struct AIRoadTripToursApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.currentUser == nil {
                    OnboardingView()
                } else {
                    MainTabView()
                }
            }
            .environment(appState)
        }
    }
}
```

## Step 5: Build and Run

1. Select a simulator (iPhone 15 Pro recommended).
2. Press **⌘R** to build and run.
3. Complete onboarding flow.
4. Explore the Discover tab with sample POIs.

## Next Steps

- Implement ToursView with tour planning.
- Add RangeCalculatorView for EV range estimation.
- Complete ProfileView with vehicle and interest management.
- Integrate real location services.
- Add MapKit integration for visual route planning.

## Troubleshooting

**Issue**: "No such module 'AIRoadTripToursCore'"
- **Solution**: Ensure the package was added correctly. Try cleaning build folder (**⌘⇧K**) and rebuilding.

**Issue**: Build errors in Swift package
- **Solution**: Run `swift build` in the package directory first to verify it compiles.
