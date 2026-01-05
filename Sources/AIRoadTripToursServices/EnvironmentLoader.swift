import Foundation

/// Loads environment variables from .env files
public struct EnvironmentLoader {

    /// Load environment variables from .env file in the project root
    public static func loadDotEnv() {
        // Try multiple possible locations for .env file
        let possiblePaths = [
            // Project root
            FileManager.default.currentDirectoryPath + "/.env",
            // Parent directory (when running from build)
            FileManager.default.currentDirectoryPath + "/../.env",
            // Two levels up
            FileManager.default.currentDirectoryPath + "/../../.env",
            // Check in bundle resources (for iOS app)
            Bundle.main.path(forResource: ".env", ofType: nil) ?? ""
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                print("📄 Loading .env from: \(path)")
                loadEnvFile(at: path)
                return
            }
        }

        print("⚠️ No .env file found in expected locations")
    }

    private static func loadEnvFile(at path: String) {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("❌ Failed to read .env file at: \(path)")
            return
        }

        let lines = contents.components(separatedBy: .newlines)
        var loadedCount = 0

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }

            // Parse KEY=VALUE format
            let parts = trimmedLine.components(separatedBy: "=")
            guard parts.count >= 2 else {
                continue
            }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)

            // Remove quotes if present
            let cleanValue = value
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            // Set environment variable
            setenv(key, cleanValue, 1)
            loadedCount += 1
            print("✅ Loaded: \(key)")
        }

        print("📄 Loaded \(loadedCount) environment variables from .env")
    }
}
