import Foundation
import AIRoadTripToursCore

/// Service for fetching weather data from Open-Meteo API.
public actor WeatherService {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetch current weather for a location.
    public func fetchWeather(for location: GeoLocation) async throws -> WeatherForecast {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(location.latitude)&longitude=\(location.longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m&hourly=temperature_2m,precipitation_probability,weather_code&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch&timezone=auto"

        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WeatherError.networkError
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let openMeteoResponse = try decoder.decode(OpenMeteoResponse.self, from: data)

        return try parseWeatherResponse(openMeteoResponse, location: location)
    }

    /// Fetch weather for multiple locations (POIs along route).
    public func fetchWeatherForRoute(locations: [GeoLocation]) async throws -> [WeatherForecast] {
        try await withThrowingTaskGroup(of: (Int, WeatherForecast).self) { group in
            for (index, location) in locations.enumerated() {
                group.addTask {
                    let forecast = try await self.fetchWeather(for: location)
                    return (index, forecast)
                }
            }

            var forecasts: [(Int, WeatherForecast)] = []
            for try await result in group {
                forecasts.append(result)
            }

            return forecasts.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
        }
    }

    private func parseWeatherResponse(_ response: OpenMeteoResponse, location: GeoLocation) throws -> WeatherForecast {
        guard let current = response.current else {
            throw WeatherError.invalidResponse
        }

        let currentCondition = WeatherCondition(
            temperature: current.temperature_2m,
            feelsLike: current.apparent_temperature,
            condition: weatherTypeFromCode(current.weather_code),
            windSpeed: current.wind_speed_10m,
            humidity: current.relative_humidity_2m,
            visibility: 10.0, // Open-Meteo doesn't provide visibility
            precipitation: current.precipitation,
            timestamp: Date()
        )

        // Parse hourly forecast (next 24 hours)
        var hourlyConditions: [WeatherCondition] = []
        if let hourly = response.hourly,
           let times = hourly.time,
           let temps = hourly.temperature_2m,
           let weatherCodes = hourly.weather_code {
            let count = min(24, times.count)
            for i in 0..<count {
                let condition = WeatherCondition(
                    temperature: temps[i],
                    feelsLike: temps[i], // Approximation
                    condition: weatherTypeFromCode(weatherCodes[i]),
                    windSpeed: current.wind_speed_10m,
                    humidity: current.relative_humidity_2m,
                    visibility: 10.0,
                    precipitation: 0.0,
                    timestamp: ISO8601DateFormatter().date(from: times[i]) ?? Date()
                )
                hourlyConditions.append(condition)
            }
        }

        // Check for severe weather alerts
        let alerts = generateAlertsFromConditions(current: currentCondition, hourly: hourlyConditions)

        return WeatherForecast(
            location: location,
            current: currentCondition,
            hourly: hourlyConditions,
            alerts: alerts
        )
    }

    private func weatherTypeFromCode(_ code: Int) -> WeatherType {
        // Open-Meteo WMO Weather codes
        switch code {
        case 0: return .clear
        case 1, 2: return .partlyCloudy
        case 3: return .cloudy
        case 45, 48: return .fog
        case 51, 53, 55, 61, 63, 80, 81: return .rain
        case 65, 82: return .heavyRain
        case 71, 73, 75, 77, 85, 86: return .snow
        case 95, 96, 99: return .thunderstorm
        default: return .unknown
        }
    }

    private func generateAlertsFromConditions(current: WeatherCondition, hourly: [WeatherCondition]) -> [WeatherAlert] {
        var alerts: [WeatherAlert] = []

        // Check current severe weather
        if current.condition.isSevere {
            let alert = WeatherAlert(
                title: "Current Weather Alert",
                description: "\(current.condition.rawValue) conditions detected. Drive with caution.",
                severity: .moderate,
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600)
            )
            alerts.append(alert)
        }

        // Check for upcoming severe weather
        let severeUpcoming = hourly.prefix(6).filter { $0.condition.isSevere }
        if !severeUpcoming.isEmpty {
            let alert = WeatherAlert(
                title: "Severe Weather Ahead",
                description: "Expect \(severeUpcoming.first!.condition.rawValue.lowercased()) conditions within the next few hours.",
                severity: .moderate,
                startTime: Date(),
                endTime: Date().addingTimeInterval(21600)
            )
            alerts.append(alert)
        }

        return alerts
    }
}

// MARK: - Open-Meteo Response Models

private struct OpenMeteoResponse: Codable {
    let current: CurrentWeather?
    let hourly: HourlyWeather?
}

private struct CurrentWeather: Codable {
    let temperature_2m: Double
    let apparent_temperature: Double
    let relative_humidity_2m: Int
    let precipitation: Double
    let weather_code: Int
    let wind_speed_10m: Double
}

private struct HourlyWeather: Codable {
    let time: [String]?
    let temperature_2m: [Double]?
    let precipitation_probability: [Int]?
    let weather_code: [Int]?
}

// MARK: - Errors

public enum WeatherError: Error, LocalizedError {
    case invalidURL
    case networkError
    case invalidResponse
    case noData

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid weather API URL"
        case .networkError:
            return "Network error fetching weather data"
        case .invalidResponse:
            return "Invalid response from weather service"
        case .noData:
            return "No weather data available"
        }
    }
}
