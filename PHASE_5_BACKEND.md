# Phase 5: Backend Integration - Implementation Plan

## Overview

Phase 5 transforms AI Road Trip Tours from a standalone iOS app into a cloud-connected service with persistent
user data, real-time POI updates, AI-powered narration generation, and multi-device sync.

## Architecture

### Backend Stack (Recommended)

**Option A: Swift Vapor Backend** (Recommended for Swift team)
- Language: Swift 6.1+
- Framework: Vapor 4.x
- Database: PostgreSQL 15+
- Hosting: AWS/GCP/Azure
- Benefits: Code sharing with iOS app, native Swift concurrency

**Option B: Node.js Backend** (Alternative)
- Language: TypeScript
- Framework: Express or NestJS
- Database: PostgreSQL 15+
- Benefits: Large ecosystem, easy deployment

**API Design**
- REST API with OpenAPI 3.0 specification
- JSON request/response format
- JWT-based authentication
- Rate limiting and throttling
- API versioning (/v1/...)

### Service Architecture

```
┌─────────────────────────────────────────┐
│         iOS App (Swift)                 │
│  ┌────────────────────────────────┐     │
│  │   AIRoadTripToursApp           │     │
│  │   (Presentation Layer)         │     │
│  └────────────────────────────────┘     │
│              ↓ HTTP/JSON                │
│  ┌────────────────────────────────┐     │
│  │   API Client Layer             │     │
│  │   - AuthService                │     │
│  │   - UserService                │     │
│  │   - POIService                 │     │
│  │   - TourService                │     │
│  │   - NarrationService           │     │
│  └────────────────────────────────┘     │
└─────────────────────────────────────────┘
                   ↓ HTTPS
┌─────────────────────────────────────────┐
│      Backend API Server                 │
│  ┌────────────────────────────────┐     │
│  │   API Gateway / Load Balancer  │     │
│  └────────────────────────────────┘     │
│              ↓                          │
│  ┌────────────────────────────────┐     │
│  │   Application Server           │     │
│  │   - Authentication             │     │
│  │   - User Management            │     │
│  │   - POI Management             │     │
│  │   - Tour Management            │     │
│  │   - Narration Generation       │     │
│  └────────────────────────────────┘     │
│              ↓                          │
│  ┌────────────────────────────────┐     │
│  │   Database (PostgreSQL)        │     │
│  │   - users                      │     │
│  │   - vehicles                   │     │
│  │   - pois                       │     │
│  │   - tours                      │     │
│  │   - narrations                 │     │
│  └────────────────────────────────┘     │
└─────────────────────────────────────────┘
                   ↓ External APIs
┌─────────────────────────────────────────┐
│      External Services                  │
│  - OpenAI GPT-4 (Narration)             │
│  - Google Places API (POI Discovery)    │
│  - NREL API (EV Chargers)               │
│  - Mapbox API (Routing)                 │
└─────────────────────────────────────────┘
```

## Implementation Steps

### Step 1: API Specification (Week 1)

**Define OpenAPI Specification**

File: `api-spec.yaml`

```yaml
openapi: 3.0.0
info:
  title: AI Road Trip Tours API
  version: 1.0.0
  description: Backend API for AI Road Trip Tours iOS app

servers:
  - url: https://api.airoadtriptours.com/v1
    description: Production server
  - url: https://staging-api.airoadtriptours.com/v1
    description: Staging server

paths:
  /auth/register:
    post:
      summary: Register new user
      tags: [Authentication]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                email:
                  type: string
                  format: email
                password:
                  type: string
                  format: password
                displayName:
                  type: string
      responses:
        '201':
          description: User created successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/AuthResponse'
        '400':
          description: Invalid input
        '409':
          description: Email already exists

  /auth/login:
    post:
      summary: Login user
      tags: [Authentication]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                email:
                  type: string
                password:
                  type: string
      responses:
        '200':
          description: Login successful
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/AuthResponse'
        '401':
          description: Invalid credentials

  /users/me:
    get:
      summary: Get current user profile
      tags: [Users]
      security:
        - bearerAuth: []
      responses:
        '200':
          description: User profile
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'

  /pois/search:
    get:
      summary: Search for POIs
      tags: [POIs]
      security:
        - bearerAuth: []
      parameters:
        - name: latitude
          in: query
          schema:
            type: number
        - name: longitude
          in: query
          schema:
            type: number
        - name: radius
          in: query
          schema:
            type: number
        - name: categories
          in: query
          schema:
            type: array
            items:
              type: string
      responses:
        '200':
          description: List of POIs
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/POI'

  /narrations/generate:
    post:
      summary: Generate AI narration for POI
      tags: [Narrations]
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                poiId:
                  type: string
                  format: uuid
                targetDuration:
                  type: number
                userInterests:
                  type: array
                  items:
                    type: string
      responses:
        '201':
          description: Narration generated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Narration'

components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

  schemas:
    AuthResponse:
      type: object
      properties:
        token:
          type: string
        expiresAt:
          type: string
          format: date-time
        user:
          $ref: '#/components/schemas/User'

    User:
      type: object
      properties:
        id:
          type: string
          format: uuid
        email:
          type: string
        displayName:
          type: string
        interests:
          type: array
          items:
            $ref: '#/components/schemas/Interest'
        vehicles:
          type: array
          items:
            $ref: '#/components/schemas/Vehicle'
        createdAt:
          type: string
          format: date-time

    POI:
      type: object
      properties:
        id:
          type: string
          format: uuid
        name:
          type: string
        description:
          type: string
        category:
          type: string
        location:
          $ref: '#/components/schemas/Location'
        rating:
          $ref: '#/components/schemas/Rating'

    Narration:
      type: object
      properties:
        id:
          type: string
          format: uuid
        poiId:
          type: string
          format: uuid
        title:
          type: string
        content:
          type: string
        durationSeconds:
          type: number
        generatedAt:
          type: string
          format: date-time
```

**Tasks**:
- [ ] Complete OpenAPI specification for all endpoints
- [ ] Validate spec with Swagger Editor
- [ ] Generate API documentation
- [ ] Review with team

### Step 2: Backend Implementation (Weeks 2-4)

**Database Schema**

```sql
-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    display_name TEXT NOT NULL,
    trial_expires_at TIMESTAMP NOT NULL DEFAULT (NOW() + INTERVAL '90 days'),
    subscription_status TEXT DEFAULT 'trial',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- User interests table
CREATE TABLE user_interests (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    interest_name TEXT NOT NULL,
    interest_category TEXT NOT NULL,
    PRIMARY KEY (user_id, interest_name)
);

-- Vehicles table
CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    make TEXT NOT NULL,
    model TEXT NOT NULL,
    year INTEGER NOT NULL,
    battery_capacity_kwh REAL NOT NULL,
    estimated_range_miles REAL NOT NULL,
    is_active BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

-- POIs table
CREATE TABLE pois (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    address TEXT,
    rating_average REAL,
    rating_total INTEGER,
    price_level INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Narrations table
CREATE TABLE narrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    poi_id UUID REFERENCES pois(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    duration_seconds REAL NOT NULL,
    generated_at TIMESTAMP DEFAULT NOW()
);

-- Tours table
CREATE TABLE tours (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_pois_location ON pois (latitude, longitude);
CREATE INDEX idx_narrations_user ON narrations (user_id);
CREATE INDEX idx_tours_user ON tours (user_id);
```

**Vapor Server Implementation**

```swift
// main.swift
import Vapor

let app = Application(.development)
defer { app.shutdown() }

try configure(app)
try app.run()

// configure.swift
import Vapor
import Fluent
import FluentPostgresDriver

public func configure(_ app: Application) throws {
    // Database
    app.databases.use(.postgres(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: 5432,
        username: Environment.get("DATABASE_USER") ?? "postgres",
        password: Environment.get("DATABASE_PASSWORD") ?? "",
        database: Environment.get("DATABASE_NAME") ?? "airoadtriptours"
    ), as: .psql)

    // Migrations
    app.migrations.add(CreateUsers())
    app.migrations.add(CreateVehicles())
    app.migrations.add(CreatePOIs())
    app.migrations.add(CreateNarrations())

    // Middleware
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    app.middleware.use(CORSMiddleware())

    // Routes
    try routes(app)
}

// routes.swift
import Vapor

func routes(_ app: Application) throws {
    let authController = AuthController()
    let userController = UserController()
    let poiController = POIController()
    let narrationController = NarrationController()

    // Public routes
    let auth = app.grouped("auth")
    auth.post("register", use: authController.register)
    auth.post("login", use: authController.login)

    // Protected routes
    let protected = app.grouped("api", "v1")
        .grouped(JWTAuthenticator())

    protected.get("users", "me", use: userController.getProfile)
    protected.put("users", "me", use: userController.updateProfile)

    protected.get("pois", "search", use: poiController.search)
    protected.post("narrations", "generate", use: narrationController.generate)
}
```

**Tasks**:
- [ ] Set up Vapor project
- [ ] Implement database models and migrations
- [ ] Create authentication system (JWT)
- [ ] Implement user management endpoints
- [ ] Implement POI management endpoints
- [ ] Integrate OpenAI API for narration generation
- [ ] Add request validation and error handling
- [ ] Write integration tests
- [ ] Deploy to staging environment

### Step 3: iOS Client Integration (Weeks 5-6)

**API Client Implementation**

Create new target: `AIRoadTripToursAPI`

```swift
// Sources/AIRoadTripToursAPI/APIClient.swift
import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

public actor APIClient {
    private let client: Client
    private let serverURL: URL
    private var authToken: String?

    public init(serverURL: URL) {
        self.serverURL = serverURL
        self.client = Client(
            serverURL: serverURL,
            transport: URLSessionTransport()
        )
    }

    public func setAuthToken(_ token: String) {
        self.authToken = token
    }

    public func register(email: String, password: String, displayName: String) async throws -> AuthResponse {
        let request = Operations.AuthRegister.Input(
            body: .json(.init(
                email: email,
                password: password,
                displayName: displayName
            ))
        )
        let response = try await client.authRegister(request)
        return try response.ok.body.json
    }

    public func login(email: String, password: String) async throws -> AuthResponse {
        let request = Operations.AuthLogin.Input(
            body: .json(.init(
                email: email,
                password: password
            ))
        )
        let response = try await client.authLogin(request)
        let authResponse = try response.ok.body.json
        await setAuthToken(authResponse.token)
        return authResponse
    }

    public func getUserProfile() async throws -> User {
        guard let token = authToken else {
            throw APIError.unauthorized
        }

        let request = Operations.GetUserProfile.Input(
            headers: .init(Authorization: "Bearer \(token)")
        )
        let response = try await client.getUserProfile(request)
        return try response.ok.body.json
    }

    public func searchPOIs(
        latitude: Double,
        longitude: Double,
        radiusMiles: Double,
        categories: [String]?
    ) async throws -> [POI] {
        guard let token = authToken else {
            throw APIError.unauthorized
        }

        let request = Operations.SearchPOIs.Input(
            headers: .init(Authorization: "Bearer \(token)"),
            query: .init(
                latitude: latitude,
                longitude: longitude,
                radius: radiusMiles,
                categories: categories
            )
        )
        let response = try await client.searchPOIs(request)
        return try response.ok.body.json
    }

    public func generateNarration(
        poiId: UUID,
        targetDuration: Double,
        userInterests: [String]
    ) async throws -> Narration {
        guard let token = authToken else {
            throw APIError.unauthorized
        }

        let request = Operations.GenerateNarration.Input(
            headers: .init(Authorization: "Bearer \(token)"),
            body: .json(.init(
                poiId: poiId,
                targetDuration: targetDuration,
                userInterests: userInterests
            ))
        )
        let response = try await client.generateNarration(request)
        return try response.ok.body.json
    }
}

public enum APIError: Error {
    case unauthorized
    case invalidResponse
    case networkError(Error)
}
```

**Update AppState**

```swift
// Sources/AIRoadTripToursApp/AppState.swift
import AIRoadTripToursCore
import AIRoadTripToursAPI

@Observable
@MainActor
public final class AppState {
    public var currentUser: User?
    public var currentVehicle: EVProfile?
    public var hasCompletedOnboarding: Bool = false

    // Local repositories (offline mode)
    public let localPOIRepository: POIRepository
    public let rangeEstimator: RangeEstimator

    // API client (online mode)
    public let apiClient: APIClient
    private(set) var isOnline: Bool = false

    public init() {
        self.localPOIRepository = InMemoryPOIRepository()
        self.rangeEstimator = SimpleRangeEstimator()

        #if DEBUG
        self.apiClient = APIClient(serverURL: URL(string: "https://staging-api.airoadtriptours.com/v1")!)
        #else
        self.apiClient = APIClient(serverURL: URL(string: "https://api.airoadtriptours.com/v1")!)
        #endif
    }

    public func syncWithBackend() async throws {
        // Sync user profile
        if let remoteUser = try? await apiClient.getUserProfile() {
            self.currentUser = remoteUser
            self.isOnline = true
        }

        // Sync POIs
        if let location = currentLocation {
            let remotePOIs = try await apiClient.searchPOIs(
                latitude: location.latitude,
                longitude: location.longitude,
                radiusMiles: 50.0,
                categories: nil
            )
            // Merge with local repository
        }
    }
}
```

**Tasks**:
- [ ] Generate Swift API client from OpenAPI spec
- [ ] Add API client to Package.swift dependencies
- [ ] Update AppState with API client
- [ ] Implement authentication flow in UI
- [ ] Add network connectivity handling
- [ ] Implement offline mode with local caching
- [ ] Add sync indicators in UI
- [ ] Handle API errors gracefully
- [ ] Write integration tests

### Step 4: External Service Integration (Week 7)

**OpenAI Integration**

```swift
// NarrationGenerator.swift
import Foundation

public actor OpenAINarrationGenerator: ContentGenerator {
    private let apiKey: String
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func generateNarration(
        for poi: POI,
        targetDurationSeconds: Double,
        userInterests: Set<UserInterest>
    ) async throws -> Narration {
        let prompt = buildPrompt(poi: poi, interests: userInterests, duration: targetDurationSeconds)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": [
                ["role": "system", "content": "You are a tour guide creating engaging audio narrations for road trips."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": Int(targetDurationSeconds * 2.5) // ~150 words per minute
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        let content = response.choices.first?.message.content ?? ""

        return Narration(
            poiId: poi.id,
            poiName: poi.name,
            title: "About \(poi.name)",
            content: content,
            durationSeconds: targetDurationSeconds
        )
    }

    private func buildPrompt(poi: POI, interests: Set<UserInterest>, duration: Double) -> String {
        """
        Create an engaging \(Int(duration))-second audio narration about \(poi.name).

        POI Details:
        - Category: \(poi.category.rawValue)
        - Description: \(poi.description ?? "")

        User Interests: \(interests.map { $0.name }.joined(separator: ", "))

        Guidelines:
        - Write for audio delivery (natural, conversational tone)
        - Highlight aspects relevant to user interests
        - Include interesting facts and stories
        - Target word count: ~\(Int(duration * 2.5)) words
        - No introduction like "Welcome to..." - start directly with content
        """
    }
}
```

**Google Places Integration**

```swift
// GooglePlacesService.swift
import Foundation

public actor GooglePlacesService {
    private let apiKey: String
    private let endpoint = URL(string: "https://maps.googleapis.com/maps/api/place/nearbysearch/json")!

    public func searchNearby(
        location: GeoLocation,
        radiusMeters: Int,
        type: String?
    ) async throws -> [POI] {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "location", value: "\(location.latitude),\(location.longitude)"),
            URLQueryItem(name: "radius", value: "\(radiusMeters)"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        if let type {
            components.queryItems?.append(URLQueryItem(name: "type", value: type))
        }

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)

        return response.results.map { result in
            POI(
                name: result.name,
                description: result.types.joined(separator: ", "),
                category: mapCategory(result.types),
                location: GeoLocation(
                    latitude: result.geometry.location.lat,
                    longitude: result.geometry.location.lng
                ),
                rating: result.rating.map {
                    POIRating(
                        averageRating: $0,
                        totalRatings: result.userRatingsTotal ?? 0
                    )
                },
                source: .google
            )
        }
    }
}
```

**Tasks**:
- [ ] Set up OpenAI API account
- [ ] Implement OpenAI narration generator
- [ ] Set up Google Places API account
- [ ] Implement Google Places POI search
- [ ] Set up NREL API for EV chargers
- [ ] Add API key management (secure storage)
- [ ] Implement rate limiting
- [ ] Add error handling for API failures
- [ ] Test with real API calls

### Step 5: Testing and Deployment (Week 8)

**Testing**
- [ ] Backend API integration tests
- [ ] iOS client unit tests
- [ ] End-to-end flow testing
- [ ] Load testing
- [ ] Security audit

**Deployment**
- [ ] Set up CI/CD pipeline
- [ ] Configure production database
- [ ] Deploy backend to cloud provider
- [ ] Set up monitoring and logging
- [ ] Configure CDN for static assets
- [ ] Set up backup and recovery

**Documentation**
- [ ] API documentation
- [ ] Deployment guide
- [ ] Operations runbook
- [ ] User privacy policy
- [ ] Terms of service

## Success Criteria

- [ ] User can register and login
- [ ] User profile syncs across devices
- [ ] POI search returns real-time data
- [ ] AI narrations generate within 5 seconds
- [ ] App works offline with cached data
- [ ] API responds in < 200ms (95th percentile)
- [ ] Zero data loss during sync
- [ ] Secure authentication (HTTPS, JWT)
- [ ] 99.9% uptime SLA

## Timeline

**Week 1**: API specification
**Weeks 2-4**: Backend implementation
**Weeks 5-6**: iOS integration
**Week 7**: External services
**Week 8**: Testing and deployment

**Total**: 8 weeks

## Budget Estimates

**Development**: 8 weeks × $X/hour
**Infrastructure**:
- Database hosting: $50-200/month
- API server: $100-500/month
- CDN: $20-100/month

**External APIs**:
- OpenAI: ~$0.01 per narration
- Google Places: Free tier, then $17/1000 requests
- NREL: Free

## Next Actions

1. [ ] Review and approve Phase 5 plan
2. [ ] Set up project management (Jira/Linear)
3. [ ] Create backend repository
4. [ ] Assign development tasks
5. [ ] Set up staging environment
6. [ ] Begin Week 1 (API specification)
