import Foundation

/// Configuration for external service API keys
public struct ServiceConfiguration {

    /// Load environment variables from .env file
    /// Call this once at app startup
    public static func loadEnvironment() {
        EnvironmentLoader.loadDotEnv()
    }

    /// Google Places API key for fetching POI images
    /// To obtain an API key:
    /// 1. Go to https://console.cloud.google.com/
    /// 2. Create a new project or select an existing one
    /// 3. Enable the "Places API" and "Places API (New)"
    /// 4. Create credentials (API Key)
    /// 5. Restrict the key to Places API for security
    /// 6. Add to .env file: GOOGLE_PLACES_API_KEY=your-key-here
    public static var googlePlacesAPIKey: String {
        // Try environment variable (set from .env file or system)
        if let envKey = ProcessInfo.processInfo.environment["GOOGLE_PLACES_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        // No key found
        return "YOUR_GOOGLE_PLACES_API_KEY"
    }

    /// Check if Google Places API is configured
    public static var isGooglePlacesConfigured: Bool {
        let key = googlePlacesAPIKey
        return !key.isEmpty && key != "YOUR_GOOGLE_PLACES_API_KEY"
    }
}

