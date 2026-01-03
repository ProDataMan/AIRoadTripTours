# AI Road Trip Tours

An AI-powered mapping, navigation, and guided tour iOS app for road trippers and sunday drivers.

## Phase 1: User Profile & Vehicle Management (Complete)

This phase establishes the foundation for personalized tours and EV safety features.

### Features Implemented

#### User Profile Management

- User account model with interests and preferences.
- 90-day trial period tracking with automatic expiration calculation.
- Premium access management (trial or subscription-based).
- Multiple interest categories for tour personalization:
  - Nature, Food, History, Entertainment, Adventure, Culture, Shopping, Relaxation, Scenic, Wildlife.

#### EV Vehicle Profile

- Comprehensive vehicle specifications:
  - Make, model, year.
  - Battery capacity (kWh).
  - Charging port compatibility (Tesla, CCS, CHAdeMO, J1772, NACS).
  - EPA-rated range and consumption rate.
- Multiple vehicle support per user.
- Active vehicle selection for trip planning.

#### Range Estimation & Safety

- Protocol-oriented range estimation with pluggable implementations.
- Simple range estimator with condition adjustments:
  - Cold weather impact (temperature-based range reduction).
  - Cold soak energy loss for extended parking in freezing temperatures.
  - Elevation change impact on battery consumption.
  - Configurable safety buffer (default 15%).
- Trip safety validation to prevent stranding.

### Architecture

#### Modules

- **AIRoadTripToursCore**: Domain models and protocols.
  - `UserProfile`: User account and preferences.
  - `Vehicle`: EV specifications and capabilities.
  - `Interest`: Tour content personalization.
  - `RangeEstimator`: Battery range calculation protocol.
- **AIRoadTripToursServices**: Business logic and services (placeholder for Phase 2+).

#### Design Principles

- Protocol-oriented design for extensibility.
- Value semantics (structs) for domain models.
- Sendable conformance for Swift Concurrency.
- Explicit error handling with typed errors.
- Comprehensive test coverage (27 tests, 100% passing).

### Dependencies

- Swift 6.2+.
- iOS 17+ / macOS 14+.
- Swift Log (structured logging).
- Swift OpenAPI Generator & Runtime (future API integration).
- Swift Testing (test framework).

### Running Tests

```bash
swift test --no-parallel
```

### Building the Project

```bash
swift build
```

### Usage Examples

#### Creating a User Profile

```swift
import AIRoadTripToursCore

let user = User(
    email: "driver@example.com",
    displayName: "Road Tripper",
    interests: [
        UserInterest(name: "Hiking", category: .adventure),
        UserInterest(name: "Local Food", category: .food),
        UserInterest(name: "Scenic Views", category: .scenic)
    ]
)

print(user.isTrialActive)        // true
print(user.hasPremiumAccess)     // true
print(user.trialExpiresAt)       // 90 days from creation
```

#### Adding an EV Profile

```swift
let tesla = EVProfile(
    make: "Tesla",
    model: "Model 3",
    year: 2024,
    batteryCapacityKWh: 75.0,
    chargingPorts: [.nacs, .ccs],
    estimatedRangeMiles: 272.0,
    consumptionRateKWhPerMile: 0.276
)

var user = existingUser
user.vehicles.append(tesla)
user.activeVehicleId = tesla.id
```

#### Estimating Range & Trip Safety

```swift
let estimator = SimpleRangeEstimator(safetyBufferPercent: 0.15)

let winterConditions = DrivingConditions(
    temperatureFahrenheit: 25.0,
    includesColdSoak: true,
    coldSoakHours: 8.0,
    elevationChangeFeet: 2000.0
)

// Check remaining range
let range = estimator.estimateRange(
    for: tesla,
    currentBatteryPercent: 0.80,
    conditions: winterConditions
)
print("Estimated range: \(range) miles")

// Validate trip safety
let isSafe = estimator.isTripSafe(
    vehicle: tesla,
    currentBatteryPercent: 0.80,
    distanceMiles: 120.0,
    conditions: winterConditions
)
print("Trip is safe: \(isSafe)")
```

### Test Coverage

- **27 tests across 7 test suites**.
- **Unit tests** (tagged `.small`).
- Test categories:
  - User profile creation and trial management.
  - Premium access validation.
  - Vehicle profile management.
  - Range estimation under standard conditions.
  - Cold weather range impact.
  - Elevation change impact.
  - Safety buffer calculations.

### Next Steps: Phase 2

Phase 2 focuses on Point of Interest (POI) discovery and management:

- POI data model with location and metadata.
- Interest-based POI filtering.
- Integration with public APIs (Yelp, Google Places, Foursquare).
- User-submitted POI suggestions.
- Review and rating system.

### Project Timeline

- **Phase 1**: User Profile & Vehicle Management (Complete).
- **Phase 2**: POI Discovery & Management (Planned).
- **Phase 3**: Tour Planning & Basic Navigation (Planned).
- **Phase 4**: Narration Engine (Planned).
- **Phase 5**: User Contributions & Community (Planned).
- **Phase 6**: Offline & Premium Features (Planned).

### License

Proprietary - All Rights Reserved.

### Contact

For questions or feedback, contact the development team.
