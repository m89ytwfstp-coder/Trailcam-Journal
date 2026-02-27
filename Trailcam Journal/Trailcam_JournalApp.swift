//
//  Trailcam_JournalApp.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 17/12/2025.
//

import SwiftUI

#if os(iOS)
@main
struct Trailcam_JournalApp: App {
    @StateObject private var store = EntryStore()
    @StateObject private var savedLocationStore = SavedLocationStore()

    init() {
        ProjectSelfChecks.run()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(savedLocationStore)
        }
    }
}
#endif
