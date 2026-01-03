import Foundation
import AIRoadTripToursCore
import Logging

// Top-level code for executable main.swift
let logger = Logger(label: "com.airoadtriptours.demo")

print("""
╔═══════════════════════════════════════════════════════╗
║     AI Road Trip Tours - Phases 1-4 Demo             ║
║     User, Vehicle, POI & Narration Engine            ║
╚═══════════════════════════════════════════════════════╝

""")

let demo = DemoApplication()
await demo.run()

actor DemoApplication {
    private var currentUser: User?
    private let poiRepository: InMemoryPOIRepository

    init() {
        // Initialize with sample POIs
        self.poiRepository = InMemoryPOIRepository(initialPOIs: Self.createSamplePOIs())
    }

    func run() async {
        var shouldContinue = true

        while shouldContinue {
            printMainMenu()

            guard let choice = readLine()?.trimmingCharacters(in: .whitespaces) else {
                continue
            }

            switch choice {
            case "1":
                await createUserProfile()
            case "2":
                await viewUserProfile()
            case "3":
                await addVehicle()
            case "4":
                await setActiveVehicle()
            case "5":
                await calculateRange()
            case "6":
                await checkTripSafety()
            case "7":
                await addInterests()
            case "8":
                await searchNearbyPOIs()
            case "9":
                await filterPOIsByInterests()
            case "10":
                await findEVChargers()
            case "11":
                await viewPOIDetails()
            case "12":
                await demonstrateAllFeatures()
            case "13":
                await generateNarrationForPOI()
            case "14":
                await calculateNarrationTiming()
            case "15":
                await demonstrateNarrationQueue()
            case "16":
                await demonstratePhase4Features()
            case "17":
                print("\n👋 Thanks for testing AI Road Trip Tours!\n")
                shouldContinue = false
            default:
                print("\n❌ Invalid choice. Please try again.\n")
            }
        }
    }

    private func printMainMenu() {
        print("""
        ═══════════════════════════════════════════════════════
        MAIN MENU
        ═══════════════════════════════════════════════════════
        Phase 1: User & Vehicle Management
        1. Create User Profile
        2. View User Profile
        3. Add Vehicle
        4. Set Active Vehicle
        5. Calculate Range Estimate
        6. Check Trip Safety
        7. Add Interests

        Phase 2: POI Discovery
        8. Search Nearby POIs
        9. Filter POIs by My Interests
        10. Find EV Chargers
        11. View POI Details

        Phase 4: Narration Engine
        13. Generate Narration for POI
        14. Calculate Narration Timing
        15. Demonstrate Narration Queue

        Demos
        12. Run Full Demo (Phases 1-3)
        16. Run Phase 4 Demo (Narration)
        17. Exit

        Enter your choice:
        """, terminator: " ")
    }

    private func createUserProfile() async {
        print("\n📝 CREATE USER PROFILE")
        print("─────────────────────────────────────────────────────")

        print("Enter email: ", terminator: "")
        guard let email = readLine()?.trimmingCharacters(in: .whitespaces), !email.isEmpty else {
            print("❌ Email is required.\n")
            return
        }

        print("Enter display name: ", terminator: "")
        guard let name = readLine()?.trimmingCharacters(in: .whitespaces), !name.isEmpty else {
            print("❌ Display name is required.\n")
            return
        }

        currentUser = User(email: email, displayName: name)

        print("""

        ✅ User profile created successfully!

        📧 Email: \(email)
        👤 Display Name: \(name)
        🎫 Trial Expires: \(formatDate(currentUser!.trialExpiresAt))
        ⭐ Premium Access: \(currentUser!.hasPremiumAccess ? "Yes" : "No")

        """)
    }

    private func viewUserProfile() async {
        guard let user = currentUser else {
            print("\n❌ No user profile found. Create one first.\n")
            return
        }

        print("\n👤 USER PROFILE")
        print("─────────────────────────────────────────────────────")
        print("📧 Email: \(user.email)")
        print("👤 Display Name: \(user.displayName)")
        print("📅 Created: \(formatDate(user.createdAt))")
        print("🎫 Trial Expires: \(formatDate(user.trialExpiresAt))")
        print("⏰ Trial Active: \(user.isTrialActive ? "Yes" : "No")")
        print("💎 Subscription: \(user.hasActiveSubscription ? "Active" : "None")")
        print("⭐ Premium Access: \(user.hasPremiumAccess ? "Yes" : "No")")
        print("\n🎯 Interests (\(user.interests.count)):")
        if user.interests.isEmpty {
            print("   No interests added yet.")
        } else {
            for interest in user.interests {
                print("   • \(interest.name) (\(interest.category.rawValue))")
            }
        }
        print("\n🚗 Vehicles (\(user.vehicles.count)):")
        if user.vehicles.isEmpty {
            print("   No vehicles added yet.")
        } else {
            for vehicle in user.vehicles {
                let active = vehicle.id == user.activeVehicleId ? " ⭐" : ""
                print("   • \(vehicle.year) \(vehicle.make) \(vehicle.model)\(active)")
                print("     Battery: \(vehicle.batteryCapacityKWh) kWh, Range: \(vehicle.estimatedRangeMiles) mi")
            }
        }
        print()
    }

    private func addVehicle() async {
        guard var user = currentUser else {
            print("\n❌ No user profile found. Create one first.\n")
            return
        }

        print("\n🚗 ADD VEHICLE")
        print("─────────────────────────────────────────────────────")
        print("Popular EV presets:")
        print("1. Tesla Model 3 (2024)")
        print("2. Ford Mustang Mach-E (2024)")
        print("3. Chevrolet Bolt EUV (2024)")
        print("4. Nissan Leaf (2024)")
        print("5. Custom vehicle")
        print("\nSelect preset (1-5): ", terminator: "")

        guard let choice = readLine()?.trimmingCharacters(in: .whitespaces) else { return }

        let vehicle: EVProfile

        switch choice {
        case "1":
            vehicle = EVProfile(
                make: "Tesla",
                model: "Model 3",
                year: 2024,
                batteryCapacityKWh: 75.0,
                chargingPorts: [.nacs, .ccs],
                estimatedRangeMiles: 272.0,
                consumptionRateKWhPerMile: 0.276
            )
        case "2":
            vehicle = EVProfile(
                make: "Ford",
                model: "Mustang Mach-E",
                year: 2024,
                batteryCapacityKWh: 91.0,
                chargingPorts: [.ccs, .j1772],
                estimatedRangeMiles: 312.0,
                consumptionRateKWhPerMile: 0.291
            )
        case "3":
            vehicle = EVProfile(
                make: "Chevrolet",
                model: "Bolt EUV",
                year: 2024,
                batteryCapacityKWh: 65.0,
                chargingPorts: [.ccs, .j1772],
                estimatedRangeMiles: 247.0,
                consumptionRateKWhPerMile: 0.263
            )
        case "4":
            vehicle = EVProfile(
                make: "Nissan",
                model: "Leaf",
                year: 2024,
                batteryCapacityKWh: 60.0,
                chargingPorts: [.chademo, .j1772],
                estimatedRangeMiles: 212.0,
                consumptionRateKWhPerMile: 0.283
            )
        default:
            print("❌ Custom vehicle entry not yet implemented.\n")
            return
        }

        user.vehicles.append(vehicle)
        if user.activeVehicleId == nil {
            user.activeVehicleId = vehicle.id
        }
        currentUser = user

        print("""

        ✅ Vehicle added successfully!

        🚗 \(vehicle.year) \(vehicle.make) \(vehicle.model)
        🔋 Battery: \(vehicle.batteryCapacityKWh) kWh
        📏 EPA Range: \(vehicle.estimatedRangeMiles) miles
        ⚡ Consumption: \(vehicle.consumptionRateKWhPerMile) kWh/mi
        🔌 Charging Ports: \(vehicle.chargingPorts.map { $0.rawValue }.joined(separator: ", "))

        """)
    }

    private func setActiveVehicle() async {
        guard var user = currentUser else {
            print("\n❌ No user profile found. Create one first.\n")
            return
        }

        guard !user.vehicles.isEmpty else {
            print("\n❌ No vehicles found. Add a vehicle first.\n")
            return
        }

        print("\n⭐ SET ACTIVE VEHICLE")
        print("─────────────────────────────────────────────────────")
        for (index, vehicle) in user.vehicles.enumerated() {
            let active = vehicle.id == user.activeVehicleId ? " (current)" : ""
            print("\(index + 1). \(vehicle.year) \(vehicle.make) \(vehicle.model)\(active)")
        }
        print("\nSelect vehicle (1-\(user.vehicles.count)): ", terminator: "")

        guard let input = readLine()?.trimmingCharacters(in: .whitespaces),
              let index = Int(input),
              index >= 1 && index <= user.vehicles.count else {
            print("❌ Invalid selection.\n")
            return
        }

        user.activeVehicleId = user.vehicles[index - 1].id
        currentUser = user

        print("""

        ✅ Active vehicle set to: \(user.vehicles[index - 1].year) \(user.vehicles[index - 1].make) \(user.vehicles[index - 1].model)

        """)
    }

    private func calculateRange() async {
        guard let user = currentUser else {
            print("\n❌ No user profile found. Create one first.\n")
            return
        }

        guard let vehicle = user.activeVehicle else {
            print("\n❌ No active vehicle. Add and select a vehicle first.\n")
            return
        }

        print("\n📊 CALCULATE RANGE ESTIMATE")
        print("─────────────────────────────────────────────────────")
        print("🚗 Vehicle: \(vehicle.year) \(vehicle.make) \(vehicle.model)")

        print("\nCurrent battery percentage (0-100): ", terminator: "")
        guard let batteryInput = readLine()?.trimmingCharacters(in: .whitespaces),
              let battery = Double(batteryInput),
              battery >= 0 && battery <= 100 else {
            print("❌ Invalid battery percentage.\n")
            return
        }

        let batteryPercent = battery / 100.0

        print("\nSelect conditions:")
        print("1. Standard (70°F, flat terrain)")
        print("2. Cold weather (20°F)")
        print("3. Cold weather with 8hr parking (20°F)")
        print("4. Mountain driving (+3000ft elevation)")
        print("5. Extreme (20°F, 8hr parking, +3000ft elevation)")
        print("\nChoice (1-5): ", terminator: "")

        guard let condChoice = readLine()?.trimmingCharacters(in: .whitespaces) else { return }

        let conditions: DrivingConditions
        let conditionName: String

        switch condChoice {
        case "1":
            conditions = .standard
            conditionName = "Standard"
        case "2":
            conditions = DrivingConditions(temperatureFahrenheit: 20.0)
            conditionName = "Cold Weather"
        case "3":
            conditions = DrivingConditions(
                temperatureFahrenheit: 20.0,
                includesColdSoak: true,
                coldSoakHours: 8.0
            )
            conditionName = "Cold Weather + Parking"
        case "4":
            conditions = DrivingConditions(elevationChangeFeet: 3000.0)
            conditionName = "Mountain Driving"
        case "5":
            conditions = DrivingConditions(
                temperatureFahrenheit: 20.0,
                includesColdSoak: true,
                coldSoakHours: 8.0,
                elevationChangeFeet: 3000.0
            )
            conditionName = "Extreme Conditions"
        default:
            print("❌ Invalid choice.\n")
            return
        }

        let estimator = SimpleRangeEstimator()
        let range = estimator.estimateRange(
            for: vehicle,
            currentBatteryPercent: batteryPercent,
            conditions: conditions
        )

        print("""

        ═══════════════════════════════════════════════════════
        📊 RANGE ESTIMATE RESULTS
        ═══════════════════════════════════════════════════════
        🔋 Current Battery: \(Int(battery))%
        🌡️  Conditions: \(conditionName)
        📏 Estimated Range: \(String(format: "%.1f", range)) miles

        🚦 Status: \(rangeStatus(range: range, maxRange: vehicle.estimatedRangeMiles))

        """)
    }

    private func checkTripSafety() async {
        guard let user = currentUser else {
            print("\n❌ No user profile found. Create one first.\n")
            return
        }

        guard let vehicle = user.activeVehicle else {
            print("\n❌ No active vehicle. Add and select a vehicle first.\n")
            return
        }

        print("\n🛡️  CHECK TRIP SAFETY")
        print("─────────────────────────────────────────────────────")
        print("🚗 Vehicle: \(vehicle.year) \(vehicle.make) \(vehicle.model)")

        print("\nCurrent battery percentage (0-100): ", terminator: "")
        guard let batteryInput = readLine()?.trimmingCharacters(in: .whitespaces),
              let battery = Double(batteryInput),
              battery >= 0 && battery <= 100 else {
            print("❌ Invalid battery percentage.\n")
            return
        }

        print("Trip distance (miles): ", terminator: "")
        guard let distanceInput = readLine()?.trimmingCharacters(in: .whitespaces),
              let distance = Double(distanceInput),
              distance > 0 else {
            print("❌ Invalid distance.\n")
            return
        }

        print("\nExpected conditions:")
        print("1. Standard (70°F, flat terrain)")
        print("2. Cold weather (20°F)")
        print("3. Winter road trip (20°F, overnight parking)")
        print("4. Mountain driving (+3000ft elevation)")
        print("\nChoice (1-4): ", terminator: "")

        guard let condChoice = readLine()?.trimmingCharacters(in: .whitespaces) else { return }

        let conditions: DrivingConditions
        let conditionName: String

        switch condChoice {
        case "1":
            conditions = .standard
            conditionName = "Standard"
        case "2":
            conditions = DrivingConditions(temperatureFahrenheit: 20.0)
            conditionName = "Cold Weather"
        case "3":
            conditions = DrivingConditions(
                temperatureFahrenheit: 20.0,
                includesColdSoak: true,
                coldSoakHours: 8.0
            )
            conditionName = "Winter Road Trip"
        case "4":
            conditions = DrivingConditions(elevationChangeFeet: 3000.0)
            conditionName = "Mountain Driving"
        default:
            print("❌ Invalid choice.\n")
            return
        }

        let estimator = SimpleRangeEstimator()
        let isSafe = estimator.isTripSafe(
            vehicle: vehicle,
            currentBatteryPercent: battery / 100.0,
            distanceMiles: distance,
            conditions: conditions
        )

        let required = estimator.requiredBatteryForTrip(
            vehicle: vehicle,
            distanceMiles: distance,
            conditions: conditions
        )

        print("""

        ═══════════════════════════════════════════════════════
        🛡️  TRIP SAFETY ANALYSIS
        ═══════════════════════════════════════════════════════
        📍 Trip Distance: \(String(format: "%.1f", distance)) miles
        🔋 Current Battery: \(Int(battery))%
        🌡️  Conditions: \(conditionName)
        ⚡ Required Battery: \(String(format: "%.1f", required * 100))% (includes 15% safety buffer)

        \(isSafe ? "✅ TRIP IS SAFE" : "❌ TRIP IS NOT SAFE")

        \(isSafe ? "You have sufficient battery for this trip." : "⚠️  WARNING: Insufficient battery! Find charging stations along the route.")

        """)
    }

    private func addInterests() async {
        guard var user = currentUser else {
            print("\n❌ No user profile found. Create one first.\n")
            return
        }

        print("\n🎯 ADD INTERESTS")
        print("─────────────────────────────────────────────────────")
        print("Select interests to personalize your tours:")
        print("1. Hiking (adventure)")
        print("2. Local Food (food)")
        print("3. Historic Sites (history)")
        print("4. Scenic Views (scenic)")
        print("5. Wildlife Watching (wildlife)")
        print("6. Museums (culture)")
        print("7. Beach Activities (relaxation)")
        print("8. Shopping (shopping)")
        print("9. Live Entertainment (entertainment)")
        print("\nEnter numbers separated by commas (e.g., 1,2,4): ", terminator: "")

        guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else { return }

        let choices = input.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }

        for choice in choices {
            let interest: UserInterest?
            switch choice {
            case 1: interest = UserInterest(name: "Hiking", category: .adventure)
            case 2: interest = UserInterest(name: "Local Food", category: .food)
            case 3: interest = UserInterest(name: "Historic Sites", category: .history)
            case 4: interest = UserInterest(name: "Scenic Views", category: .scenic)
            case 5: interest = UserInterest(name: "Wildlife Watching", category: .wildlife)
            case 6: interest = UserInterest(name: "Museums", category: .culture)
            case 7: interest = UserInterest(name: "Beach Activities", category: .relaxation)
            case 8: interest = UserInterest(name: "Shopping", category: .shopping)
            case 9: interest = UserInterest(name: "Live Entertainment", category: .entertainment)
            default: interest = nil
            }

            if let interest {
                user.interests.insert(interest)
            }
        }

        currentUser = user

        print("""

        ✅ Interests added successfully!

        Your interests (\(user.interests.count)):
        """)
        for interest in user.interests {
            print("   • \(interest.name)")
        }
        print()
    }

    private func demonstrateAllFeatures() async {
        print("\n🎬 RUNNING FULL DEMO")
        print("═══════════════════════════════════════════════════════\n")

        // Create user
        print("1️⃣  Creating user profile...")
        currentUser = User(
            email: "demo@roadtrip.com",
            displayName: "Demo Traveler",
            interests: [
                UserInterest(name: "Scenic Views", category: .scenic),
                UserInterest(name: "Local Food", category: .food),
                UserInterest(name: "Hiking", category: .adventure)
            ]
        )
        print("   ✅ User created with 3 interests\n")
        try? await Task.sleep(for: .seconds(1))

        // Add vehicle
        print("2️⃣  Adding Tesla Model 3...")
        let tesla = EVProfile(
            make: "Tesla",
            model: "Model 3",
            year: 2024,
            batteryCapacityKWh: 75.0,
            chargingPorts: [.nacs, .ccs],
            estimatedRangeMiles: 272.0,
            consumptionRateKWhPerMile: 0.276
        )
        currentUser?.vehicles.append(tesla)
        currentUser?.activeVehicleId = tesla.id
        print("   ✅ Vehicle added and set as active\n")
        try? await Task.sleep(for: .seconds(1))

        // Range calculations
        print("3️⃣  Calculating ranges under different conditions...")
        let estimator = SimpleRangeEstimator()

        let standardRange = estimator.estimateRange(
            for: tesla,
            currentBatteryPercent: 0.80,
            conditions: .standard
        )
        print("   • Standard (80% battery): \(String(format: "%.1f", standardRange)) miles")

        let coldRange = estimator.estimateRange(
            for: tesla,
            currentBatteryPercent: 0.80,
            conditions: DrivingConditions(temperatureFahrenheit: 20.0)
        )
        print("   • Cold weather (80% battery): \(String(format: "%.1f", coldRange)) miles")

        let mountainRange = estimator.estimateRange(
            for: tesla,
            currentBatteryPercent: 0.80,
            conditions: DrivingConditions(elevationChangeFeet: 3000.0)
        )
        print("   • Mountain (+3000ft, 80% battery): \(String(format: "%.1f", mountainRange)) miles")
        print()
        try? await Task.sleep(for: .seconds(1))

        // Trip safety
        print("4️⃣  Checking trip safety...")
        let safeTripResult = estimator.isTripSafe(
            vehicle: tesla,
            currentBatteryPercent: 0.80,
            distanceMiles: 150.0,
            conditions: .standard
        )
        print("   • 150 mile trip @ 80% battery: \(safeTripResult ? "✅ SAFE" : "❌ UNSAFE")")

        let unsafeTripResult = estimator.isTripSafe(
            vehicle: tesla,
            currentBatteryPercent: 0.40,
            distanceMiles: 150.0,
            conditions: DrivingConditions(
                temperatureFahrenheit: 20.0,
                includesColdSoak: true,
                coldSoakHours: 8.0
            )
        )
        print("   • 150 mile winter trip @ 40% battery: \(unsafeTripResult ? "✅ SAFE" : "❌ UNSAFE")")
        print()
        try? await Task.sleep(for: .seconds(1))

        // Premium status
        print("5️⃣  Checking premium access...")
        guard let user = currentUser else { return }
        print("   • Trial expires: \(formatDate(user.trialExpiresAt))")
        print("   • Premium access: \(user.hasPremiumAccess ? "✅ Active" : "❌ Inactive")")
        print()

        print("""
        ═══════════════════════════════════════════════════════
        ✅ DEMO COMPLETE!

        All Phase 1 features demonstrated successfully.
        ═══════════════════════════════════════════════════════

        """)
    }

    // Phase 2: POI Discovery Functions

    private func searchNearbyPOIs() async {
        print("\n🗺️  SEARCH NEARBY POIs")
        print("─────────────────────────────────────────────────────")

        print("Select a location:")
        print("1. Portland, OR")
        print("2. Seattle, WA")
        print("3. San Francisco, CA")
        print("\nChoice (1-3): ", terminator: "")

        guard let choice = readLine()?.trimmingCharacters(in: .whitespaces) else { return }

        let location: GeoLocation
        let locationName: String

        switch choice {
        case "1":
            location = GeoLocation(latitude: 45.5152, longitude: -122.6784)
            locationName = "Portland, OR"
        case "2":
            location = GeoLocation(latitude: 47.6062, longitude: -122.3321)
            locationName = "Seattle, WA"
        case "3":
            location = GeoLocation(latitude: 37.7749, longitude: -122.4194)
            locationName = "San Francisco, CA"
        default:
            print("❌ Invalid choice.\n")
            return
        }

        print("Search radius (miles, default 10): ", terminator: "")
        let radiusInput = readLine()?.trimmingCharacters(in: .whitespaces)
        let radius = Double(radiusInput ?? "10") ?? 10.0

        do {
            let pois = try await poiRepository.findNearby(
                location: location,
                radiusMiles: radius,
                categories: nil
            )

            print("""

            ═══════════════════════════════════════════════════════
            📍 NEARBY POIs - \(locationName)
            ═══════════════════════════════════════════════════════
            Found \(pois.count) POIs within \(radius) miles

            """)

            for poi in pois.prefix(10) {
                let distance = poi.location.distance(to: location)
                let ratingText = poi.rating.map { "⭐ \(String(format: "%.1f", $0.averageRating))" } ?? "No rating"
                print("""
                📌 \(poi.name)
                   \(poi.category.rawValue) • \(String(format: "%.1f", distance)) miles away
                   \(ratingText)
                """)
            }

            if pois.count > 10 {
                print("   ... and \(pois.count - 10) more")
            }
            print()
        } catch {
            print("❌ Error searching POIs: \(error)\n")
        }
    }

    private func filterPOIsByInterests() async {
        guard let user = currentUser else {
            print("\n❌ No user profile found. Create one and add interests first.\n")
            return
        }

        guard !user.interests.isEmpty else {
            print("\n❌ No interests added. Add some interests first (option 7).\n")
            return
        }

        print("\n🎯 FILTER POIs BY YOUR INTERESTS")
        print("─────────────────────────────────────────────────────")
        print("Your interests:")
        for interest in user.interests {
            print("   • \(interest.name) (\(interest.category.rawValue))")
        }

        print("\nSelect location to search:")
        print("1. Portland, OR")
        print("2. Seattle, WA")
        print("\nChoice (1-2): ", terminator: "")

        guard let choice = readLine()?.trimmingCharacters(in: .whitespaces) else { return }

        let location: GeoLocation
        let locationName: String

        switch choice {
        case "1":
            location = GeoLocation(latitude: 45.5152, longitude: -122.6784)
            locationName = "Portland, OR"
        case "2":
            location = GeoLocation(latitude: 47.6062, longitude: -122.3321)
            locationName = "Seattle, WA"
        default:
            print("❌ Invalid choice.\n")
            return
        }

        do {
            let filter = POIFilter.forUser(user, near: location, radiusMiles: 25.0)
            let pois = try await poiRepository.find(matching: filter)

            print("""

            ═══════════════════════════════════════════════════════
            🎯 PERSONALIZED POIs - \(locationName)
            ═══════════════════════════════════════════════════════
            Found \(pois.count) POIs matching your interests

            """)

            for poi in pois.prefix(10) {
                let distance = poi.location.distance(to: location)
                let ratingText = poi.rating.map { "⭐ \(String(format: "%.1f", $0.averageRating))" } ?? "No rating"
                print("""
                📌 \(poi.name)
                   \(poi.category.rawValue) • \(String(format: "%.1f", distance)) miles away
                   \(ratingText)
                """)
            }

            if pois.count > 10 {
                print("   ... and \(pois.count - 10) more")
            }
            print()
        } catch {
            print("❌ Error filtering POIs: \(error)\n")
        }
    }

    private func findEVChargers() async {
        print("\n⚡ FIND EV CHARGERS")
        print("─────────────────────────────────────────────────────")

        print("Select location:")
        print("1. Portland, OR")
        print("2. Seattle, WA")
        print("\nChoice (1-2): ", terminator: "")

        guard let choice = readLine()?.trimmingCharacters(in: .whitespaces) else { return }

        let location: GeoLocation
        let locationName: String

        switch choice {
        case "1":
            location = GeoLocation(latitude: 45.5152, longitude: -122.6784)
            locationName = "Portland, OR"
        case "2":
            location = GeoLocation(latitude: 47.6062, longitude: -122.3321)
            locationName = "Seattle, WA"
        default:
            print("❌ Invalid choice.\n")
            return
        }

        do {
            let filter = POIFilter.evChargers(near: location, radiusMiles: 15.0)
            let chargers = try await poiRepository.find(matching: filter)

            print("""

            ═══════════════════════════════════════════════════════
            ⚡ EV CHARGERS - \(locationName)
            ═══════════════════════════════════════════════════════
            Found \(chargers.count) charging stations within 15 miles

            """)

            for charger in chargers {
                let distance = charger.location.distance(to: location)
                print("""
                🔌 \(charger.name)
                   \(String(format: "%.1f", distance)) miles away
                   Source: \(charger.source.rawValue)
                """)
            }

            if chargers.isEmpty {
                print("   No EV chargers found in this demo dataset.")
                print("   In production, this would query real charger APIs.")
            }
            print()
        } catch {
            print("❌ Error finding chargers: \(error)\n")
        }
    }

    private func viewPOIDetails() async {
        print("\n🔍 VIEW POI DETAILS")
        print("─────────────────────────────────────────────────────")

        do {
            let allPOIs = try await poiRepository.findAll()
            if allPOIs.isEmpty {
                print("No POIs available.\n")
                return
            }

            print("Select a POI:")
            for (index, poi) in allPOIs.prefix(15).enumerated() {
                print("\(index + 1). \(poi.name) (\(poi.category.rawValue))")
            }
            print("\nChoice (1-\(min(allPOIs.count, 15))): ", terminator: "")

            guard let input = readLine()?.trimmingCharacters(in: .whitespaces),
                  let index = Int(input),
                  index >= 1 && index <= min(allPOIs.count, 15) else {
                print("❌ Invalid choice.\n")
                return
            }

            let poi = allPOIs[index - 1]

            print("""

            ═══════════════════════════════════════════════════════
            📍 POI DETAILS
            ═══════════════════════════════════════════════════════
            📌 Name: \(poi.name)
            🏷️  Category: \(poi.category.rawValue)
            📍 Location: \(poi.location.latitude), \(poi.location.longitude)
            \(poi.location.address.map { "   Address: \($0)" } ?? "")

            """)

            if let description = poi.description {
                print("📝 Description: \(description)\n")
            }

            if let rating = poi.rating {
                let priceLevel = rating.priceLevel.map { String(repeating: "$", count: $0) } ?? "N/A"
                print("""
                ⭐ Rating: \(String(format: "%.1f", rating.averageRating)) (\(rating.totalRatings) reviews)
                💰 Price: \(priceLevel)

                """)
            }

            if let hours = poi.hours {
                let openStatus = hours.isOpenNow.map { $0 ? "🟢 Open Now" : "🔴 Closed" } ?? ""
                print("🕐 Hours: \(hours.description) \(openStatus)\n")
            }

            if let contact = poi.contact {
                if let phone = contact.phone {
                    print("📞 Phone: \(phone)")
                }
                if let website = contact.website {
                    print("🌐 Website: \(website)")
                }
                print()
            }

            if !poi.tags.isEmpty {
                print("🏷️  Tags: \(poi.tags.sorted().joined(separator: ", "))\n")
            }

            print("📦 Source: \(poi.source.rawValue)")
            print("📅 Added: \(formatDate(poi.createdAt))\n")

        } catch {
            print("❌ Error loading POI details: \(error)\n")
        }
    }

    // Phase 4: Narration Functions

    private func generateNarrationForPOI() async {
        print("\n📢 GENERATE NARRATION FOR POI")
        print("─────────────────────────────────────────────────────")

        do {
            let allPOIs = try await poiRepository.findAll()
            if allPOIs.isEmpty {
                print("No POIs available.\n")
                return
            }

            print("Select a POI to generate narration:")
            for (index, poi) in allPOIs.prefix(10).enumerated() {
                print("\(index + 1). \(poi.name) (\(poi.category.rawValue))")
            }
            print("\nChoice (1-\(min(allPOIs.count, 10))): ", terminator: "")

            guard let input = readLine()?.trimmingCharacters(in: .whitespaces),
                  let index = Int(input),
                  index >= 1 && index <= min(allPOIs.count, 10) else {
                print("❌ Invalid choice.\n")
                return
            }

            let poi = allPOIs[index - 1]

            print("Target duration (seconds, default 180): ", terminator: "")
            let durationInput = readLine()?.trimmingCharacters(in: .whitespaces)
            let duration = Double(durationInput ?? "180") ?? 180.0

            let generator = MockContentGenerator()
            let narration = try await generator.generateNarration(
                for: poi,
                targetDurationSeconds: duration,
                userInterests: currentUser?.interests ?? []
            )

            print("""

            ═══════════════════════════════════════════════════════
            📢 GENERATED NARRATION
            ═══════════════════════════════════════════════════════
            📍 POI: \(narration.poiName)
            📝 Title: \(narration.title)
            ⏱️  Duration: \(String(format: "%.1f", narration.durationSeconds)) seconds
            📊 Word Count: \(narration.wordCount) words
            📅 Generated: \(formatDate(narration.generatedAt))
            🔊 Status: \(narration.status.rawValue)

            ─────────────────────────────────────────────────────
            CONTENT:
            ─────────────────────────────────────────────────────
            \(narration.content)
            ═══════════════════════════════════════════════════════

            """)
        } catch {
            print("❌ Error generating narration: \(error)\n")
        }
    }

    private func calculateNarrationTiming() async {
        print("\n⏰ CALCULATE NARRATION TIMING")
        print("─────────────────────────────────────────────────────")

        print("Narration duration (seconds, default 180): ", terminator: "")
        let durationInput = readLine()?.trimmingCharacters(in: .whitespaces)
        let duration = Double(durationInput ?? "180") ?? 180.0

        print("Distance from POI (miles, default 5.0): ", terminator: "")
        let distanceInput = readLine()?.trimmingCharacters(in: .whitespaces)
        let distance = Double(distanceInput ?? "5.0") ?? 5.0

        print("Current speed (mph, default 30): ", terminator: "")
        let speedInput = readLine()?.trimmingCharacters(in: .whitespaces)
        let speed = Double(speedInput ?? "30") ?? 30.0

        let testNarration = Narration(
            poiId: UUID(),
            poiName: "Test POI",
            title: "About Test POI",
            content: String(repeating: "word ", count: Int((duration / 60.0) * 150)),
            durationSeconds: duration
        )

        let calculator = StandardNarrationTimingCalculator()
        let timing = calculator.calculateTiming(
            for: testNarration,
            distanceFromPOIMiles: distance,
            currentSpeedMph: speed,
            targetArrivalWindowSeconds: 60...120
        )

        print("""

        ═══════════════════════════════════════════════════════
        ⏰ NARRATION TIMING RESULTS
        ═══════════════════════════════════════════════════════
        📏 Distance from POI: \(String(format: "%.2f", distance)) miles
        🚗 Current Speed: \(String(format: "%.0f", speed)) mph
        ⏱️  Narration Duration: \(String(format: "%.0f", duration)) seconds

        ─────────────────────────────────────────────────────
        📍 Trigger Distance: \(String(format: "%.2f", timing.triggerDistanceMiles)) miles from POI
        ⏰ Time to Trigger: \(String(format: "%.0f", timing.timeToTriggerSeconds)) seconds
        🛣️  Travel During Narration: \(String(format: "%.2f", timing.narrationTravelDistanceMiles)) miles
        📍 Distance at Completion: \(String(format: "%.2f", timing.distanceFromPOIOnCompletionMiles)) miles from POI

        \(timing.isValid ? "✅ TIMING IS VALID" : "❌ TIMING IS INVALID - too close to POI")
        ═══════════════════════════════════════════════════════

        """)
    }

    private func demonstrateNarrationQueue() async {
        print("\n🎵 NARRATION QUEUE DEMONSTRATION")
        print("═══════════════════════════════════════════════════════\n")

        do {
            let pois = try await poiRepository.findAll().prefix(3)
            let queue = NarrationQueue()
            let generator = MockContentGenerator()

            print("1️⃣  Generating narrations for 3 POIs...")
            var narrations: [Narration] = []
            for poi in pois {
                let narration = try await generator.generateNarration(
                    for: poi,
                    targetDurationSeconds: 120.0,
                    userInterests: []
                )
                narrations.append(narration)
                print("   ✅ Generated for \(poi.name)")
            }

            print("\n2️⃣  Enqueueing narrations...")
            await queue.enqueue(narrations)
            let count = await queue.pendingCount()
            print("   ✅ \(count) narrations in queue\n")

            print("3️⃣  Playing narrations...")
            while let current = await queue.next() {
                print("   ▶️  Now Playing: \(current.poiName)")
                await queue.updateStatus(current.id, status: .playing)
                try? await Task.sleep(for: .seconds(1))

                await queue.updateStatus(current.id, status: .completed)
                print("   ✅ Completed: \(current.poiName)")
                try? await Task.sleep(for: .seconds(0.5))
            }

            let allNarrations = await queue.all()
            let completed = allNarrations.filter { $0.status == .completed }
            print("""

            ═══════════════════════════════════════════════════════
            ✅ QUEUE DEMONSTRATION COMPLETE
            ═══════════════════════════════════════════════════════
            Total narrations: \(allNarrations.count)
            Completed: \(completed.count)
            Pending: \(await queue.pendingCount())
            ═══════════════════════════════════════════════════════

            """)
        } catch {
            print("❌ Error demonstrating queue: \(error)\n")
        }
    }

    private func demonstratePhase4Features() async {
        print("\n🎬 PHASE 4 DEMONSTRATION - NARRATION ENGINE")
        print("═══════════════════════════════════════════════════════\n")

        do {
            let pois = try await poiRepository.findAll().prefix(3)
            let generator = MockContentGenerator()
            let calculator = StandardNarrationTimingCalculator()

            print("1️⃣  AI Content Generation...")
            for poi in pois {
                let narration = try await generator.generateNarration(
                    for: poi,
                    targetDurationSeconds: 150.0,
                    userInterests: []
                )
                print("""
                   ✅ \(poi.name)
                      Duration: \(String(format: "%.0f", narration.durationSeconds))s, Words: \(narration.wordCount)
                """)
            }
            print()
            try? await Task.sleep(for: .seconds(1))

            print("2️⃣  Narration Timing Calculations...")
            let scenarios: [(speed: Double, distance: Double, name: String)] = [
                (30.0, 3.0, "City driving"),
                (60.0, 5.0, "Highway driving"),
                (45.0, 2.0, "Suburban driving")
            ]

            for scenario in scenarios {
                let testNarration = Narration(
                    poiId: UUID(),
                    poiName: "Test",
                    title: "Test",
                    content: String(repeating: "word ", count: 300),
                    durationSeconds: 120.0
                )

                let timing = calculator.calculateTiming(
                    for: testNarration,
                    distanceFromPOIMiles: scenario.distance,
                    currentSpeedMph: scenario.speed,
                    targetArrivalWindowSeconds: 60...120
                )

                let status = timing.isValid ? "✅" : "❌"
                print("""
                   \(status) \(scenario.name) - \(String(format: "%.0f", scenario.speed)) mph
                      Trigger at \(String(format: "%.2f", timing.triggerDistanceMiles)) miles
                      Complete with \(String(format: "%.2f", timing.distanceFromPOIOnCompletionMiles)) miles to go
                """)
            }
            print()
            try? await Task.sleep(for: .seconds(1))

            print("3️⃣  Queue Management...")
            let queue = NarrationQueue()
            var narrations: [Narration] = []
            for poi in pois {
                let narration = try await generator.generateNarration(
                    for: poi,
                    targetDurationSeconds: 90.0,
                    userInterests: []
                )
                narrations.append(narration)
            }

            await queue.enqueue(narrations)
            print("   ✅ Enqueued \(narrations.count) narrations")

            if let first = await queue.next() {
                await queue.updateStatus(first.id, status: .playing)
                print("   ▶️  Playing: \(first.poiName)")
                await queue.updateStatus(first.id, status: .completed)
                print("   ✅ Completed: \(first.poiName)")
            }
            print("   📊 Remaining: \(await queue.pendingCount())")
            print()

            print("""
            ═══════════════════════════════════════════════════════
            ✅ PHASE 4 DEMONSTRATION COMPLETE!

            Features Demonstrated:
            • AI-generated narration content tailored to POI types
            • Precise timing calculations for different speeds
            • Queue management with status tracking
            • Integration with POI discovery system

            Phase 4: Narration Engine is fully functional!
            ═══════════════════════════════════════════════════════

            """)
        } catch {
            print("❌ Error during demonstration: \(error)\n")
        }
    }

    // Sample POI data
    static func createSamplePOIs() -> [POI] {
        [
            POI(
                name: "Multnomah Falls",
                description: "A spectacular 620-foot waterfall in the Columbia River Gorge, one of Oregon's most visited natural attractions.",
                category: .waterfall,
                location: GeoLocation(
                    latitude: 45.5762,
                    longitude: -122.1153,
                    address: "Multnomah Falls Lodge, Bridal Veil, OR 97010"
                ),
                hours: POIHours(description: "Open 24 hours", isOpenNow: true),
                rating: POIRating(averageRating: 4.8, totalRatings: 5000, priceLevel: 1),
                source: .curated,
                tags: ["scenic", "nature", "waterfall", "hiking", "photography"]
            ),
            POI(
                name: "Portland Japanese Garden",
                description: "A traditional Japanese garden nestled in the hills of Portland, featuring authentic Japanese architecture and horticulture.",
                category: .park,
                location: GeoLocation(
                    latitude: 45.5195,
                    longitude: -122.7057,
                    address: "611 SW Kingston Ave, Portland, OR 97205"
                ),
                contact: POIContact(
                    phone: "+1-503-223-1321",
                    website: "https://japanesegarden.org"
                ),
                hours: POIHours(description: "Mon-Sun 10am-7pm", isOpenNow: true),
                rating: POIRating(averageRating: 4.7, totalRatings: 2000, priceLevel: 2),
                source: .curated,
                tags: ["garden", "peaceful", "cultural", "photography"]
            ),
            POI(
                name: "Voodoo Doughnut",
                description: "Famous Portland doughnut shop known for creative and unconventional flavors.",
                category: .restaurant,
                location: GeoLocation(
                    latitude: 45.5228,
                    longitude: -122.6731,
                    address: "22 SW 3rd Ave, Portland, OR 97204"
                ),
                contact: POIContact(
                    phone: "+1-503-241-4704",
                    website: "https://voodoodoughnut.com"
                ),
                hours: POIHours(description: "Open 24 hours", isOpenNow: true),
                rating: POIRating(averageRating: 4.2, totalRatings: 10000, priceLevel: 1),
                source: .yelp,
                tags: ["famous", "dessert", "quirky", "late-night"]
            ),
            POI(
                name: "Pike Place Market",
                description: "Iconic Seattle public market featuring fresh seafood, local produce, and unique crafts.",
                category: .attraction,
                location: GeoLocation(
                    latitude: 47.6097,
                    longitude: -122.3422,
                    address: "85 Pike St, Seattle, WA 98101"
                ),
                contact: POIContact(
                    phone: "+1-206-682-7453",
                    website: "https://pikeplacemarket.org"
                ),
                hours: POIHours(description: "Mon-Sun 9am-6pm", isOpenNow: true),
                rating: POIRating(averageRating: 4.6, totalRatings: 8000, priceLevel: 2),
                source: .google,
                tags: ["shopping", "food", "historic", "tourist-attraction"]
            ),
            POI(
                name: "Columbia River Gorge Scenic Drive",
                description: "One of the most beautiful scenic drives in America, featuring waterfalls, hiking trails, and stunning vistas.",
                category: .scenic,
                location: GeoLocation(
                    latitude: 45.6878,
                    longitude: -121.9405,
                    address: "Columbia River Gorge, OR"
                ),
                hours: POIHours(description: "Open 24 hours", isOpenNow: true),
                rating: POIRating(averageRating: 4.9, totalRatings: 3500, priceLevel: 1),
                source: .curated,
                tags: ["scenic", "driving", "nature", "photography", "waterfalls"]
            ),
            POI(
                name: "Crater Lake National Park",
                description: "America's deepest lake, known for its intense blue color and dramatic volcanic landscape.",
                category: .park,
                location: GeoLocation(
                    latitude: 42.8684,
                    longitude: -122.1685,
                    address: "Crater Lake, OR 97604"
                ),
                contact: POIContact(
                    website: "https://nps.gov/crla"
                ),
                hours: POIHours(description: "Seasonal, check website", isOpenNow: true),
                rating: POIRating(averageRating: 4.9, totalRatings: 4200, priceLevel: 1),
                source: .curated,
                tags: ["national-park", "scenic", "hiking", "camping", "lake"]
            ),
            POI(
                name: "Powell's City of Books",
                description: "World's largest independent bookstore, occupying a full city block in Portland.",
                category: .shopping,
                location: GeoLocation(
                    latitude: 45.5230,
                    longitude: -122.6814,
                    address: "1005 W Burnside St, Portland, OR 97209"
                ),
                contact: POIContact(
                    phone: "+1-503-228-4651",
                    website: "https://powells.com"
                ),
                hours: POIHours(description: "Daily 9am-9pm", isOpenNow: true),
                rating: POIRating(averageRating: 4.7, totalRatings: 6000, priceLevel: 2),
                source: .google,
                tags: ["books", "shopping", "cultural", "iconic"]
            ),
            POI(
                name: "Mount Hood",
                description: "Oregon's highest peak and a year-round playground for outdoor enthusiasts.",
                category: .hiking,
                location: GeoLocation(
                    latitude: 45.3736,
                    longitude: -121.6960,
                    address: "Mount Hood, OR"
                ),
                hours: POIHours(description: "Open 24 hours", isOpenNow: true),
                rating: POIRating(averageRating: 4.8, totalRatings: 7500, priceLevel: 1),
                source: .curated,
                tags: ["mountain", "hiking", "skiing", "scenic", "adventure"]
            ),
            POI(
                name: "Cannon Beach",
                description: "Picturesque Oregon coast beach featuring the iconic Haystack Rock.",
                category: .beach,
                location: GeoLocation(
                    latitude: 45.8912,
                    longitude: -123.9615,
                    address: "Cannon Beach, OR 97110"
                ),
                hours: POIHours(description: "Open 24 hours", isOpenNow: true),
                rating: POIRating(averageRating: 4.8, totalRatings: 5200, priceLevel: 1),
                source: .curated,
                tags: ["beach", "scenic", "photography", "tide-pools", "family-friendly"]
            ),
            POI(
                name: "Oregon Museum of Science and Industry (OMSI)",
                description: "Interactive science museum with exhibits, planetarium, and submarine tours.",
                category: .museum,
                location: GeoLocation(
                    latitude: 45.5089,
                    longitude: -122.6649,
                    address: "1945 SE Water Ave, Portland, OR 97214"
                ),
                contact: POIContact(
                    phone: "+1-503-797-4000",
                    website: "https://omsi.edu"
                ),
                hours: POIHours(description: "Tue-Sun 9:30am-5:30pm", isOpenNow: false),
                rating: POIRating(averageRating: 4.5, totalRatings: 3800, priceLevel: 2),
                source: .google,
                tags: ["museum", "science", "family-friendly", "educational"]
            )
        ]
    }

    // Helper functions
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func rangeStatus(range: Double, maxRange: Double) -> String {
        let percentage = (range / maxRange) * 100
        if percentage > 70 {
            return "🟢 Excellent range"
        } else if percentage > 40 {
            return "🟡 Moderate range - plan charging stops"
        } else {
            return "🔴 Limited range - charge soon"
        }
    }
}
