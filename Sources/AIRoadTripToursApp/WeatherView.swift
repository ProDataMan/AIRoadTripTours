import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices

/// View displaying weather information for a location.
public struct WeatherView: View {
    let forecast: WeatherForecast
    @State private var showHourly = false

    public init(forecast: WeatherForecast) {
        self.forecast = forecast
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Current weather
            HStack(spacing: 16) {
                Image(systemName: forecast.current.condition.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(weatherColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(forecast.current.temperature))°F")
                        .font(.title)
                        .fontWeight(.bold)

                    Text(forecast.current.condition.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Feels like \(Int(forecast.current.feelsLike))°F")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(forecast.current.humidity)% humidity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Weather details
            HStack(spacing: 20) {
                WeatherDetailItem(
                    icon: "wind",
                    value: String(format: "%.1f mph", forecast.current.windSpeed),
                    label: "Wind"
                )

                WeatherDetailItem(
                    icon: "drop.fill",
                    value: String(format: "%.2f in", forecast.current.precipitation),
                    label: "Rain"
                )

                WeatherDetailItem(
                    icon: "eye.fill",
                    value: String(format: "%.1f mi", forecast.current.visibility),
                    label: "Visibility"
                )
            }

            // Weather alerts
            if !forecast.alerts.isEmpty {
                Divider()

                ForEach(forecast.alerts) { alert in
                    WeatherAlertCard(alert: alert)
                }
            }

            // Hourly forecast toggle
            if !forecast.hourly.isEmpty {
                Divider()

                Button {
                    showHourly.toggle()
                } label: {
                    HStack {
                        Text("Hourly Forecast")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        Image(systemName: showHourly ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.primary)

                if showHourly {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(forecast.hourly.prefix(12).indices, id: \.self) { index in
                                HourlyWeatherCard(condition: forecast.hourly[index])
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(12)
    }

    private var weatherColor: Color {
        if forecast.current.condition.isSevere {
            return .red
        }

        switch forecast.current.condition {
        case .clear: return .yellow
        case .partlyCloudy: return .blue
        case .cloudy: return .gray
        case .rain, .heavyRain: return .blue
        case .snow: return .cyan
        case .fog: return .gray
        case .thunderstorm: return .purple
        case .unknown: return .gray
        }
    }
}

// MARK: - Weather Detail Item

struct WeatherDetailItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Weather Alert Card

struct WeatherAlertCard: View {
    let alert: WeatherAlert

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(alertColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(alert.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(alertColor.opacity(0.1))
        .cornerRadius(8)
    }

    private var alertColor: Color {
        switch alert.severity {
        case .minor: return .yellow
        case .moderate: return .orange
        case .severe: return .red
        case .extreme: return .purple
        }
    }
}

// MARK: - Hourly Weather Card

struct HourlyWeatherCard: View {
    let condition: WeatherCondition

    var body: some View {
        VStack(spacing: 8) {
            Text(formatTime(condition.timestamp))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Image(systemName: condition.condition.icon)
                .font(.title3)
                .foregroundStyle(iconColor)

            Text("\(Int(condition.temperature))°")
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(width: 60)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var iconColor: Color {
        if condition.condition.isSevere {
            return .red
        }

        switch condition.condition {
        case .clear: return .yellow
        case .partlyCloudy: return .blue
        case .cloudy: return .gray
        case .rain, .heavyRain: return .blue
        case .snow: return .cyan
        case .fog: return .gray
        case .thunderstorm: return .purple
        case .unknown: return .gray
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date)
    }
}

#Preview {
    WeatherView(forecast: WeatherForecast(
        location: GeoLocation(latitude: 45.5152, longitude: -122.6784),
        current: WeatherCondition(
            temperature: 65.0,
            feelsLike: 63.0,
            condition: .partlyCloudy,
            windSpeed: 8.5,
            humidity: 70,
            visibility: 10.0,
            precipitation: 0.0,
            timestamp: Date()
        ),
        hourly: [],
        alerts: []
    ))
    .padding()
}
