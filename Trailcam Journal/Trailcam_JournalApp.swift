//
//  Trailcam_JournalApp.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 17/12/2025.
//

// ── Platform role (decided 2026-03) ─────────────────────────────────────────
// iOS  : field capture — entry creation, photo import from Photos, basic map
// macOS: review & management — Finder import, full edit, stats, map layers, pins
//
// New features: start on primary target. Don't mirror management tools to iOS
// or field tools to Mac unless there is a strong explicit reason.
// ─────────────────────────────────────────────────────────────────────────────

import SwiftUI

#if os(iOS)
@main
struct Trailcam_JournalApp: App {
    @StateObject private var store          = EntryStore()
    @StateObject private var locationStore  = LocationStore()   // merges SavedLocationStore + HubStore
    @StateObject private var tripStore      = TripStore()
    @StateObject private var arrivalStore   = ArrivalStore()
    @StateObject private var nestboxStore   = NestboxStore()

    init() {
        ProjectSelfChecks.run()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(locationStore)   // satisfies all SavedLocationStore consumers
                .environmentObject(tripStore)
                .environmentObject(arrivalStore)
                .environmentObject(nestboxStore)
        }
    }
}
#endif
