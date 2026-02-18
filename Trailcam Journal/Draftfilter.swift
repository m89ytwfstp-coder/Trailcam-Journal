//
//  Draftfilter.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 16/01/2026.
//

import Foundation

enum DraftFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case missingSpecies = "Missing species"
    case missingLocation = "Missing location"
    case hasGPS = "Has GPS"
    case noGPS = "No GPS"

    var id: String { rawValue }
}
