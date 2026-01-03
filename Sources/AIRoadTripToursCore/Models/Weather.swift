import Foundation

/// Weather condition for a location.
public struct WeatherCondition: Codable, Sendable, Equatable {
    public let temperature: Double // Fahrenheit
    public let feelsLike: Double // Fahrenheit
    public let condition: WeatherType
    public let windSpeed: Double // mph
    public let humidity: Int // percentage
    public let visibility: Double // miles
    public let precipitation: Double // inches
    public let timestamp: Date

    public init(
        temperature: Double,
        feelsLike: Double,
        condition: WeatherType,
        windSpeed: Double,
        humidity: Int,
        visibility: Double,
        precipitation: Double,
        timestamp: Date
    ) {
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.condition = condition
        self.windSpeed = windSpeed
        self.humidity = humidity
        self.visibility = visibility
        self.precipitation = precipitation
        self.timestamp = timestamp
    }
}

/// Weather condition types.
public enum WeatherType: String, Codable, Sendable {
    case clear = "Clear"
    case partlyCloudy = "Partly Cloudy"
    case cloudy = "Cloudy"
    case rain = "Rain"
    case heavyRain = "Heavy Rain"
    case snow = "Snow"
    case fog = "Fog"
    case thunderstorm = "Thunderstorm"
    case unknown = "Unknown"

    public var icon: String {
        switch self {
        case .clear: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .rain: return "cloud.rain.fill"
        case .heavyRain: return "cloud.heavyrain.fill"
        case .snow: return "cloud.snow.fill"
        case .fog: return "cloud.fog.fill"
        case .thunderstorm: return "cloud.bolt.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    public var isSevere: Bool {
        switch self {
        case .heavyRain, .snow, .thunderstorm, .fog:
            return true
        case .clear, .partlyCloudy, .cloudy, .rain, .unknown:
            return false
        }
    }
}

/// Weather forecast for a location.
public struct WeatherForecast: Codable, Sendable {
    public let location: GeoLocation
    public let current: WeatherCondition
    public let hourly: [WeatherCondition]
    public let alerts: [WeatherAlert]

    public init(
        location: GeoLocation,
        current: WeatherCondition,
        hourly: [WeatherCondition],
        alerts: [WeatherAlert]
    ) {
        self.location = location
        self.current = current
        self.hourly = hourly
        self.alerts = alerts
    }
}

/// Weather alert for severe conditions.
public struct WeatherAlert: Codable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let description: String
    public let severity: AlertSeverity
    public let startTime: Date
    public let endTime: Date

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        severity: AlertSeverity,
        startTime: Date,
        endTime: Date
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.severity = severity
        self.startTime = startTime
        self.endTime = endTime
    }
}

/// Alert severity levels.
public enum AlertSeverity: String, Codable, Sendable {
    case minor = "Minor"
    case moderate = "Moderate"
    case severe = "Severe"
    case extreme = "Extreme"

    public var color: String {
        switch self {
        case .minor: return "yellow"
        case .moderate: return "orange"
        case .severe: return "red"
        case .extreme: return "purple"
        }
    }
}
