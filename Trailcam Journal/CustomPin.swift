
//
//  CustomPin.swift
//  Trailcam Journal
//
//  Persistent named places — a distinct map layer from time-stamped observation entries.
//  Part of MapPins-v1 feature.
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - CustomPin

struct CustomPin: Identifiable, Codable {
    var id: UUID            = UUID()
    var name: String?       = nil
    var type: CustomPinType
    var latitude: Double
    var longitude: Double
    var isActive: Bool      = true
    var dateAdded: Date     = Date()
    var dateSighted: Date?  = nil
    var notes: String?      = nil
    var linkedEntryIDs: [UUID] = []
    /// Filename of an optional photo stored in Application Support/TrailcamJournal/pinphotos/
    var photoFilename: String? = nil

    /// Computed coordinate (not stored directly — CLLocationCoordinate2D is not Codable)
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Display name: user-supplied name if present, else the type's display name
    var displayName: String {
        if let n = name, !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return n
        }
        return type.displayName
    }
}

// MARK: - CustomPinType

enum CustomPinType: String, Codable, CaseIterable {

    // Infrastructure — things you placed or maintain
    case birdFeeder
    case saltLick
    case trailCameraPlacement

    // Wildlife signs — things you found
    case den
    case burrow
    case nestInTree
    case scratchTree
    case wallow
    case scat
    case carcass

    // Terrain markers — reference points
    case gameTrail
    case waterSource
    case vantagePoint
    case feedingArea

    var displayName: String {
        switch self {
        case .birdFeeder:           return "Bird feeder"
        case .saltLick:             return "Salt lick"
        case .trailCameraPlacement: return "Camera"
        case .den:                  return "Den"
        case .burrow:               return "Burrow"
        case .nestInTree:           return "Nest"
        case .scratchTree:          return "Scratch tree"
        case .wallow:               return "Wallow"
        case .scat:                 return "Scat"
        case .carcass:              return "Carcass"
        case .gameTrail:            return "Game trail"
        case .waterSource:          return "Water source"
        case .vantagePoint:         return "Vantage point"
        case .feedingArea:          return "Feeding area"
        }
    }

    var sfSymbol: String {
        switch self {
        case .birdFeeder:           return "bird"
        case .saltLick:             return "circle.hexagonpath"
        case .trailCameraPlacement: return "camera.fill"
        case .den:                  return "house.lodge.fill"
        case .burrow:               return "arrow.down.to.line"
        case .nestInTree:           return "leaf.circle.fill"
        case .scratchTree:          return "claw.hand"
        case .wallow:               return "drop.fill"
        case .scat:                 return "oval.portrait.fill"
        case .carcass:              return "exclamationmark.circle"
        case .gameTrail:            return "arrow.triangle.branch"
        case .waterSource:          return "water.waves"
        case .vantagePoint:         return "binoculars.fill"
        case .feedingArea:          return "fork.knife.circle"
        }
    }

    var category: CustomPinCategory {
        switch self {
        case .birdFeeder, .saltLick, .trailCameraPlacement:
            return .infrastructure
        case .den, .burrow, .nestInTree, .scratchTree, .wallow, .scat, .carcass:
            return .wildlifeSign
        case .gameTrail, .waterSource, .vantagePoint, .feedingArea:
            return .terrain
        }
    }

    /// Hint for UI — carcass / wallow / scat / scratchTree are typically temporary
    var isTypicallyTemporary: Bool {
        switch self {
        case .carcass, .wallow, .scat, .scratchTree: return true
        default:                                     return false
        }
    }

    var color: Color {
        switch self {
        case .birdFeeder:           return Color(red: 0.95, green: 0.70, blue: 0.10) // amber
        case .saltLick:             return .orange
        case .trailCameraPlacement: return Color(red: 0.13, green: 0.60, blue: 0.62) // teal
        case .den:                  return Color(red: 0.55, green: 0.35, blue: 0.20) // brown
        case .burrow:               return Color(red: 0.55, green: 0.35, blue: 0.20) // brown
        case .nestInTree:           return Color(red: 0.20, green: 0.65, blue: 0.30) // green
        case .scratchTree:          return Color(red: 0.63, green: 0.32, blue: 0.18) // sienna
        case .wallow:               return Color(red: 0.44, green: 0.50, blue: 0.56) // slate
        case .scat:                 return Color(red: 0.42, green: 0.30, blue: 0.10) // dark brown
        case .carcass:              return .red
        case .gameTrail:            return Color(red: 0.50, green: 0.50, blue: 0.50) // gray
        case .waterSource:          return Color(red: 0.20, green: 0.45, blue: 0.80) // blue
        case .vantagePoint:         return Color(red: 0.29, green: 0.25, blue: 0.75) // indigo
        case .feedingArea:          return Color(red: 0.40, green: 0.50, blue: 0.20) // olive
        }
    }
}

// MARK: - CustomPinCategory

enum CustomPinCategory: String, Codable, CaseIterable {
    case infrastructure
    case wildlifeSign
    case terrain

    var displayName: String {
        switch self {
        case .infrastructure: return "Infrastructure"
        case .wildlifeSign:   return "Wildlife Signs"
        case .terrain:        return "Terrain"
        }
    }
}
