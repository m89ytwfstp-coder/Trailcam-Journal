import SwiftUI

#if os(macOS)
@main
struct Trailcam_JournalMacApp: App {
    @StateObject private var store = EntryStore()
    @StateObject private var savedLocationStore = SavedLocationStore()

    init() {
        ProjectSelfChecks.run()
    }

    var body: some Scene {
        WindowGroup {
            ContentViewMac()
                .environmentObject(store)
                .environmentObject(savedLocationStore)
        }
    }
}
#endif
