//
//  WeatherService.swift
//  Trailcam Journal
//
//  Fetches current conditions from the Norwegian Meteorological Institute's
//  free, open, no-key-required Locationforecast 2.0 API.
//  https://api.met.no/weatherapi/locationforecast/2.0
//

#if os(macOS)
import Foundation

// ── Snapshot returned by the service ──────────────────────────────────────────

struct WeatherSnapshot {
    let temperatureC:  Double
    let windSpeedMs:   Double
    let symbolCode:    String   // met.no symbol, e.g. "partlycloudy_day"

    // Map met.no symbol codes → SF Symbols (available macOS 13+)
    var sfSymbol: String {
        let base = symbolCode
            .replacingOccurrences(of: "_day",          with: "")
            .replacingOccurrences(of: "_night",        with: "")
            .replacingOccurrences(of: "_polartwilight", with: "")
        switch base {
        case "clearsky", "fair":
            return "sun.max.fill"
        case "partlycloudy":
            return "cloud.sun.fill"
        case "cloudy":
            return "cloud.fill"
        case "fog":
            return "cloud.fog.fill"
        case "lightrain", "rain", "lightrainshowers", "rainshowers":
            return "cloud.rain.fill"
        case "heavyrain", "heavyrainshowers":
            return "cloud.heavyrain.fill"
        case "lightsnow", "snow", "lightsnowshowers", "snowshowers":
            return "cloud.snow.fill"
        case "heavysnow", "heavysnowshowers":
            return "cloud.snow.fill"
        case "sleet", "lightsleet", "lightsleetshowers", "sleetshowers":
            return "cloud.sleet.fill"
        case "thunder", "thundershowers", "heavyrainandthunder",
             "lightrainandthunder", "snowandthunder":
            return "cloud.bolt.rain.fill"
        default:
            return "cloud.fill"
        }
    }

    var temperatureString: String { String(format: "%.0f°C", temperatureC) }
    var windString:        String { String(format: "%.1f m/s", windSpeedMs) }
}

// ── Service ───────────────────────────────────────────────────────────────────

enum WeatherService {

    // Minimal Decodable wrappers for the Locationforecast compact response
    private struct METResponse: Decodable {
        struct Properties: Decodable {
            struct Series: Decodable {
                struct Data: Decodable {
                    struct Instant: Decodable {
                        struct Details: Decodable {
                            let air_temperature: Double?
                            let wind_speed:      Double?
                        }
                        let details: Details
                    }
                    struct Summary: Decodable { let symbol_code: String }
                    struct Bucket: Decodable  { let summary: Summary }
                    let instant:      Instant
                    let next_1_hours: Bucket?
                    let next_6_hours: Bucket?
                }
                let data: Data
            }
            let timeseries: [Series]
        }
        let properties: Properties
    }

    /// Fetch current conditions for the given coordinate.
    /// Returns nil on network error, bad JSON, or when offline.
    static func fetch(lat: Double, lon: Double) async -> WeatherSnapshot? {
        let latStr = String(format: "%.4f", lat)
        let lonStr = String(format: "%.4f", lon)
        guard let url = URL(string:
            "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=\(latStr)&lon=\(lonStr)")
        else { return nil }

        var req = URLRequest(url: url, timeoutInterval: 8)
        // met.no requires a descriptive User-Agent
        req.setValue("TrailcamJournal/1.0 github.com/trailcam-journal", forHTTPHeaderField: "User-Agent")
        req.cachePolicy = .useProtocolCachePolicy

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp    = try? decoder.decode(METResponse.self, from: data),
              let first   = resp.properties.timeseries.first
        else { return nil }

        let temp   = first.data.instant.details.air_temperature ?? 0
        let wind   = first.data.instant.details.wind_speed      ?? 0
        let symbol = first.data.next_1_hours?.summary.symbol_code
                  ?? first.data.next_6_hours?.summary.symbol_code
                  ?? "cloudy"

        return WeatherSnapshot(temperatureC: temp, windSpeedMs: wind, symbolCode: symbol)
    }
}
#endif
