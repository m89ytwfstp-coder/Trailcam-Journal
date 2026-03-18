//
//  SunMoonCalculator.swift
//  Trailcam Journal
//
//  Pure-Swift astronomical calculations — no external dependencies, no network.
//
//  • Sunrise / sunset  — NOAA Solar Position algorithm (accurate to ~1 min)
//  • Moon phase        — Synodic-month offset from a known new moon
//

import Foundation

enum SunMoonCalculator {

    // MARK: - Moon phase

    struct MoonPhase {
        /// 0 = new moon … 1 = back to new moon
        let fraction:  Double
        let name:      String
        let sfSymbol:  String
    }

    static func moonPhase(for date: Date) -> MoonPhase {
        // Known new moon: 6 Jan 2000 18:14 UTC
        let knownNewMoon: TimeInterval = 947_178_840
        let synodicMonth: TimeInterval = 29.530_588_853 * 86_400

        var age = (date.timeIntervalSince1970 - knownNewMoon)
            .truncatingRemainder(dividingBy: synodicMonth)
        if age < 0 { age += synodicMonth }
        let f = age / synodicMonth   // 0…1

        switch f {
        case ..<0.033, 0.967...:
            return MoonPhase(fraction: f, name: "New Moon",       sfSymbol: "moonphase.new.moon")
        case ..<0.25:
            return MoonPhase(fraction: f, name: "Waxing Crescent",sfSymbol: "moonphase.waxing.crescent")
        case ..<0.283:
            return MoonPhase(fraction: f, name: "First Quarter",  sfSymbol: "moonphase.first.quarter")
        case ..<0.5:
            return MoonPhase(fraction: f, name: "Waxing Gibbous", sfSymbol: "moonphase.waxing.gibbous")
        case ..<0.533:
            return MoonPhase(fraction: f, name: "Full Moon",      sfSymbol: "moonphase.full.moon")
        case ..<0.75:
            return MoonPhase(fraction: f, name: "Waning Gibbous", sfSymbol: "moonphase.waning.gibbous")
        case ..<0.783:
            return MoonPhase(fraction: f, name: "Last Quarter",   sfSymbol: "moonphase.last.quarter")
        default:
            return MoonPhase(fraction: f, name: "Waning Crescent",sfSymbol: "moonphase.waning.crescent")
        }
    }

    // MARK: - Sunrise / Sunset

    struct SunTimes {
        let sunrise: Date?
        let sunset:  Date?
        let isPolDay:   Bool   // sun never sets  (midnight sun)
        let isPolNight: Bool   // sun never rises (polar night)
    }

    /// Returns sunrise and sunset in UTC for the calendar day of `date` at the given coordinate.
    /// All calculations follow NOAA's published spreadsheet methodology.
    static func sunTimes(for date: Date, lat: Double, lon: Double) -> SunTimes {
        let cal = utcCalendar

        // Julian day for solar noon on `date`
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = 12; comps.minute = 0; comps.second = 0
        guard let noonUTC = cal.date(from: comps) else {
            return SunTimes(sunrise: nil, sunset: nil, isPolDay: false, isPolNight: false)
        }
        let JD = noonUTC.timeIntervalSince1970 / 86_400.0 + 2_440_587.5

        // Julian century
        let T = (JD - 2_451_545.0) / 36_525.0

        // Geometric mean longitude (degrees)
        let L0 = mod360(280.46646 + T * (36_000.76983 + T * 0.000_3032))

        // Geometric mean anomaly (degrees)
        let M    = 357.52911 + T * (35_999.05029 - 0.000_1537 * T)
        let Mrad = deg2rad(M)

        // Equation of center
        let C = sin(Mrad)   * (1.914602 - T * (0.004817 + 0.000014 * T))
              + sin(2*Mrad) * (0.019993 - 0.000101 * T)
              + sin(3*Mrad) * 0.000289

        // Sun's apparent longitude
        let omega  = 125.04 - 1_934.136 * T
        let lambda = L0 + C - 0.00569 - 0.00478 * sin(deg2rad(omega))

        // Mean obliquity (degrees)
        let eps0 = 23.0 + (26.0 + (21.448 - T * (46.8150 + T * (0.00059 - T * 0.001813))) / 60.0) / 60.0
        let eps  = eps0 + 0.00256 * cos(deg2rad(omega))

        // Sun's declination
        let sinDec = sin(deg2rad(eps)) * sin(deg2rad(lambda))
        let dec    = asin(sinDec)   // radians

        // Equation of time (minutes)
        let y   = tan(deg2rad(eps / 2)); let y2 = y * y
        let ecc = 0.016_708_634
        let Eqt = 4.0 * rad2deg(
            y2 * sin(2*deg2rad(L0))
            - 2*ecc * sin(Mrad)
            + 4*ecc*y2 * sin(Mrad)*cos(2*deg2rad(L0))
            - 0.5*y2*y2 * sin(4*deg2rad(L0))
            - 1.25*ecc*ecc * sin(2*Mrad)
        )

        // Hour angle (degrees) — 90.833° accounts for refraction & solar disk
        let latRad = deg2rad(lat)
        let cosHA  = (cos(deg2rad(90.833)) - sin(latRad)*sinDec)
                   / (cos(latRad)*cos(dec))

        if cosHA < -1 {
            return SunTimes(sunrise: nil, sunset: nil, isPolDay: true,  isPolNight: false)
        }
        if cosHA > 1 {
            return SunTimes(sunrise: nil, sunset: nil, isPolDay: false, isPolNight: true)
        }

        let HA = rad2deg(acos(cosHA))   // degrees

        // Solar noon in minutes past UTC midnight
        let solarNoonMin = 720.0 - 4.0*lon - Eqt

        let sunriseMin = solarNoonMin - HA * 4.0
        let sunsetMin  = solarNoonMin + HA * 4.0

        // Day start in UTC
        guard let dayStartUTC = cal.date(from: cal.dateComponents([.year, .month, .day], from: noonUTC))
        else { return SunTimes(sunrise: nil, sunset: nil, isPolDay: false, isPolNight: false) }

        let sunrise = dayStartUTC.addingTimeInterval(sunriseMin * 60)
        let sunset  = dayStartUTC.addingTimeInterval(sunsetMin  * 60)

        return SunTimes(sunrise: sunrise, sunset: sunset, isPolDay: false, isPolNight: false)
    }

    // MARK: - Helpers

    private static var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private static func deg2rad(_ d: Double) -> Double { d * .pi / 180 }
    private static func rad2deg(_ r: Double) -> Double { r * 180 / .pi }
    private static func mod360(_ d: Double) -> Double {
        let m = d.truncatingRemainder(dividingBy: 360)
        return m < 0 ? m + 360 : m
    }
}
